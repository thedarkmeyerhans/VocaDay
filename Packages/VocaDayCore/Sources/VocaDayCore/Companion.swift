import Foundation

// MARK: - Places

/// A place where VocaDay shows a new word on the home screen.
public struct LearningPlace: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// Meters.
    public var radius: Double

    public init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, radius: Double = 150) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

/// What happens after a widget word was completed the configured number of times.
public enum WidgetCompletion: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Show the next new word right away.
    case nextWord
    /// The word counts as done until the next configured time.
    case done

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .nextWord: return "Nächstes Wort zeigen"
        case .done: return "Bis zur nächsten Uhrzeit erledigt"
        }
    }
}

// MARK: - Gate quiz ("Zwangsmodus")

/// Daily rotation of words for the gate quiz: words are asked in turn until each
/// was answered correctly `target` times, then new words join.
public struct GateState: Codable, Hashable, Sendable {
    public var day: DayKey?
    public var pool: [String] = []
    public var correct: [String: Int] = [:]
    public var known: [String] = []
    public var lastWordID: String?

    public init() {}
}

public enum GateQuiz {
    public static let poolSize = 5

    /// The next word to ask, or nil if there is no word at all.
    /// `isNew` means the word was never learned and needs an introduction first.
    public static func nextWord<G: RandomNumberGenerator>(
        progress: inout LearnerProgress, words: WordIndex, now: Date, scheduler: FSRSScheduler,
        planner: DailyPlanner, calendar: Calendar = .current, using generator: inout G
    ) -> (word: Word, isNew: Bool)? {
        let today = DayKey(now, calendar: calendar)
        let target = max(1, progress.settings.gateWordTarget)
        if progress.gate.day != today {
            progress.gate = GateState()
            progress.gate.day = today
            progress.gate.pool = initialPool(progress: progress, words: words, now: now, scheduler: scheduler,
                                             today: today)
        }

        var open = progress.gate.pool.filter { (progress.gate.correct[$0] ?? 0) < target && words[$0] != nil }
        if open.isEmpty {
            let more = refill(progress: &progress, words: words, now: now, scheduler: scheduler, planner: planner,
                              today: today, using: &generator)
            progress.gate.pool.append(contentsOf: more)
            open = more
        }
        guard !open.isEmpty else { return nil }

        // Rotate: fewest correct answers first, never the same word twice in a row if avoidable.
        let candidates = open.count > 1 ? open.filter { $0 != progress.gate.lastWordID } : open
        let lowest = candidates.map { progress.gate.correct[$0] ?? 0 }.min() ?? 0
        let pick = candidates.filter { (progress.gate.correct[$0] ?? 0) == lowest }.randomElement(using: &generator)
            ?? candidates[0]
        progress.gate.lastWordID = pick
        guard let word = words[pick] else { return nil }
        return (word, progress.cards[pick] == nil)
    }

    /// Counts an answer; a wrong answer resets the word's count.
    public static func record(wordID: String, correct: Bool, progress: inout LearnerProgress) {
        let target = max(1, progress.settings.gateWordTarget)
        let count = correct ? (progress.gate.correct[wordID] ?? 0) + 1 : 0
        progress.gate.correct[wordID] = count
        if count >= target, !progress.gate.known.contains(wordID) {
            progress.gate.known.append(wordID)
        }
    }

    static func initialPool(progress: LearnerProgress, words: WordIndex, now: Date, scheduler: FSRSScheduler,
                            today: DayKey) -> [String] {
        var pool: [String] = []
        func add(_ ids: [String]) {
            for id in ids where pool.count < poolSize && !pool.contains(id) && words[id] != nil { pool.append(id) }
        }
        add(Array(progress.dueWordIDs(at: now).prefix(3)))
        add(progress.plans[today]?.wordIDs ?? [])
        add(weakest(progress: progress, now: now, scheduler: scheduler))
        if pool.isEmpty { add(progress.pendingNewWords(upTo: today)) }
        return pool
    }

    static func refill<G: RandomNumberGenerator>(
        progress: inout LearnerProgress, words: WordIndex, now: Date, scheduler: FSRSScheduler,
        planner: DailyPlanner, today: DayKey, using generator: inout G
    ) -> [String] {
        let used = Set(progress.gate.pool)
        let learned = weakest(progress: progress, now: now, scheduler: scheduler).filter { !used.contains($0) }
        if !learned.isEmpty { return Array(learned.prefix(3)) }
        // Everything known: bring a new word.
        return planner.addExtraWords(1, to: &progress, today: today, using: &generator).map(\.id)
    }

    static func weakest(progress: LearnerProgress, now: Date, scheduler: FSRSScheduler) -> [String] {
        progress.cards
            .sorted { scheduler.retrievability(of: $0.value, at: now) < scheduler.retrievability(of: $1.value, at: now) }
            .map(\.key)
    }
}

// MARK: - Widget

public struct WidgetState: Codable, Hashable, Sendable {
    /// After a completion in "done" mode: show the check mark until this time.
    public var doneUntil: Date?
    /// A place was entered: show the word even before the first time of the day.
    public var revealedDay: DayKey?

    public init() {}
}

/// What the widget shows at one point in time. Written by the app into the
/// shared app group container, read by the widget extension.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public struct WordInfo: Codable, Hashable, Sendable {
        public let id: String
        public let translation: String
        public let native: String
        public let article: String?
        public let partOfSpeech: String
        public let example: String
        public let exampleNative: String
        public let irregular: Bool

        public init(_ word: Word) {
            id = word.id
            translation = word.translation
            native = word.native
            article = word.article
            partOfSpeech = word.partOfSpeech.displayName
            example = word.cloze.plain
            exampleNative = word.exampleNative
            irregular = word.turkishVerb?.isIrregular == true
        }

        public var nativeWithArticle: String { article.map { "\($0) \(native)" } ?? native }
    }

    public struct Entry: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable { case word, done, waiting }

        public let date: Date
        public let kind: Kind
        public let word: WordInfo?
        /// For `.waiting` and `.done`: when the next word appears.
        public let next: Date?

        public init(date: Date, kind: Kind, word: WordInfo?, next: Date?) {
            self.date = date
            self.kind = kind
            self.word = word
            self.next = next
        }
    }

    public let generatedAt: Date
    public let entries: [Entry]
    public let streak: Int
    public let learned: Int
    public let due: Int
    public let repetitions: Int

    public init(generatedAt: Date, entries: [Entry], streak: Int, learned: Int, due: Int, repetitions: Int) {
        self.generatedAt = generatedAt
        self.entries = entries
        self.streak = streak
        self.learned = learned
        self.due = due
        self.repetitions = repetitions
    }

    /// The entry valid at `date`.
    public func entry(at date: Date) -> Entry? {
        entries.last { $0.date <= date } ?? entries.first
    }
}

public enum WidgetPlanner {
    /// The next new word: today's (or missed) planned words first, then the coming days.
    public static func nextWord(progress: LearnerProgress, words: WordIndex, today: DayKey) -> Word? {
        progress.plans.keys.sorted()
            .flatMap { progress.plans[$0]?.wordIDs ?? [] }
            .lazy
            .filter { progress.cards[$0] == nil }
            .compactMap { words[$0] }
            .first
    }

    /// Configured times as dates for the day of `date`.
    static func slots(on day: Date, hours: [Int], calendar: Calendar) -> [Date] {
        hours.sorted().compactMap { hour in
            calendar.date(bySettingHour: min(max(hour, 0), 23), minute: 0, second: 0, of: day)
        }
    }

    /// The first configured time after `date`.
    public static func nextSlot(after date: Date, hours: [Int], calendar: Calendar = .current) -> Date? {
        let hours = hours.isEmpty ? [8] : hours
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let slot = slots(on: day, hours: hours, calendar: calendar).first(where: { $0 > date }) { return slot }
        }
        return nil
    }

    public static func snapshot(progress: LearnerProgress, words: WordIndex, now: Date,
                                calendar: Calendar = .current) -> WidgetSnapshot {
        let settings = progress.settings
        let hours = settings.widgetHours.isEmpty ? [8] : settings.widgetHours
        let today = DayKey(now, calendar: calendar)
        let word = nextWord(progress: progress, words: words, today: today).map(WidgetSnapshot.WordInfo.init)

        // Points in time at which the content may change.
        var dates = [now]
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            dates += slots(on: day, hours: hours, calendar: calendar).filter { $0 > now }
            if let midnight = calendar.date(byAdding: .day, value: offset + 1, to: calendar.startOfDay(for: now)) {
                dates.append(midnight)
            }
        }
        if let done = progress.widget.doneUntil, done > now { dates.append(done) }
        dates = Array(Set(dates)).sorted()

        let entries = dates.map { date -> WidgetSnapshot.Entry in
            if let done = progress.widget.doneUntil, date < done {
                return .init(date: date, kind: .done, word: nil, next: done)
            }
            let day = DayKey(date, calendar: calendar)
            let first = slots(on: date, hours: hours, calendar: calendar).first ?? date
            if date < first && progress.widget.revealedDay != day {
                return .init(date: date, kind: .waiting, word: nil, next: first)
            }
            guard let word else { return .init(date: date, kind: .done, word: nil, next: nil) }
            return .init(date: date, kind: .word, word: word, next: nil)
        }
        return WidgetSnapshot(
            generatedAt: now, entries: entries, streak: progress.streak(today: today, calendar: calendar),
            learned: progress.cards.count, due: progress.dueWordIDs(at: now).count,
            repetitions: settings.widgetRepetitions)
    }

    /// Called when the widget word was practised the configured number of times.
    public static func completed(progress: inout LearnerProgress, now: Date, calendar: Calendar = .current) {
        switch progress.settings.widgetAfterCompletion {
        case .nextWord:
            progress.widget.doneUntil = nil
        case .done:
            progress.widget.doneUntil = nextSlot(after: now, hours: progress.settings.widgetHours, calendar: calendar)
        }
    }

    /// A saved place was entered: show the next word now.
    public static func placeEntered(progress: inout LearnerProgress, now: Date, calendar: Calendar = .current) {
        progress.widget.doneUntil = nil
        progress.widget.revealedDay = DayKey(now, calendar: calendar)
    }
}
