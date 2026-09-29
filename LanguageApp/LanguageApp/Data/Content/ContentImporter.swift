//
//  ContentImporter.swift
//  LanguageApp
//
//  Imports course JSON into SwiftData. Upserts by `remoteId` so that a content update
//  (higher `version`) refreshes texts while keeping the learner's progress & SRS state.
//

import Foundation
import SwiftData

struct ContentImporter {
    let context: ModelContext

    /// JSON files in Resources/Content (without extension), in display order.
    static let bundledCourseFiles = ["course_en", "course_zh", "course_ja", "course_ko", "course_es", "course_vi"]

    func importBundledCourses(bundle: Bundle = .main) {
        for (index, file) in Self.bundledCourseFiles.enumerated() {
            guard let url = bundle.url(forResource: file, withExtension: "json") else {
                Logger.shared.error("Course file not found: \(file).json")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                try importCourse(from: data, order: index)
            } catch {
                Logger.shared.error("Failed to import \(file): \(error)")
            }
        }
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

        let existingUnits = Dictionary((course.units ?? []).map { ($0.remoteId, $0) },
                                       uniquingKeysWith: { first, _ in first })

        for (unitIndex, unitDTO) in dto.units.enumerated() {
            let unit: CourseUnit
            if let found = existingUnits[unitDTO.id] {
                unit = found
            } else {
                unit = CourseUnit(remoteId: unitDTO.id)
                context.insert(unit)
                unit.course = course
            }
            unit.order = unitIndex
            unit.title = unitDTO.title
            upsertLessons(unitDTO.lessons, into: unit, courseId: dto.id)
        }

        Logger.shared.info("Imported course \(dto.id) v\(dto.version)")
        return course
    }

    private func upsertLessons(_ lessons: [LessonDTO], into unit: CourseUnit, courseId: String) {
        let existingLessons = Dictionary((unit.lessons ?? []).map { ($0.remoteId, $0) },
                                         uniquingKeysWith: { first, _ in first })

        for (lessonIndex, lessonDTO) in lessons.enumerated() {
            let lesson: Lesson
            if let found = existingLessons[lessonDTO.id] {
                lesson = found
            } else {
                lesson = Lesson(remoteId: lessonDTO.id)
                context.insert(lesson)
                lesson.unit = unit
            }
            lesson.order = lessonIndex
            lesson.title = lessonDTO.title
            lesson.icon = lessonDTO.icon ?? "star.fill"
            lesson.xpReward = lessonDTO.xp ?? 10

            let existingItems = Dictionary((lesson.items ?? []).map { ($0.remoteId, $0) },
                                           uniquingKeysWith: { first, _ in first })
            for (itemIndex, itemDTO) in lessonDTO.items.enumerated() {
                let item: VocabItem
                if let found = existingItems[itemDTO.id] {
                    item = found
                } else {
                    item = VocabItem(remoteId: itemDTO.id, courseId: courseId)
                    context.insert(item)
                    item.lesson = lesson
                }
                // Content only – SRS fields are intentionally untouched.
                item.order = itemIndex
                item.courseId = courseId
                item.term = itemDTO.term
                item.reading = itemDTO.reading
                item.meaning = itemDTO.meaning
                item.example = itemDTO.example
                item.exampleMeaning = itemDTO.exampleMeaning
            }
        }
    }
}
