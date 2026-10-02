//
//  ContentImporter.swift
//  LanguageApp
//
//  Imports course JSON into SwiftData. Upserts by `remoteId` so that a content update
//  (higher `version`) refreshes texts while keeping the learner's progress & SRS state.
//  Units / lessons / words that are no longer in the content are deleted.
//

import Foundation
import SwiftData

struct ContentImporter {
    let context: ModelContext

    /// JSON files in Resources/Content (without extension), in display order.
    static let bundledCourseFiles = ["course_en", "course_zh", "course_ja", "course_ko", "course_es", "course_vi"]

    func importBundledCourses(bundle: Bundle = .main) {
        for (index, file) in Self.bundledCourseFiles.enumerated() {
            importBundledCourse(file, order: index, bundle: bundle)
        }
        save()
    }

    /// Same as `importBundledCourses`, but gives the main thread back between courses so the splash
    /// keeps animating. A content update re-imports ~1,700 words, which took a few seconds in one go.
    /// (The models are main-actor isolated in this project, so the import itself stays on the main actor.)
    func importBundledCoursesInSteps(bundle: Bundle = .main) async {
        let start = Date()
        for (index, file) in Self.bundledCourseFiles.enumerated() {
            importBundledCourse(file, order: index, bundle: bundle)
            await Task.yield()
        }
        save()
        Logger.shared.info("Content import: \(Int(Date().timeIntervalSince(start) * 1000)) ms")
    }

    private func importBundledCourse(_ file: String, order: Int, bundle: Bundle) {
        guard let url = bundle.url(forResource: file, withExtension: "json") else {
            Logger.shared.error("Course file not found: \(file).json")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            try importCourse(from: data, order: order)
        } catch {
            Logger.shared.error("Failed to import \(file): \(error)")
        }
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Logger.shared.error("Failed to save imported content: \(error)")
        }
    }

    @discardableResult
    func importCourse(from data: Data, order: Int) throws -> Course {
        let dto = try JSONDecoder().decode(CourseDTO.self, from: data)
        return try upsert(dto, order: order)
    }

    // MARK: - Upsert

    private func upsert(_ dto: CourseDTO, order: Int) throws -> Course {
        let courseId = dto.id
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.remoteId == courseId })
        if let existing = try context.fetch(descriptor).first,
           existing.contentVersion >= dto.version {
            existing.order = order
            return existing
        }

        let course: Course
        if let existing = try context.fetch(descriptor).first {
            course = existing
        } else {
            course = Course(remoteId: dto.id)
            context.insert(course)
        }

        course.contentVersion = dto.version
        course.order = order
        course.name = dto.name
        course.nativeName = dto.nativeName
        course.flag = dto.flag
        course.speechLocale = dto.speechLocale
        course.readingLabel = dto.readingLabel

        // Look up existing content across the whole course so a lesson or word that moved
        // to another unit/lesson keeps its identity (and the learner's SRS progress).
        let oldUnits = course.units ?? []
        let oldLessons = oldUnits.flatMap { $0.lessons ?? [] }
        let oldItems = oldLessons.flatMap { $0.items ?? [] }
        var index = ExistingContent(
            units: Dictionary(oldUnits.map { ($0.remoteId, $0) }, uniquingKeysWith: { first, _ in first }),
            lessons: Dictionary(oldLessons.map { ($0.remoteId, $0) }, uniquingKeysWith: { first, _ in first }),
            items: Dictionary(oldItems.map { ($0.remoteId, $0) }, uniquingKeysWith: { first, _ in first })
        )

        for (unitIndex, unitDTO) in dto.units.enumerated() {
            let unit: CourseUnit
            if let found = index.units.removeValue(forKey: unitDTO.id) {
                unit = found
            } else {
                unit = CourseUnit(remoteId: unitDTO.id)
                context.insert(unit)
            }
            unit.course = course
            unit.order = unitIndex
            unit.title = unitDTO.title
            upsertLessons(unitDTO.lessons, into: unit, courseId: dto.id, index: &index)
        }

        // Whatever is left was removed from the content → delete it.
        index.items.values.forEach { context.delete($0) }
        index.lessons.values.forEach { context.delete($0) }
        index.units.values.forEach { context.delete($0) }
        if !(index.items.isEmpty && index.lessons.isEmpty && index.units.isEmpty) {
            Logger.shared.info("Removed from \(dto.id): \(index.units.count) units, \(index.lessons.count) lessons, \(index.items.count) words")
        }

        Logger.shared.info("Imported course \(dto.id) v\(dto.version)")
        return course
    }

    /// Existing objects of a course that haven't been matched to the new content yet.
    private struct ExistingContent {
        var units: [String: CourseUnit]
        var lessons: [String: Lesson]
        var items: [String: VocabItem]
    }

    private func upsertLessons(_ lessons: [LessonDTO], into unit: CourseUnit, courseId: String, index: inout ExistingContent) {
        for (lessonIndex, lessonDTO) in lessons.enumerated() {
            let lesson: Lesson
            if let found = index.lessons.removeValue(forKey: lessonDTO.id) {
                lesson = found
            } else {
                lesson = Lesson(remoteId: lessonDTO.id)
                context.insert(lesson)
            }
            lesson.unit = unit
            lesson.order = lessonIndex
            lesson.title = lessonDTO.title
            lesson.icon = lessonDTO.icon ?? "star.fill"
            lesson.xpReward = lessonDTO.xp ?? 10
            lesson.tip = lessonDTO.tip

            for (itemIndex, itemDTO) in lessonDTO.items.enumerated() {
                let item: VocabItem
                if let found = index.items.removeValue(forKey: itemDTO.id) {
                    item = found
                } else {
                    item = VocabItem(remoteId: itemDTO.id, courseId: courseId)
                    context.insert(item)
                }
                // Content only – SRS fields are intentionally untouched.
                item.lesson = lesson
                item.order = itemIndex
                item.courseId = courseId
                item.term = itemDTO.term
                item.reading = itemDTO.reading
                item.meaning = itemDTO.meaning
                item.example = itemDTO.example
                item.exampleTokens = itemDTO.exampleTokens
                item.exampleMeaning = itemDTO.exampleMeaning
            }
        }
    }
}
