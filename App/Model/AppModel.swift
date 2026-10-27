import Foundation
import SwiftUI
import VocaDayCore

/// A learning session presented full screen.
struct ActiveSession: Identifiable {
    let id = UUID()
    let title: String
    let session: LearningSession
}

/// A mastery practice (grammar stage or consolidation) presented full screen.
struct ActiveMastery: Identifiable {
    enum Purpose {
        case grammar(stageID: String)
        case consolidation
        case widgetWord(wordID: String)
    }

    let id = UUID()
    let title: String
    let purpose: Purpose
    let session: MasterySession
    /// Shown as an introduction first when the word is new.
    var introWordID: String?
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

enum WordStatus: String, CaseIterable, Identifiable {
    case learning = "Lernend"
    case review = "Wiederholen"
    case mature = "Gefestigt"
    case upcoming = "Geplant"
    case notYet = "Noch nicht dran"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .learning: return "gerade neu oder vergessen"
        case .review: return "sitzt für einige Tage"
        case .mature: return "sitzt drei Wochen und länger"
        case .upcoming: return "kommt in den nächsten Tagen"
        case .notYet: return "noch nicht an der Reihe"
        }
    }

    /// The groups shown in the vocabulary overview.
    static let overview: [WordStatus] = [.learning, .review, .mature, .upcoming]
}

/// A stack of words for the flashcard browser.
struct CardDeck: Identifiable {
    let id = UUID()
    let title: String
    let words: [Word]
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var progress: LearnerProgress
    /// Practice opened from the widget or another deep link.
    @Published var deepLinkMastery: ActiveMastery?
    let words: WordIndex
    let grammar: GrammarCurriculum
    let notifications = NotificationScheduler()

    private let store: ProgressStore
    private let calendar = Calendar.current

    init(store: ProgressStore = .live) {
        self.store = store
        self.words = WordIndex(WordBankLoader.load(.germanTurkish))
        self.grammar = WordBankLoader.loadGrammar(.germanTurkish)
        self.progress = store.load() ?? LearnerProgress()
        ensurePlans()
        startCompanions()
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
        guard let card = progress.cards[word.id] else {
            return progress.plans.values.contains { $0.wordIDs.contains(word.id) } ? .upcoming : .notYet
        }
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

    // MARK: Vocabulary

    /// Learned words grouped by memory state (most recently reviewed first) and
    /// the words planned from today on.
    var wordsByStatus: [WordStatus: [Word]] {
        var groups: [WordStatus: [Word]] = [:]
        for word in introducedWords {
            groups[status(of: word), default: []].append(word)
        }
        groups[.upcoming] = progress.plans.keys.filter { $0 >= today }.sorted()
            .flatMap { progress.plans[$0]?.wordIDs ?? [] }
            .filter { progress.cards[$0] == nil }
            .compactMap { words[$0] }
        return groups
    }

    func words(forLetter letter: String) -> [Word] {
        let alphabet = Alphabet.forLanguage(settings.pair.native)
        return words.bank.words.filter { alphabet.letter(for: $0.native) == letter }
    }

    func plannedDay(for word: Word) -> DayKey? { progress.plannedDays[word.id] }

    /// "Jetzt lernen": puts a word the learner picked on today's plan.
    @discardableResult
    func learnNow(_ word: Word) -> Bool {
        var generator = SystemRandomNumberGenerator()
        let added = planner.addSpecificWord(word.id, to: &progress, today: today, using: &generator)
        if added {
            save()
            rescheduleNotifications()
        }
        return added
    }

    /// "Heute", "Gestern" or the date.
    func dayLabel(_ day: DayKey) -> String {
        if day == today { return "Heute" }
        if day == today.adding(days: -1, calendar: calendar) { return "Gestern" }
        if day == today.adding(days: 1, calendar: calendar) { return "Morgen" }
        guard let date = day.date(calendar: calendar) else { return day.rawValue }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE")))
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

    // MARK: Widget, places & deep links

    private func startCompanions() {
        GatePass.mirror(enabled: settings.gateEnabled)
        PlaceMonitor.shared.onEnter = { [weak self] id in self?.placeEntered(id) }
        let places = settings.places
        if !places.isEmpty {
            Task { await PlaceMonitor.shared.sync(places: places) }
        }
    }

    func handle(url: URL) {
        guard url.scheme == "vocaday" else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch url.host {
        case "widget":
            if let id = query.first(where: { $0.name == "word" })?.value {
                deepLinkMastery = makeWidgetPractice(wordID: id)
            }
        case "quiz":
            let target = query.first(where: { $0.name == "return" })?.value.flatMap(URL.init(string:))
            GateRouter.shared.present(returnURL: target)
        default:
            break
        }
    }

    /// Practice of the widget word: introduction if new, then the configured
    /// number of correct answers in a row.
    func makeWidgetPractice(wordID: String) -> ActiveMastery? {
        guard let word = words[wordID] else { return nil }
        let isNew = progress.cards[wordID] == nil
        if isNew { learnNow(word) }
        var generator = SystemRandomNumberGenerator()
        let items = GrammarBuilder.vocabularyItems(wordIDs: [wordID], words: words, using: &generator)
        let session = MasterySession(items: items, target: max(1, settings.widgetRepetitions), using: &generator)
        return ActiveMastery(title: "Wort des Tages", purpose: .widgetWord(wordID: wordID), session: session,
                             introWordID: isNew ? wordID : nil)
    }

    func placeEntered(_ id: UUID) {
        guard let place = settings.places.first(where: { $0.id == id }) else { return }
        WidgetPlanner.placeEntered(progress: &progress, now: Date(), calendar: calendar)
        save()
        if let word = WidgetPlanner.nextWord(progress: progress, words: words, today: today) {
            notifications.notifyNow(title: "📍 \(place.name): neues Wort",
                                    body: "\(word.translation) – \(word.nativeWithArticle)",
                                    url: "vocaday://widget?word=\(word.id)")
        }
    }

    /// Saves the current position as a place. Returns false without location.
    func addPlace(named name: String) async -> Bool {
        guard let location = await PlaceMonitor.shared.currentLocation() else { return false }
        let place = LearningPlace(name: name.isEmpty ? "Mein Ort" : name,
                                  latitude: location.coordinate.latitude,
                                  longitude: location.coordinate.longitude)
        updateSettings { $0.places.append(place) }
        PlaceMonitor.shared.requestPermission()
        let places = settings.places
        await PlaceMonitor.shared.sync(places: places)
        return true
    }

    func removePlace(_ place: LearningPlace) {
        updateSettings { $0.places.removeAll { $0.id == place.id } }
        let places = settings.places
        Task { await PlaceMonitor.shared.sync(places: places) }
    }

    // MARK: Zwangsmodus

    /// The next word of the gate quiz (rotates during the day until known).
    func nextGateWord() -> (word: Word, isNew: Bool)? {
        var generator = SystemRandomNumberGenerator()
        let result = GateQuiz.nextWord(progress: &progress, words: words, now: Date(), scheduler: scheduler,
                                       planner: planner, calendar: calendar, using: &generator)
        if let result, result.isNew { learnNow(result.word) }
        save()
        return result
    }

    func gateItem(for word: Word) -> MasteryItem? {
        var generator = SystemRandomNumberGenerator()
        return GrammarBuilder.vocabularyItems(wordIDs: [word.id], words: words, using: &generator).first
    }

    /// Records a gate answer. A correct answer opens the pass for the configured minutes.
    func answerGate(wordID: String, correct: Bool) {
        GateQuiz.record(wordID: wordID, correct: correct, progress: &progress)
        progress.record(wordID: wordID, rating: correct ? .good : .again, at: Date(), scheduler: scheduler,
                        calendar: calendar)
        if correct { GatePass.grant(minutes: settings.gatePassMinutes) }
        save()
    }

    var gateKnownToday: Int { progress.gate.day == today ? progress.gate.known.count : 0 }

    // MARK: Grammar & consolidation

    func state(of stage: GrammarStage) -> StageState {
        GrammarBuilder.state(of: stage, in: grammar.stages, progress: progress, words: words)
    }

    var completedStages: Int { grammar.stages.filter { progress.grammar[$0.id]?.isCompleted == true }.count }

    var learnedVerbCount: Int { GrammarBuilder.learnedVerbs(progress: progress, words: words).count }

    func makeGrammarPractice(_ stage: GrammarStage) -> ActiveMastery {
        var generator = SystemRandomNumberGenerator()
        let items = GrammarBuilder.items(for: stage, progress: progress, words: words, using: &generator)
        return ActiveMastery(title: stage.title, purpose: .grammar(stageID: stage.id),
                             session: MasterySession(items: items, target: 2, using: &generator))
    }

    /// "Festigen": the weakest learned words until each is answered twice in a row.
    func makeConsolidation(count: Int = 10) -> ActiveMastery {
        var generator = SystemRandomNumberGenerator()
        let now = Date()
        let ids = progress.cards.filter { words[$0.key] != nil }
            .sorted { scheduler.retrievability(of: $0.value, at: now) < scheduler.retrievability(of: $1.value, at: now) }
            .prefix(count).map(\.key)
        let items = GrammarBuilder.vocabularyItems(wordIDs: Array(ids), words: words, using: &generator)
        return ActiveMastery(title: "Festigen", purpose: .consolidation,
                             session: MasterySession(items: items, target: 2, using: &generator))
    }

    /// Records one answer of a mastery practice. Only the first answer to a
    /// vocabulary or conjugation item updates the word's memory state.
    func recordMastery(item: MasteryItem, correct: Bool, firstAttempt: Bool) {
        guard firstAttempt, let wordID = item.wordID else { return }
        record(wordID: wordID, rating: correct ? .good : .again)
    }

    func finishMastery(_ active: ActiveMastery, session: MasterySession, studyTime: TimeInterval) {
        if session.isFinished, case .grammar(let stageID) = active.purpose {
            progress.recordGrammarSession(stageID: stageID, firstTryScore: session.firstTryScore, at: Date())
        }
        if session.isFinished, case .widgetWord = active.purpose {
            WidgetPlanner.completed(progress: &progress, now: Date(), calendar: calendar)
        }
        progress.addStudyTime(studyTime, at: Date(), calendar: calendar)
        save()
        rescheduleNotifications()
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
        GatePass.mirror(enabled: settings.gateEnabled)
        WidgetBridge.update(model: self)
    }
}

enum WordBankLoader {
    static func loadGrammar(_ pair: LanguagePair) -> GrammarCurriculum {
        guard let url = Bundle.main.url(forResource: "grammar_\(pair.native.rawValue)_\(pair.target.rawValue)",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let curriculum = try? GrammarCurriculum.decode(from: data) else {
            return GrammarCurriculum(stages: [])
        }
        return curriculum
    }

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
