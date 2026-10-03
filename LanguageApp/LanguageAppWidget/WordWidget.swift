//
//  WordWidget.swift
//  LanguageAppWidget
//
//  Home screen (small / medium / large) and lock screen (circular / rectangular / inline) widget with the words of the word reminders (latest lesson + words graded
//  Again / Hard): 1, 2 or 5 words, new ones every word-reminder interval, a colorful background that changes with
//  them, a live progress bar until the next words and a ↻ button to skip ahead.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct WordEntry: TimelineEntry {
    let date: Date
    /// Rotation step (clock slot + skips) – picks the words and the background.
    let step: Int
    let words: [WordWidgetData.Word]
    let data: WordWidgetData
    /// When the next words appear.
    let nextDate: Date
}

struct WordProvider: TimelineProvider {
    /// Entries planned ahead; WidgetKit asks again after the last one.
    static let entryCount = 12

    func placeholder(in context: Context) -> WordEntry {
        Self.sample(for: context.family)
    }

    /// Words shown at the same time: 1 on small, 2 on medium (like a notification), 5 on large.
    static func wordsPerEntry(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemLarge, .systemExtraLarge: return 5
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return 1
        default: return WordWidgetData.wordsPerEntry
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        let entries = Self.entries(now: .now, data: WordWidgetData.load(), offset: WordWidgetData.offset(), count: 1,
                                   wordsPerEntry: Self.wordsPerEntry(for: context.family))
        completion(context.isPreview && (entries.first?.words.isEmpty ?? true)
                   ? Self.sample(for: context.family) : entries[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let entries = Self.entries(now: .now, data: WordWidgetData.load(), offset: WordWidgetData.offset(),
                                   count: Self.entryCount, wordsPerEntry: Self.wordsPerEntry(for: context.family))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func entries(now: Date, data: WordWidgetData?, offset: Int, count: Int,
                        wordsPerEntry: Int = WordWidgetData.wordsPerEntry) -> [WordEntry] {
        let data = data ?? .empty
        let interval = data.intervalMinutes
        let first = WordWidgetData.slot(at: now, intervalMinutes: interval)
        return (0..<max(count, 1)).map { index in
            let slot = first + index
            let step = slot + offset
            return WordEntry(date: index == 0 ? now : WordWidgetData.startOfSlot(slot, intervalMinutes: interval),
                             step: step,
                             words: WordWidgetData.words(slot: step, pool: data.words, count: wordsPerEntry),
                             data: data,
                             nextDate: WordWidgetData.startOfSlot(slot + 1, intervalMinutes: interval))
        }
    }

    static let sampleWords = [
        WordWidgetData.Word(id: "1", term: "こんにちは", reading: "konnichiwa", meaning: "hello", isHard: false),
        WordWidgetData.Word(id: "2", term: "ありがとう", reading: "arigatou", meaning: "thank you", isHard: true, level: 1),
        WordWidgetData.Word(id: "3", term: "水", reading: "mizu", meaning: "water", isHard: false),
        WordWidgetData.Word(id: "4", term: "学校", reading: "gakkou", meaning: "school", isHard: false),
        WordWidgetData.Word(id: "5", term: "おいしい", reading: "oishii", meaning: "delicious", isHard: true, level: 2)
    ]

    static func sample(for family: WidgetFamily) -> WordEntry {
        let words = Array(sampleWords.prefix(wordsPerEntry(for: family)))
        let data = WordWidgetData(courseName: "Japanese", intervalMinutes: 30, words: sampleWords, texts: .english,
                                  updatedAt: .now)
        return WordEntry(date: .now, step: 0, words: words, data: data, nextDate: .now.addingTimeInterval(30 * 60))
    }
}

// MARK: - Views

struct WordWidgetView: View {
    let entry: WordEntry

    /// Background colors, one pair per step so each new set of words feels fresh.
    /// 12 three-color gradients, one per step. Mid-dark tones so white text stays readable and
    /// the bright cards of hard words stand out on every one of them.
    private static let palettes: [[Color]] = [
        [rgb(0x5B4FF2), rgb(0x8A3FE0), rgb(0xC03CC8)],   // indigo → violet → magenta
        [rgb(0xF2545B), rgb(0xD63A7A), rgb(0x8E3FC0)],   // coral → raspberry → purple
        [rgb(0x0F9D8F), rgb(0x1479B8), rgb(0x2D4FB5)],   // teal → ocean → royal blue
        [rgb(0xE8743B), rgb(0xD9434F), rgb(0xA62D6B)],   // tangerine → red → plum
        [rgb(0x2E7D32), rgb(0x0E8A7D), rgb(0x1565A8)],   // forest → teal → blue
        [rgb(0x3949AB), rgb(0x1E88E5), rgb(0x00A3B4)],   // indigo → sky → cyan
        [rgb(0xC2185B), rgb(0x7B1FA2), rgb(0x4527A0)],   // pink → purple → deep violet
        [rgb(0x00897B), rgb(0x43A047), rgb(0x7CB342)],   // jade → green → lime
        [rgb(0x6D4C41), rgb(0xA0522D), rgb(0xD2691E)],   // cocoa → sienna → copper
        [rgb(0x283593), rgb(0x6A1B9A), rgb(0xAD1457)],   // midnight → grape → berry
        [rgb(0x0277BD), rgb(0x5E35B1), rgb(0xD81B60)],   // azure → violet → rose
        [rgb(0x37474F), rgb(0x455A64), rgb(0x00796B)]    // slate → steel → pine
    ]

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    private var palette: [Color] {
        let count = Self.palettes.count
        return Self.palettes[((entry.step % count) + count) % count]
    }

    @Environment(\.widgetFamily) private var family

    private var isLockScreen: Bool {
        let lockScreenFamilies: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        return lockScreenFamilies.contains(family)
    }

    var body: some View {
        if isLockScreen {
            // The lock screen tints widgets itself and drops the background.
            LockScreenWordView(entry: entry, family: family)
                .containerBackground(for: .widget) { Color.clear }
        } else {
            homeScreenBody
        }
    }

    private var homeScreenBody: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 8) {
            header
            if entry.words.isEmpty {
                Text(entry.data.texts.empty)
                    .font(family == .systemSmall ? .caption.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                words
                    // New words slide in when the entry changes.
                    .id(entry.step)
                    .transition(.push(from: .bottom))
                progressBar
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    @ViewBuilder
    private var words: some View {
        switch family {
        case .systemSmall:
            if let word = entry.words.first {
                WordCard(word: word, hardLabel: entry.data.texts.hard, style: .big)
            }
        case .systemLarge, .systemExtraLarge:
            VStack(spacing: 5) {
                ForEach(entry.words) { word in
                    WordRow(word: word, hardLabel: entry.data.texts.hard)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        default:
            HStack(spacing: 8) {
                ForEach(entry.words) { word in
                    WordCard(word: word, hardLabel: entry.data.texts.hard, style: .regular)
                }
            }
        }
    }

    /// Fills up until the next words appear.
    private var progressBar: some View {
        ProgressView(timerInterval: entry.date...max(entry.nextDate, entry.date.addingTimeInterval(1)),
                     countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(.white)
        .opacity(0.7)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
            // Small: the course name only (no room for both).
            Text(family == .systemSmall && !entry.data.courseName.isEmpty ? entry.data.courseName : entry.data.texts.title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            if family != .systemSmall, !entry.data.courseName.isEmpty {
                Text(entry.data.courseName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2), in: .capsule)
            }
            Spacer(minLength: 4)
            if !entry.words.isEmpty {
                Button(intent: NextWordsIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.bold))
                        .padding(6)
                        .background(.white.opacity(0.2), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.data.texts.next)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct WordCard: View {
    enum Style { case regular, big }

    let word: WordWidgetData.Word
    let hardLabel: String
    let style: Style

    private var look: DifficultyStyle { DifficultyStyle(difficulty: word.difficulty) }

    private var showsReading: Bool {
        guard let reading = word.reading else { return false }
        return !reading.isEmpty && reading != word.term
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(word.term)
                // The word to learn is clearly bigger than its meaning.
                .font(.system(size: style == .big ? 40 : 34, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if showsReading, let reading = word.reading {
                Text(reading)
                    .font(style == .big ? .caption.weight(.medium) : .caption2.weight(.medium))
                    .opacity(0.8)
                    .lineLimit(1)
            }
            Text(word.meaning)
                .font(style == .big ? .footnote.weight(.medium) : .caption.weight(.medium))
                .lineLimit(style == .big ? 3 : 2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if word.difficulty != .normal {
                Label(hardLabel, systemImage: look.badgeIcon)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(look.badgeBackground, in: .capsule)
            }
        }
        .foregroundStyle(look.foreground)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { look.background(cornerRadius: 12) }
    }
}

/// Lock screen: circular (word inside a ring that fills until the next word), rectangular
/// (word, reading, meaning) and inline (one line above the clock).
private struct LockScreenWordView: View {
    let entry: WordEntry
    let family: WidgetFamily

    private var word: WordWidgetData.Word? { entry.words.first }

    private var reading: String? {
        guard let word, let reading = word.reading, !reading.isEmpty, reading != word.term else { return nil }
        return reading
    }

    private var timer: ClosedRange<Date> {
        entry.date...max(entry.nextDate, entry.date.addingTimeInterval(1))
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: rectangular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let word {
                ProgressView(timerInterval: timer, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    Text(word.term)
                        .font(.system(size: 14, weight: .heavy))
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
                .progressViewStyle(.circular)
                .widgetAccentable()
            } else {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
            }
        }
        .accessibilityLabel(word.map { "\($0.term), \($0.meaning)" } ?? entry.data.texts.title)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let word {
                HStack(spacing: 4) {
                    Image(systemName: word.isHard ? "arrow.triangle.2.circlepath" : "sparkles")
                        .font(.caption2.weight(.bold))
                    Text(word.term)
                        .font(.headline.weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .widgetAccentable()
                if let reading {
                    Text(reading)
                        .font(.caption2)
                        .lineLimit(1)
                }
                Text(word.meaning)
                    .font(.caption.weight(.semibold))
                    .lineLimit(reading == nil ? 2 : 1)
            } else {
                Text(entry.data.texts.title)
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.data.texts.empty)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only text and an image are shown above the clock.
    @ViewBuilder
    private var inline: some View {
        if let word {
            Text("\(Image(systemName: "sparkles")) \(word.term) – \(word.meaning)")
        } else {
            Text("\(Image(systemName: "sparkles")) \(entry.data.texts.title)")
        }
    }
}

/// One line of the large widget: word + reading on the left, meaning on the right.
private struct WordRow: View {
    let word: WordWidgetData.Word
    let hardLabel: String

    private var look: DifficultyStyle { DifficultyStyle(difficulty: word.difficulty) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(word.term)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let reading = word.reading, !reading.isEmpty, reading != word.term {
                    Text(reading)
                        .font(.caption2.weight(.medium))
                        .opacity(0.8)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(word.meaning)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
            if word.difficulty != .normal {
                Image(systemName: look.badgeIcon)
                    .font(.caption.weight(.bold))
                    .accessibilityLabel(hardLabel)
            }
        }
        .foregroundStyle(look.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        // Grows with the space but stays a row when the pool has only a few words.
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 66)
        .background { look.background(cornerRadius: 12) }
    }
}

// MARK: - Difficulty colors

/// Normal words sit on a light glass card; Hard words get a bright amber card and Again words a
/// solid white card with red text – the harder the word, the more it stands out.
private struct DifficultyStyle {
    let difficulty: WordWidgetData.Difficulty

    private static let brown = Color(red: 0.36, green: 0.18, blue: 0.0)
    private static let crimson = Color(red: 0.80, green: 0.07, blue: 0.24)

    var foreground: Color {
        switch difficulty {
        case .normal: return .white
        case .hard: return Self.brown      // dark brown on amber
        case .again: return Self.crimson   // crimson on white
        }
    }

    var badgeBackground: Color {
        switch difficulty {
        case .normal: return .white.opacity(0.25)
        case .hard: return Self.brown.opacity(0.15)
        case .again: return Self.crimson.opacity(0.12)
        }
    }

    var badgeIcon: String {
        difficulty == .again ? "exclamationmark.arrow.circlepath" : "arrow.triangle.2.circlepath"
    }

    @ViewBuilder
    func background(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch difficulty {
        case .normal:
            shape.fill(.white.opacity(0.15))
        case .hard:
            shape.fill(LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.30),
                                               Color(red: 1.0, green: 0.65, blue: 0.15)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        case .again:
            shape.fill(.white)
                .overlay(shape.strokeBorder(Color(red: 1.0, green: 0.30, blue: 0.40), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        }
    }
}

// MARK: - Widget

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WordWidgetData.widgetKind, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Words to remember")
        .description("New words from your latest lesson and the ones to review again.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    WordWidget()
} timeline: {
    WordProvider.sample(for: .systemSmall)
}

#Preview(as: .systemMedium) {
    WordWidget()
} timeline: {
    WordProvider.sample(for: .systemMedium)
}

#Preview(as: .systemLarge) {
    WordWidget()
} timeline: {
    WordProvider.sample(for: .systemLarge)
}

#Preview(as: .accessoryRectangular) {
    WordWidget()
} timeline: {
    WordProvider.sample(for: .accessoryRectangular)
}

#Preview(as: .accessoryCircular) {
    WordWidget()
} timeline: {
    WordProvider.sample(for: .accessoryCircular)
}

#Preview(as: .accessoryInline) {
    WordWidget()
} timeline: {
    WordProvider.sample(for: .accessoryInline)
}
