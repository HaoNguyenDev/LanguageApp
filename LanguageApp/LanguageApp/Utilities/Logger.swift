//
//  Logger.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 21/7/25.
//

import Foundation

enum LogLevel: String {
    case debug = "🐞 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
}

final class Logger {
    static let shared = Logger()

    // MARK: - Configuration
    var isEnabled: Bool = true
    var enabledLevels: Set<LogLevel> = [.debug, .info, .warning, .error]

    private init() {}

    // MARK: - Public API
    private func log(_ level: LogLevel,
             _ message: @autoclosure () -> String,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        guard isEnabled, enabledLevels.contains(level) else { return }

        let filename = (file as NSString).lastPathComponent
        let timestamp = Logger.dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(filename):\(line) → \(function)] - \(message())"
        #if DEBUG
        print(logMessage)
        #endif
        //Can record to log file here
    }

    func debug(_ message: @autoclosure () -> String,
               file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message(), file: file, function: function, line: line)
    }

    func info(_ message: @autoclosure () -> String,
              file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message(), file: file, function: function, line: line)
    }

    func warning(_ message: @autoclosure () -> String,
                 file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message(), file: file, function: function, line: line)
    }

    func error(_ message: @autoclosure () -> String,
               file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message(), file: file, function: function, line: line)
    }

    // MARK: - Helpers
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
