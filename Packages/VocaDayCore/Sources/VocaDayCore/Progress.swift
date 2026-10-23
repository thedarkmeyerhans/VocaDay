import Foundation

/// Calendar day in the learner's time zone, formatted "yyyy-MM-dd".
public struct DayKey: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func date(calendar: Calendar = .current) -> Date? {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        guard let start = date(calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: days, to: start) else { return self }
        return DayKey(shifted, calendar: calendar)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension DayKey: CodingKeyRepresentable {
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public var codingKey: CodingKey { Key(stringValue: rawValue) }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(rawValue: codingKey.stringValue)
    }
}

public struct LearnerSettings: Codable, Hashable, Sendable {
    public var pair: LanguagePair
    public var mode: SelectionMode
    /// New words per day (at least one).
    public var newWordsPerDay: Int
    public var notificationsEnabled: Bool
    /// Time of the daily "word of the day" notification.
    public var notificationHour: Int
    public var notificationMinute: Int
    /// Evening reminder when the reviews of the day are still open.
    public var eveningReminderEnabled: Bool
    public var eveningReminderHour: Int
    /// Target recall probability for the scheduler.
    public var desiredRetention: Double
    /// Mix sentence exercises into the daily review.
    public var mixSentenceExercises: Bool
    public var onboardingCompleted: Bool

    public init(pair: LanguagePair = .germanTurkish, mode: SelectionMode = .standard,
                newWordsPerDay: Int = 1, notificationsEnabled: Bool = true,
                notificationHour: Int = 8, notificationMinute: Int = 0,
                eveningReminderEnabled: Bool = true, eveningReminderHour: Int = 19,
                desiredRetention: Double = 0.9, mixSentenceExercises: Bool = true,
                onboardingCompleted: Bool = false) {
        self.pair = pair
        self.mode = mode
        self.newWordsPerDay = newWordsPerDay
        self.notificationsEnabled = notificationsEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.eveningReminderEnabled = eveningReminderEnabled
        self.eveningReminderHour = eveningReminderHour
        self.desiredRetention = desiredRetention
        self.mixSentenceExercises = mixSentenceExercises
        self.onboardingCompleted = onboardingCompleted
    }

    public static let newWordsRange = 1...20
}

/// The new words assigned to one day.
public struct DayPlan: Codable, Hashable, Sendable {
    public var wordIDs: [String]
    /// Alphabet cursor before this day was planned, so later days can be
    /// re-planned without breaking the A–Z order.
    public var cursorBefore: Int

    public init(wordIDs: [String], cursorBefore: Int) {
        self.wordIDs = wordIDs
        self.cursorBefore = cursorBefore
    }
}

public struct DayStats: Codable, Hashable, Sendable {
    /// All graded answers of the day.
    public var reviews: Int = 0
    public var correct: Int = 0
    public var newWords: Int = 0
    /// Time spent in sessions and tests.
    public var seconds: Double = 0
    /// Answers to words that were already in the review phase – the basis
    /// of the measured retention ("true retention").
    public var reviewTotal: Int = 0
    public var reviewCorrect: Int = 0

    public init(reviews: Int = 0, correct: Int = 0, newWords: Int = 0, seconds: Double = 0,
                reviewTotal: Int = 0, reviewCorrect: Int = 0) {
        self.reviews = reviews
        self.correct = correct
        self.newWords = newWords
        self.seconds = seconds
        self.reviewTotal = reviewTotal
        self.reviewCorrect = reviewCorrect
    }

    private enum CodingKeys: String, CodingKey {
        case reviews, correct, newWords, seconds, reviewTotal, reviewCorrect
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reviews = try c.decodeIfPresent(Int.self, forKey: .reviews) ?? 0
        correct = try c.decodeIfPresent(Int.self, forKey: .correct) ?? 0
        newWords = try c.decodeIfPresent(Int.self, forKey: .newWords) ?? 0
        seconds = try c.decodeIfPresent(Double.self, forKey: .seconds) ?? 0
        reviewTotal = try c.decodeIfPresent(Int.self, forKey: .reviewTotal) ?? 0
        reviewCorrect = try c.decodeIfPresent(Int.self, forKey: .reviewCorrect) ?? 0
    }
}

/// Everything the app stores about one learner.
public struct LearnerProgress: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var settings: LearnerSettings
    /// Index of the next letter in the A–Z rotation.
    public var letterCursor: Int
    public var plans: [DayKey: DayPlan]
    /// Memory state of every word that has been introduced.
    public var cards: [String: CardState]
    public var stats: [DayKey: DayStats]
    /// Results of finished vocabulary tests, oldest first.
    public var tests: [TestResult]

    public init(settings: LearnerSettings = LearnerSettings()) {
        version = Self.currentVersion
        self.settings = settings
        letterCursor = 0
        plans = [:]
        cards = [:]
        stats = [:]
        tests = []
    }

    private enum CodingKeys: String, CodingKey {
        case version, settings, letterCursor, plans, cards, stats, tests
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        settings = try c.decode(LearnerSettings.self, forKey: .settings)
        letterCursor = try c.decodeIfPresent(Int.self, forKey: .letterCursor) ?? 0
        plans = try c.decodeIfPresent([DayKey: DayPlan].self, forKey: .plans) ?? [:]
        cards = try c.decodeIfPresent([String: CardState].self, forKey: .cards) ?? [:]
        stats = try c.decodeIfPresent([DayKey: DayStats].self, forKey: .stats) ?? [:]
        tests = try c.decodeIfPresent([TestResult].self, forKey: .tests) ?? []
    }

    public static func decode(from data: Data) throws -> LearnerProgress {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LearnerProgress.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    // MARK: Queries

    public func isIntroduced(_ wordID: String) -> Bool { cards[wordID] != nil }

    /// Words planned for `day` or earlier that have not been introduced yet.
    public func pendingNewWords(upTo day: DayKey) -> [String] {
        plans.keys.filter { $0 <= day }.sorted().flatMap { key in
            plans[key]?.wordIDs.filter { !isIntroduced($0) } ?? []
        }
    }

    /// Introduced words due at or before `date`, most overdue first.
    public func dueWordIDs(at date: Date) -> [String] {
        cards.filter { $0.value.due <= date }
            .sorted { $0.value.due < $1.value.due }
            .map(\.key)
    }

    /// Number of consecutive days with at least one review, counting back from
    /// today (or from yesterday, if nothing was done today yet).
    public func streak(today: DayKey, calendar: Calendar = .current) -> Int {
        var day = today
        if (stats[day]?.reviews ?? 0) == 0 { day = day.adding(days: -1, calendar: calendar) }
        var count = 0
        while (stats[day]?.reviews ?? 0) > 0 {
            count += 1
            day = day.adding(days: -1, calendar: calendar)
        }
        return count
    }

    // MARK: Updates

    public mutating func record(wordID: String, rating: Rating, at date: Date,
                                scheduler: FSRSScheduler, calendar: Calendar = .current) {
        let previous = cards[wordID]
        cards[wordID] = scheduler.schedule(previous, rating: rating, at: date)
        let day = DayKey(date, calendar: calendar)
        var dayStats = stats[day] ?? DayStats()
        dayStats.reviews += 1
        if rating != .again { dayStats.correct += 1 }
        if previous == nil { dayStats.newWords += 1 }
        if previous?.phase == .review {
            dayStats.reviewTotal += 1
            if rating != .again { dayStats.reviewCorrect += 1 }
        }
        stats[day] = dayStats
    }

    /// Adds time spent learning to the statistics of the day.
    public mutating func addStudyTime(_ seconds: TimeInterval, at date: Date, calendar: Calendar = .current) {
        guard seconds > 0 else { return }
        let day = DayKey(date, calendar: calendar)
        var dayStats = stats[day] ?? DayStats()
        dayStats.seconds += min(seconds, 2 * 3600)
        stats[day] = dayStats
    }

    /// Word ids introduced on the days `from`...`to` according to the plans.
    public func wordsIntroduced(from start: DayKey, to end: DayKey) -> [String] {
        plans.filter { $0.key >= start && $0.key <= end }
            .sorted { $0.key < $1.key }
            .flatMap { $0.value.wordIDs.filter(isIntroduced) }
    }
}
