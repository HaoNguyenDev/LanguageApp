//
//  RemoteContentService.swift
//  LanguageApp
//
//  Course content updates without an App Store release.
//
//  The content spreadsheet is published by the "Publish content" GitHub workflow to a public repo
//  served by GitHub Pages (`LanguageApp-content`):
//
//      <base>/v1/<channel>/manifest.json        – versions + sha256 of every course file
//      <base>/v1/<channel>/course_xx.json       – same JSON as Resources/Content
//
//  The app reads the manifest when it starts and when it comes back to the foreground (at most every
//  few hours), downloads the courses whose version is newer than the installed one, checks them
//  (sha256, id, version) and keeps them in Application Support/RemoteContent/pending. Pending files
//  are imported with `ContentImporter` (upsert → the learner's progress is kept) as soon as no
//  lesson / review is open, so content never changes under an open session.
//

import Foundation
import CryptoKit
import SwiftData

enum ContentChannel: String, CaseIterable, Identifiable {
    case production, staging
    var id: String { rawValue }
}

struct ContentManifest: Decodable, Equatable {
    struct Entry: Decodable, Equatable {
        let id: String
        let version: Int
        let file: String
        let sha256: String
    }

    /// Format of the course JSON; the app only reads `RemoteContentService.supportedSchema`.
    let schema: Int
    /// Oldest app version that understands this content ("1.0").
    let minAppVersion: String
    let courses: [Entry]
    /// Welcome toasts + notification texts (messages.json, from the "App Messages" sheet). Optional.
    let messages: MessagesEntry?

    struct MessagesEntry: Decodable, Equatable {
        let version: Int
        let file: String
        let sha256: String
    }
}

enum RemoteContentService {
    static let baseURL = URL(string: "https://haonguyendev.github.io/LanguageApp-content/v1/")!
    static let supportedSchema = 1
    /// Minimum time between two checks when the app comes back to the foreground
    /// (a cold launch always checks).
    static let checkInterval: TimeInterval = 30 * 60

    private enum Keys {
        static let lastCheck = "remoteContent.lastCheck"
        static let lastResult = "remoteContent.lastResult"
    }

    enum CheckResult: Equatable {
        case skipped              // checked recently
        case upToDate
        case downloaded([String]) // course ids waiting to be applied
        case unsupported          // content needs a newer app
        case failed(String)
    }

    // MARK: - Pure calculations (unit tested)

    static func manifestURL(channel: ContentChannel) -> URL {
        baseURL.appendingPathComponent(channel.rawValue).appendingPathComponent("manifest.json")
    }

    static func fileURL(_ entry: ContentManifest.Entry, channel: ContentChannel) -> URL {
        baseURL.appendingPathComponent(channel.rawValue).appendingPathComponent(entry.file)
    }

    /// "1.2.10" vs "1.10" → compares numbers part by part (missing parts count as 0).
    static func isVersion(_ version: String, atLeast minimum: String) -> Bool {
        let a = version.split(separator: ".").map { Int($0) ?? 0 }
        let b = minimum.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return true
    }

    /// Courses of the manifest newer than what is installed (or pending). Empty when the content
    /// needs a newer app or uses another schema.
    static func coursesToDownload(_ manifest: ContentManifest, installed: [String: Int], appVersion: String) -> [ContentManifest.Entry] {
        guard manifest.schema == supportedSchema, isVersion(appVersion, atLeast: manifest.minAppVersion) else { return [] }
        return manifest.courses.filter { $0.version > (installed[$0.id] ?? 0) }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The downloaded file is the one the manifest describes.
    static func isValid(_ data: Data, for entry: ContentManifest.Entry) -> Bool {
        guard sha256(data) == entry.sha256.lowercased(),
              let course = try? JSONDecoder().decode(CourseDTO.self, from: data) else { return false }
        return course.id == entry.id && course.version == entry.version
    }

    // MARK: - Pending files

    static var pendingDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("RemoteContent/pending", isDirectory: true)
    }

    static func pendingFiles(in directory: URL = pendingDirectory) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Versions of the pending files by course id (so they aren't downloaded again).
    static func pendingVersions(in directory: URL = pendingDirectory) -> [String: Int] {
        var result: [String: Int] = [:]
        for url in pendingFiles(in: directory) {
            if let data = try? Data(contentsOf: url), let course = try? JSONDecoder().decode(CourseDTO.self, from: data) {
                result[course.id] = course.version
            }
        }
        return result
    }

    // MARK: - Check & download

    /// Downloads newer course files into the pending folder. Doesn't touch SwiftData.
    @discardableResult
    static func checkForUpdates(installed: [String: Int],
                                channel: ContentChannel,
                                force: Bool = false,
                                defaults: UserDefaults = .standard,
                                session: URLSession = .shared,
                                now: Date = .now) async -> CheckResult {
        if !force, let last = defaults.object(forKey: Keys.lastCheck) as? Date,
           now.timeIntervalSince(last) < checkInterval {
            return .skipped
        }
        let result = await download(installed: installed, channel: channel, session: session)
        defaults.set(now, forKey: Keys.lastCheck)
        defaults.set("\(now.formatted(date: .abbreviated, time: .shortened)) · \(channel.rawValue) · \(describe(result))",
                     forKey: Keys.lastResult)
        return result
    }

    private static func download(installed: [String: Int], channel: ContentChannel, session: URLSession) async -> CheckResult {
        do {
            var request = URLRequest(url: manifestURL(channel: channel), cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 15)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                // 404 = nothing published on this channel yet (run the "Publish content" workflow).
                return .failed(status == 404 ? "nothing published on \(channel.rawValue) yet (HTTP 404)" : "manifest HTTP \(status)")
            }
            let manifest = try JSONDecoder().decode(ContentManifest.self, from: data)

            let known = installed.merging(pendingVersions()) { max($0, $1) }
            let appVersion = Env.shared.getVersionApp()
            guard manifest.schema == supportedSchema, isVersion(appVersion, atLeast: manifest.minAppVersion) else {
                return .unsupported
            }
            await downloadMessages(manifest.messages, channel: channel, session: session)
            let entries = coursesToDownload(manifest, installed: known, appVersion: appVersion)
            guard !entries.isEmpty else { return .upToDate }

            try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
            var saved: [String] = []
            for entry in entries {
                let fileRequest = URLRequest(url: fileURL(entry, channel: channel), cachePolicy: .reloadIgnoringLocalCacheData,
                                             timeoutInterval: 30)
                let (fileData, fileResponse) = try await session.data(for: fileRequest)
                guard (fileResponse as? HTTPURLResponse)?.statusCode == 200, isValid(fileData, for: entry) else {
                    Logger.shared.error("Remote content: \(entry.file) failed the check, skipped")
                    continue
                }
                try fileData.write(to: pendingDirectory.appendingPathComponent("course_\(entry.id).json"), options: .atomic)
                saved.append(entry.id)
            }
            return saved.isEmpty ? .failed("no valid file") : .downloaded(saved)
        } catch {
            Logger.shared.error("Remote content check failed: \(error)")
            return .failed(error.localizedDescription)
        }
    }

    /// Newer messages.json → checked and used right away (it doesn't touch SwiftData).
    /// A failure only keeps the texts the app already has.
    private static func downloadMessages(_ entry: ContentManifest.MessagesEntry?, channel: ContentChannel,
                                         session: URLSession) async {
        guard let entry, entry.version > MessageCatalog.installedVersion else { return }
        do {
            let url = baseURL.appendingPathComponent(channel.rawValue).appendingPathComponent(entry.file)
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, sha256(data) == entry.sha256.lowercased() else {
                Logger.shared.error("Remote content: \(entry.file) failed the check, skipped")
                return
            }
            try MessageCatalog.install(data)
        } catch {
            Logger.shared.error("Remote messages failed: \(error)")
        }
    }

    private static func describe(_ result: CheckResult) -> String {
        switch result {
        case .skipped: return "skipped"
        case .upToDate: return "up to date"
        case .downloaded(let ids): return "downloaded \(ids.joined(separator: ", "))"
        case .unsupported: return "needs a newer app"
        case .failed(let reason): return "failed: \(reason)"
        }
    }

    static func lastResultDescription(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: Keys.lastResult)
    }

    // MARK: - Apply

    /// Imports the pending course files (call only while no lesson / review is open).
    /// - Returns: ids of the courses that were updated.
    @discardableResult
    static func applyPending(in context: ModelContext, directory: URL = pendingDirectory) -> [String] {
        let files = pendingFiles(in: directory)
        guard !files.isEmpty else { return [] }
        let importer = ContentImporter(context: context)
        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        var updated: [String] = []
        for url in files {
            defer { try? FileManager.default.removeItem(at: url) }
            guard let data = try? Data(contentsOf: url),
                  let dto = try? JSONDecoder().decode(CourseDTO.self, from: data) else { continue }
            let existing = courses.first { $0.remoteId == dto.id }
            guard dto.version > (existing?.contentVersion ?? 0) else { continue }
            let order = existing?.order
                ?? ContentImporter.bundledCourseFiles.firstIndex(of: "course_\(dto.id)")
                ?? courses.count + updated.count
            do {
                try importer.importCourse(from: data, order: order)
                updated.append(dto.id)
            } catch {
                Logger.shared.error("Remote content: import of \(dto.id) failed: \(error)")
            }
        }
        if context.hasChanges { try? context.save() }
        return updated
    }

    /// Installed content versions by course id.
    static func installedVersions(in context: ModelContext) -> [String: Int] {
        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        return Dictionary(courses.map { ($0.remoteId, $0.contentVersion) }, uniquingKeysWith: { max($0, $1) })
    }

    static func resetSchedule(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Keys.lastCheck)
    }

    // MARK: - What changed (toast)

    struct ContentCounts: Equatable {
        var units = 0
        var lessons = 0
        var words = 0
    }

    static func counts(of course: Course?) -> ContentCounts {
        guard let course else { return ContentCounts() }
        return ContentCounts(units: course.sortedUnits.count,
                             lessons: course.orderedLessons.count,
                             words: course.allItems.count)
    }

    /// Title + message of the content-update toast. A text from the "App Messages" sheet
    /// (title → toast title, body → toast message) when published, else the built-in strings.
    static func updateToast(courseName: String?, before: ContentCounts, after: ContentCounts,
                            in messages: AppMessages = MessageCatalog.current) -> (title: String, message: String) {
        let units = max(0, after.units - before.units)
        let words = max(0, after.words - before.words)
        let key: String
        let values: [String: String]
        let fallback: String
        if let courseName, units > 0 {
            key = "content_new_units"
            values = ["course": courseName, "units": "\(units)", "words": "\(words)"]
            fallback = "content_updated_new_units".localizedFormat(courseName, units, words)
        } else if let courseName, words > 0 {
            key = "content_new_words"
            values = ["course": courseName, "words": "\(words)"]
            fallback = "content_updated_new_words".localizedFormat(courseName, words)
        } else {
            key = "content_updated"
            values = [:]
            fallback = "content_updated_message".localized()
        }
        if let remote = MessageCatalog.text(key, values: values, in: messages), let body = remote.body, !body.isEmpty {
            return (remote.title, body)
        }
        return ("content_updated_title".localized(), fallback)
    }
}
