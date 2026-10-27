import Foundation
import XCTest
@testable import VocaDayCore

final class GrammarTests: XCTestCase {
    static var curriculumURL: URL {
        ShippedWordBankTests.bankURL.deletingLastPathComponent().appendingPathComponent("grammar_de_tr.json")
    }

    func loadShipped() throws -> (GrammarCurriculum, WordBank) {
        guard FileManager.default.fileExists(atPath: Self.curriculumURL.path) else { throw XCTSkip("no curriculum") }
        let curriculum = try GrammarCurriculum.decode(from: Data(contentsOf: Self.curriculumURL))
        let bank = try WordBank.decode(from: Data(contentsOf: ShippedWordBankTests.bankURL))
        return (curriculum, bank)
    }

    func testCurriculumLoadsAndStagesUnlockInOrder() throws {
        let (curriculum, bank) = try loadShipped()
        let words = WordIndex(bank)
        XCTAssertEqual(curriculum.stages.map(\.id),
                       ["pronouns", "verbEndings", "presentEndings", "present", "past", "future", "aorist"])
        var progress = LearnerProgress()
        let stages = curriculum.stages
        XCTAssertEqual(GrammarBuilder.state(of: stages[0], in: stages, progress: progress, words: words), .open)
        if case .locked = GrammarBuilder.state(of: stages[1], in: stages, progress: progress, words: words) {} else {
            XCTFail("verb endings should be locked")
        }
        progress.recordGrammarSession(stageID: "pronouns", firstTryScore: 0.8, at: Date())
        progress.recordGrammarSession(stageID: "verbEndings", firstTryScore: 0.8, at: Date())
        progress.recordGrammarSession(stageID: "presentEndings", firstTryScore: 0.8, at: Date())
        // Conjugating needs three learned verbs.
        guard case .locked(let reason) = GrammarBuilder.state(of: stages[3], in: stages, progress: progress,
                                                               words: words) else { return XCTFail() }
        XCTAssertTrue(reason.contains("0/3"))
        for id in ["gehen", "kommen", "machen"] {
            progress.record(wordID: id, rating: .good, at: Date(), scheduler: FSRSScheduler())
        }
        XCTAssertEqual(GrammarBuilder.state(of: stages[3], in: stages, progress: progress, words: words), .open)
    }

    func testEveryStageBuildsAnswerableItems() throws {
        let (curriculum, bank) = try loadShipped()
        let words = WordIndex(bank)
        var progress = LearnerProgress()
        for id in ["gehen", "kommen", "machen", "essen", "sehen"] {
            progress.record(wordID: id, rating: .good, at: Date(), scheduler: FSRSScheduler())
        }
        var generator = SeededGenerator(seed: 21)
        for stage in curriculum.stages {
            let items = GrammarBuilder.items(for: stage, progress: progress, words: words, using: &generator)
            XCTAssertFalse(items.isEmpty, stage.id)
            XCTAssertEqual(Set(items.map(\.id)).count, items.count, stage.id)
            for item in items {
                XCTAssertFalse(item.answers.isEmpty)
                if !item.choices.isEmpty {
                    XCTAssertTrue(item.choices.contains(item.answers[0]), "\(stage.id): \(item.prompt)")
                }
            }
        }
        let aorist = try XCTUnwrap(curriculum.stages.first { $0.id == "aorist" })
        let aoristItems = GrammarBuilder.items(for: aorist, progress: progress, words: words, using: &generator)
        XCTAssertTrue(aoristItems.contains { $0.prompt.hasSuffix("gelmek") || $0.prompt.hasSuffix("görmek") })
        let present = try XCTUnwrap(curriculum.stages.first { $0.id == "presentEndings" })
        let presentItems = GrammarBuilder.items(for: present, progress: progress, words: words, using: &generator)
        XCTAssertTrue(presentItems.contains { $0.answers.contains("geliyorum") && $0.detail == "ich" })
    }

    func testMasterySessionRepeatsUntilEveryItemIsMastered() {
        let items = (1...3).map { MasteryItem(id: "i\($0)", kicker: "", prompt: "p\($0)", answers: ["a"]) }
        var generator = SeededGenerator(seed: 22)
        var session = MasterySession(items: items, target: 2, using: &generator)
        XCTAssertEqual(session.currentStreak, 0)
        let firstID = session.current?.id
        session.answer(correct: false)
        var steps = 1
        while !session.isFinished && steps < 50 {
            session.answer(correct: true)
            steps += 1
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.masteredCount, 3)
        XCTAssertEqual(session.progress, 1)
        XCTAssertEqual(steps, 7) // one wrong + 2 × 3 correct
        XCTAssertEqual(session.firstTry[firstID!], false)
        XCTAssertEqual(session.firstTryScore, 2.0 / 3.0, accuracy: 0.001)
    }

    func testBaseFormRuleBlocksInflectedGaps() throws {
        let verb = Word(id: "arbeiten", rank: 3, native: "arbeiten", partOfSpeech: .verb, translation: "çalışmak",
                        exampleNative: "Ich arbeite viel.", exampleTarget: "Çok [çalışıyorum].")
        let card = CardState(stability: 20, difficulty: 5, due: Date(), lastReview: Date(), phase: .review,
                             reps: 5, lapses: 0)
        var generator = SeededGenerator(seed: 23)
        for _ in 0..<20 {
            let kind = ExercisePicker.kind(for: card, style: .sentences, word: verb, allowInflected: false,
                                           using: &generator)
            XCTAssertFalse([.clozeChoice, .clozeType].contains(kind))
        }
        let unlocked = ExercisePicker.kind(for: card, style: .sentences, word: verb, allowInflected: true,
                                           using: &generator)
        XCTAssertTrue([.clozeType, .sentenceBuilder].contains(unlocked))
    }

    func testVocabularyItemsUseDictionaryForm() throws {
        let (_, bank) = try loadShipped()
        var generator = SeededGenerator(seed: 24)
        let items = GrammarBuilder.vocabularyItems(wordIDs: ["gehen", "haus"], words: WordIndex(bank),
                                                   using: &generator)
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[0].answers.contains("gitmek"))
        XCTAssertTrue(items[0].detail?.contains("unregelmäßig") == true)
        XCTAssertEqual(items[0].choices.count, 4)
    }
}

final class CompanionTests: XCTestCase {
    func testGateRotatesUntilKnownThenAddsWords() throws {
        let bank = try Fixtures.bank()
        let words = WordIndex(bank)
        let calendar = Fixtures.utcCalendar
        let scheduler = FSRSScheduler()
        let planner = DailyPlanner(bank: bank, calendar: calendar)
        var progress = LearnerProgress(settings: LearnerSettings(onboardingCompleted: true))
        progress.settings.gateWordTarget = 2
        let now = Fixtures.date("2026-10-27T09:00:00Z")
        for id in ["haus", "auto"] {
            progress.record(wordID: id, rating: .good, at: now.addingTimeInterval(-86_400 * 3), scheduler: scheduler,
                            calendar: calendar)
        }
        var generator = SeededGenerator(seed: 31)
        var asked: [String] = []
        for _ in 0..<4 {
            let next = try XCTUnwrap(GateQuiz.nextWord(progress: &progress, words: words, now: now,
                                                       scheduler: scheduler, planner: planner, calendar: calendar,
                                                       using: &generator))
            asked.append(next.word.id)
            GateQuiz.record(wordID: next.word.id, correct: true, progress: &progress)
        }
        XCTAssertEqual(Set(asked), ["haus", "auto"])
        XCTAssertNotEqual(asked[0], asked[1]) // rotation
        XCTAssertEqual(Set(progress.gate.known), ["haus", "auto"])
        // Both known: a new word joins.
        let fresh = try XCTUnwrap(GateQuiz.nextWord(progress: &progress, words: words, now: now, scheduler: scheduler,
                                                    planner: planner, calendar: calendar, using: &generator))
        XCTAssertTrue(fresh.isNew)
        XCTAssertFalse(["haus", "auto"].contains(fresh.word.id))
    }

    func testWrongAnswerResetsGateCount() {
        var progress = LearnerProgress()
        GateQuiz.record(wordID: "haus", correct: true, progress: &progress)
        GateQuiz.record(wordID: "haus", correct: false, progress: &progress)
        XCTAssertEqual(progress.gate.correct["haus"], 0)
        XCTAssertTrue(progress.gate.known.isEmpty)
    }

    func testWidgetWaitsForTheConfiguredTimeAndHonoursDoneMode() throws {
        let bank = try Fixtures.bank()
        let words = WordIndex(bank)
        let calendar = Fixtures.utcCalendar
        var progress = LearnerProgress(settings: LearnerSettings(onboardingCompleted: true))
        progress.settings.widgetHours = [8, 18]
        progress.plans[DayKey(rawValue: "2026-10-27")] = DayPlan(wordIDs: ["haus"], cursorBefore: 0)
        let early = Fixtures.date("2026-10-27T06:00:00Z")

        var snapshot = WidgetPlanner.snapshot(progress: progress, words: words, now: early, calendar: calendar)
        XCTAssertEqual(snapshot.entry(at: early)?.kind, .waiting)
        let eight = Fixtures.date("2026-10-27T08:00:00Z")
        XCTAssertEqual(snapshot.entry(at: eight)?.kind, .word)
        XCTAssertEqual(snapshot.entry(at: eight)?.word?.translation, "ev")

        // A place reveals the word right away.
        WidgetPlanner.placeEntered(progress: &progress, now: early, calendar: calendar)
        snapshot = WidgetPlanner.snapshot(progress: progress, words: words, now: early, calendar: calendar)
        XCTAssertEqual(snapshot.entry(at: early)?.kind, .word)

        // "Done" mode: check mark until 18:00.
        progress.settings.widgetAfterCompletion = .done
        let nine = Fixtures.date("2026-10-27T09:00:00Z")
        WidgetPlanner.completed(progress: &progress, now: nine, calendar: calendar)
        XCTAssertEqual(progress.widget.doneUntil, Fixtures.date("2026-10-27T18:00:00Z"))
        snapshot = WidgetPlanner.snapshot(progress: progress, words: words, now: nine, calendar: calendar)
        XCTAssertEqual(snapshot.entry(at: nine)?.kind, .done)
        XCTAssertEqual(snapshot.entry(at: Fixtures.date("2026-10-27T18:30:00Z"))?.kind, .word)
    }

    func testOldSettingsDecodeWithDefaults() throws {
        let json = """
        {"pair":{"native":"de","target":"tr"},"mode":"standard","newWordsPerDay":2,"notificationsEnabled":true,
         "notificationHour":7,"notificationMinute":30,"eveningReminderEnabled":false,"eveningReminderHour":19,
         "desiredRetention":0.9,"mixSentenceExercises":true,"onboardingCompleted":true}
        """
        let settings = try JSONDecoder().decode(LearnerSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.newWordsPerDay, 2)
        XCTAssertEqual(settings.notificationHour, 7)
        XCTAssertEqual(settings.widgetHours, [8])
        XCTAssertEqual(settings.widgetRepetitions, 3)
        XCTAssertFalse(settings.gateEnabled)
        let roundTrip = try JSONDecoder().decode(LearnerSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(roundTrip, settings)
    }
}
