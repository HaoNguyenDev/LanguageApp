//
//  PersistenceController.swift
//  LanguageApp
//

import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Course.self,
        CourseUnit.self,
        Lesson.self,
        VocabItem.self,
        DailyActivity.self
    ])

    /// - Parameter inMemory: use for previews & tests.
    /// Phase 2: switch `cloudKitDatabase` to `.automatic` (+ iCloud capability) for sync.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema,
                                               isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// In-memory container pre-filled with bundled courses for SwiftUI previews.
    static let preview: ModelContainer = {
        let container = makeContainer(inMemory: true)
        ContentImporter(context: container.mainContext).importBundledCourses()
        return container
    }()
}
