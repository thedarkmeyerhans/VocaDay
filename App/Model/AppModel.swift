import Foundation
import SwiftUI
import VocaDayCore

/// A learning session presented full screen.
struct ActiveSession: Identifiable {
    let id = UUID()
    let title: String
    let session: LearningSession
}

/// A vocabulary test presented full screen.
struct ActiveTest: Identifiable {
    let id = UUID()
    let test: VocabularyTest
}

struct WeekDay: Identifiable {
    var id: DayKey { day }
    let day: DayKey
    let date: Date
    let active: Bool
    let isToday: Bool
}

enum WordStatus: String {
    case upcoming = "Geplant"
    case learning = "Lernend"
    case review = "Wiederholen"
    case mature = "Gefestigt"
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var progress: LearnerProgress
    let words: WordIndex
    let notifications = NotificationScheduler()

    private let store: ProgressStore
    private let calendar = Calendar.current

    init(store: ProgressStore = .live) {
        self.store = store
        self.words = WordIndex(WordBankLoader.load(.germanTurkish))
        self.progress = store.load() ?? LearnerProgress()
        ensurePlans()
    }

    // MARK: Derived state

    var settings: LearnerSettings { progress.settings }
    var scheduler: FSRSScheduler { FSRSScheduler(desiredRetention: settings.desiredRetention) }
    var today: DayKey { DayKey(Date(), calendar: calendar) }
    private var planner: DailyPlanner { DailyPlanner(bank: words.bank, calendar: calendar) }

    /// The words assigned to today, including words from missed days.
    var todaysWords: [Word] {
        let missed = progress.pendingNewWords(upTo: today.adding(days: -1, calendar: calendar))
        let todays = progress.plans[today]?.wordIDs ?? []
        return (missed + todays).compactMap { words[$0] }
    }

    var pendingNewWords: [Word] {
        progress.pendingNewWords(upTo: today).compactMap { words[$0] }
    }

    var dueCount: Int {
        progress.dueWordIDs(at: Date()).filter { words[$0] != nil }.count
    }

    var hasWorkToday: Bool { !pendingNewWords.isEmpty || dueCount > 0 }

    var streak: Int { progress.streak(today: today, calendar: calendar) }

    var learnedCount: Int { progress.cards.count }

    var matureCount: Int { progress.cards.values.filter(\.isMature).count }

    var reviewsToday: Int { progress.stats[today]?.reviews ?? 0 }

    /// The letter of the A–Z rotation the next planned word comes from.
    var nextLetter: String {
        let alphabet = Alphabet.forLanguage(settings.pair.native)
        if let word = todaysWords.first(where: { !progress.isIntroduced($0.id) }) ?? todaysWords.first,
           let letter = alphabet.letter(for: word.native) {
            return letter
        }
        return alphabet.letters[progress.letterCursor % alphabet.letters.count]
    }

    func card(for word: Word) -> CardState? { progress.cards[word.id] }

    func status(of word: Word) -> WordStatus {
        guard let card = progress.cards[word.id] else { return .upcoming }
        if card.isMature { return .mature }
        if card.phase != .review { return .learning }
        return .review
    }

    /// Words that were introduced, most recent first.
    var introducedWords: [Word] {
        progress.cards
            .sorted { $0.value.lastReview > $1.value.lastReview }
            .compactMap { words[$0.key] }
    }

    /// Upcoming planned words (from tomorrow on).
    var upcomingWords: [Word] {
        progress.plans.keys.filter { $0 > today }.sorted()
            .flatMap { progress.plans[$0]?.wordIDs ?? [] }
            .compactMap { words[$0] }
    }

    // MARK: Sessions

    var practiceStyle: PracticeStyle { settings.mixSentenceExercises ? .mixed : .words }

    func makeDailySession() -> ActiveSession {
        var generator = SystemRandomNumberGenerator()
        let session = SessionBuilder.daily(progress: progress, words: words, now: Date(),
                                           style: practiceStyle, calendar: calendar, using: &generator)
        return ActiveSession(title: "Heute lernen", session: session)
    }

    /// Sentence trainer: due words in sentences, or free practice if nothing is due.
    func makeSentenceSession() -> ActiveSession {
        var generator = SystemRandomNumberGenerator()
        var session = SessionBuilder.daily(progress: progress, words: words, now: Date(), style: .sentences,
                                           includeNewWords: false, calendar: calendar, using: &generator)
        if session.isEmpty {
            session = SessionBuilder.practice(progress: progress, words: words, now: Date(), style: .sentences,
                                              scheduler: scheduler, using: &generator)
        }
        return ActiveSession(title: "Satztrainer", session: session)
    }

    func makeFreePracticeSession() -> ActiveSession {
        var generator = SystemRandomNumberGenerator()
        let session = SessionBuilder.practice(progress: progress, words: words, now: Date(), style: practiceStyle,
                                              scheduler: scheduler, using: &generator)
        return ActiveSession(title: "Freies Üben", session: session)
    }

    func record(wordID: String, rating: Rating) {
        progress.record(wordID: wordID, rating: rating, at: Date(), scheduler: scheduler, calendar: calendar)
        save()
    }

    /// Called when a session ends, so the evening reminder can be dropped.
    func sessionFinished(studyTime: TimeInterval) {
        progress.addStudyTime(studyTime, at: Date(), calendar: calendar)
        save()
        rescheduleNotifications()
    }

    // MARK: Vocabulary test

    func testWordCount(for scope: TestScope) -> Int {
        var generator = SystemRandomNumberGenerator()
        return VocabularyTest.wordIDs(for: scope, progress: progress, words: words, now: Date(),
                                      scheduler: scheduler, calendar: calendar, using: &generator).count
    }

    func makeTest(scope: TestScope, direction: TestDirection, answerMode: TestAnswerMode) -> ActiveTest {
        var generator = SystemRandomNumberGenerator()
        let test = VocabularyTest.make(scope: scope, direction: direction, answerMode: answerMode,
                                       progress: progress, words: words, now: Date(), scheduler: scheduler,
                                       calendar: calendar, using: &generator)
        return ActiveTest(test: test)
    }

    /// Stores the result of a finished test.
    func finishTest(_ test: VocabularyTest) {
        let result = test.result(at: Date())
        progress.tests.append(result)
        progress.addStudyTime(result.seconds, at: Date(), calendar: calendar)
        save()
        rescheduleNotifications()
    }

    /// Time spent in a test that was cancelled.
    func addStudyTime(_ seconds: TimeInterval) {
        progress.addStudyTime(seconds, at: Date(), calendar: calendar)
        save()
    }

    var lastTest: TestResult? { progress.tests.last }

    // MARK: Statistics

    var statistics: LearningStatistics {
        LearningStatistics.make(progress: progress, words: words, now: Date(), calendar: calendar)
    }

    /// Weekdays (Monday first) of the current week with their activity.
    var currentWeek: [WeekDay] {
        let weekday = calendar.component(.weekday, from: Date())
        let monday = today.adding(days: -((weekday + 5) % 7), calendar: calendar)
        return (0..<7).map { offset in
            let day = monday.adding(days: offset, calendar: calendar)
            return WeekDay(day: day, date: day.date(calendar: calendar) ?? Date(),
                           active: (progress.stats[day]?.reviews ?? 0) > 0, isToday: day == today)
        }
    }

    /// Progress of today's work: answered vs. still open.
    var todayProgress: Double {
        let done = Double(reviewsToday)
        let open = Double(pendingNewWords.count * 3 + dueCount)
        if done + open == 0 { return 0 }
        return done / (done + open)
    }

    // MARK: Plans & settings

    func didBecomeActive() {
        ensurePlans()
        rescheduleNotifications()
    }

    func ensurePlans() {
        var generator = SystemRandomNumberGenerator()
        planner.ensurePlans(&progress, today: today, using: &generator)
        save()
    }

    @discardableResult
    func addExtraWord() -> Word? {
        var generator = SystemRandomNumberGenerator()
        let added = planner.addExtraWords(1, to: &progress, today: today, using: &generator)
        save()
        rescheduleNotifications()
        return added.first
    }

    func updateSettings(_ change: (inout LearnerSettings) -> Void) {
        let before = progress.settings
        change(&progress.settings)
        progress.settings.newWordsPerDay = min(max(progress.settings.newWordsPerDay,
                                                   LearnerSettings.newWordsRange.lowerBound),
                                               LearnerSettings.newWordsRange.upperBound)
        if before.newWordsPerDay != progress.settings.newWordsPerDay || before.mode != progress.settings.mode {
            var generator = SystemRandomNumberGenerator()
            planner.replanFuture(&progress, today: today, using: &generator)
            topUpToday(previous: before.newWordsPerDay)
        }
        save()
        rescheduleNotifications()
    }

    /// When the number of words per day is raised, today gets the extra words too.
    private func topUpToday(previous: Int) {
        let missing = progress.settings.newWordsPerDay - (progress.plans[today]?.wordIDs.count ?? 0)
        guard progress.settings.newWordsPerDay > previous, missing > 0 else { return }
        var generator = SystemRandomNumberGenerator()
        planner.addExtraWords(missing, to: &progress, today: today, using: &generator)
    }

    func completeOnboarding(with settings: LearnerSettings) {
        var generator = SystemRandomNumberGenerator()
        progress = LearnerProgress(settings: settings)
        progress.settings.onboardingCompleted = true
        planner.ensurePlans(&progress, today: today, using: &generator)
        save()
        rescheduleNotifications()
    }

    func resetProgress() {
        let settings = progress.settings
        progress = LearnerProgress(settings: settings)
        ensurePlans()
        rescheduleNotifications()
    }

    // MARK: Notifications

    func rescheduleNotifications() {
        let entries = NotificationPlanner.entries(for: progress, words: words, now: Date(), calendar: calendar,
                                                  hasOpenWorkToday: hasWorkToday)
        let scheduler = notifications
        Task { await scheduler.replace(with: entries) }
    }

    private func save() {
        store.save(progress)
    }
}

enum WordBankLoader {
    static func load(_ pair: LanguagePair) -> WordBank {
        guard let url = Bundle.main.url(forResource: pair.resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? WordBank.decode(from: data) else {
            fatalError("Word bank \(pair.resourceName).json is missing from the app bundle")
        }
        return bank
    }
}

struct ProgressStore {
    let url: URL

    static var live: ProgressStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ProgressStore(url: directory.appendingPathComponent("progress.json"))
    }

    func load() -> LearnerProgress? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? LearnerProgress.decode(from: data)
    }

    func save(_ progress: LearnerProgress) {
        do {
            try progress.encoded().write(to: url, options: [.atomic])
        } catch {
            print("Saving progress failed: \(error)")
        }
    }
}
