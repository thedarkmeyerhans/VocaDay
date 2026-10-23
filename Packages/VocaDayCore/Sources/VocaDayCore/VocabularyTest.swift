import Foundation

/// Which learned words a vocabulary test asks.
public enum TestScope: Hashable, Codable, Sendable {
    /// Every introduced word.
    case all
    /// The words with the lowest predicted recall right now.
    case weakest(Int)
    /// A random sample.
    case random(Int)
    /// Words introduced during the last `days` days.
    case recent(days: Int)
    /// A fixed list, e.g. the mistakes of the previous test.
    case words([String])

    public var displayName: String {
        switch self {
        case .all: return "Alle Wörter"
        case .weakest(let count): return "Die \(count) schwächsten"
        case .random(let count): return "\(count) zufällige"
        case .recent(let days): return days == 7 ? "Diese Woche" : "Letzte \(days) Tage"
        case .words: return "Fehler üben"
        }
    }
}

public enum TestDirection: String, Codable, CaseIterable, Sendable {
    case toTarget, toNative, mixed

    public var displayName: String {
        switch self {
        case .toTarget: return "Deutsch → Türkisch"
        case .toNative: return "Türkisch → Deutsch"
        case .mixed: return "Gemischt"
        }
    }
}

public enum TestAnswerMode: String, Codable, CaseIterable, Sendable {
    case choice, typing

    public var displayName: String {
        switch self {
        case .choice: return "Auswählen"
        case .typing: return "Eintippen"
        }
    }
}

/// Outcome of a finished vocabulary test, kept for the statistics.
public struct TestResult: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let scope: TestScope
    public let direction: TestDirection
    public let answerMode: TestAnswerMode
    /// Number of different words asked.
    public let total: Int
    /// Words answered correctly on the first attempt.
    public let correctFirstTry: Int
    public let seconds: Double
    /// Words answered wrongly on the first attempt.
    public let mistakes: [String]

    public init(id: UUID = UUID(), date: Date, scope: TestScope, direction: TestDirection,
                answerMode: TestAnswerMode, total: Int, correctFirstTry: Int, seconds: Double,
                mistakes: [String]) {
        self.id = id
        self.date = date
        self.scope = scope
        self.direction = direction
        self.answerMode = answerMode
        self.total = total
        self.correctFirstTry = correctFirstTry
        self.seconds = seconds
        self.mistakes = mistakes
    }

    public var score: Double { total == 0 ? 0 : Double(correctFirstTry) / Double(total) }
}

/// A test over learned words, built as a mastery loop:
///
/// 1. Every selected word is asked once, in random order (interleaved).
/// 2. Only the first attempt counts for the score and is fed into the memory
///    model, so a test is an honest measurement and a real retrieval practice.
/// 3. Wrongly answered words come back in a mistakes round with an easier
///    exercise until they are answered correctly (at most three times),
///    so the test never ends on an error.
public struct VocabularyTest: Sendable {
    public let scope: TestScope
    public let direction: TestDirection
    public let answerMode: TestAnswerMode
    public let startedAt: Date

    public private(set) var items: [SessionItem]
    public private(set) var position = 0
    /// Number of items in the first round (= number of words).
    public let wordCount: Int
    /// First-attempt result per word.
    public private(set) var firstAttempts: [String: Bool] = [:]
    private var attempts: [String: Int] = [:]
    private var nextID: Int

    public static let maxAttempts = 3

    init(scope: TestScope, direction: TestDirection, answerMode: TestAnswerMode,
         items: [SessionItem], startedAt: Date) {
        self.scope = scope
        self.direction = direction
        self.answerMode = answerMode
        self.items = items
        self.wordCount = items.count
        self.startedAt = startedAt
        self.nextID = items.count
    }

    public var current: SessionItem? { position < items.count ? items[position] : nil }
    public var isFinished: Bool { current == nil }
    public var isEmpty: Bool { items.isEmpty }
    /// True while the mistakes of the first round are repeated.
    public var isInMistakesRound: Bool { position >= wordCount && !isFinished }
    public var fractionDone: Double { items.isEmpty ? 1 : Double(position) / Double(items.count) }

    /// Whether the current answer is the first one for its word, i.e. counts.
    public var currentIsFirstAttempt: Bool {
        guard let item = current else { return false }
        return firstAttempts[item.wordID] == nil
    }

    public var correctFirstTry: Int { firstAttempts.values.filter { $0 }.count }
    public var answeredFirstTry: Int { firstAttempts.count }
    public var mistakes: [String] {
        items.prefix(wordCount).map(\.wordID).filter { firstAttempts[$0] == false }
    }
    public var score: Double { wordCount == 0 ? 0 : Double(correctFirstTry) / Double(wordCount) }

    public mutating func record(correct: Bool) {
        guard let item = current else { return }
        if firstAttempts[item.wordID] == nil {
            firstAttempts[item.wordID] = correct
        }
        let count = attempts[item.wordID, default: 0] + 1
        attempts[item.wordID] = count
        if !correct && count < Self.maxAttempts {
            items.append(SessionItem(id: nextID, wordID: item.wordID,
                                     kind: ExercisePicker.retryKind(after: item.kind)))
            nextID += 1
        }
        position += 1
    }

    public func result(at date: Date) -> TestResult {
        TestResult(date: date, scope: scope, direction: direction, answerMode: answerMode,
                   total: wordCount, correctFirstTry: correctFirstTry,
                   seconds: date.timeIntervalSince(startedAt), mistakes: mistakes)
    }

    /// Words a test with `scope` would ask.
    public static func wordIDs<G: RandomNumberGenerator>(
        for scope: TestScope, progress: LearnerProgress, words: WordIndex, now: Date,
        scheduler: FSRSScheduler, calendar: Calendar = .current, using generator: inout G
    ) -> [String] {
        let learned = progress.cards.keys.filter { words[$0] != nil }
        switch scope {
        case .all:
            return Array(learned)
        case .weakest(let count):
            return learned
                .sorted {
                    scheduler.retrievability(of: progress.cards[$0]!, at: now)
                        < scheduler.retrievability(of: progress.cards[$1]!, at: now)
                }
                .prefix(count).map { $0 }
        case .random(let count):
            return Array(learned.shuffled(using: &generator).prefix(count))
        case .recent(let days):
            let today = DayKey(now, calendar: calendar)
            return progress.wordsIntroduced(from: today.adding(days: -(days - 1), calendar: calendar), to: today)
                .filter { words[$0] != nil }
        case .words(let ids):
            return ids.filter { progress.cards[$0] != nil && words[$0] != nil }
        }
    }

    public static func make<G: RandomNumberGenerator>(
        scope: TestScope, direction: TestDirection, answerMode: TestAnswerMode,
        progress: LearnerProgress, words: WordIndex, now: Date, scheduler: FSRSScheduler,
        calendar: Calendar = .current, using generator: inout G
    ) -> VocabularyTest {
        let ids = wordIDs(for: scope, progress: progress, words: words, now: now, scheduler: scheduler,
                          calendar: calendar, using: &generator)
            .shuffled(using: &generator)
        let items = ids.enumerated().map { index, id -> SessionItem in
            let toTarget: Bool
            switch direction {
            case .toTarget: toTarget = true
            case .toNative: toTarget = false
            case .mixed: toTarget = Bool.random(using: &generator)
            }
            let kind: ExerciseKind
            switch (answerMode, toTarget) {
            case (.choice, true): kind = .chooseTarget
            case (.choice, false): kind = .chooseNative
            case (.typing, true): kind = .typeTarget
            case (.typing, false): kind = .typeNative
            }
            return SessionItem(id: index, wordID: id, kind: kind)
        }
        return VocabularyTest(scope: scope, direction: direction, answerMode: answerMode,
                              items: items, startedAt: now)
    }
}

extension TestResult {
    /// Short verdict for a score.
    public static func grade(for score: Double) -> String {
        switch score {
        case 0.9...: return "Ausgezeichnet"
        case 0.75..<0.9: return "Sehr gut"
        case 0.6..<0.75: return "Gut"
        case 0.4..<0.6: return "Weiter üben"
        default: return "Dranbleiben"
        }
    }
}
