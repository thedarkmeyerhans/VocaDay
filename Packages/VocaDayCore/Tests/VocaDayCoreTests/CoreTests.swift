import Foundation
import XCTest
@testable import VocaDayCore

final class WordSelectionTests: XCTestCase {
    func testLettersFoldUmlauts() {
        XCTAssertEqual(Alphabet.german.letter(for: "öffnen"), "O")
        XCTAssertEqual(Alphabet.german.letter(for: "Haus"), "H")
        XCTAssertNil(Alphabet.german.letter(for: "123"))
    }

    func testStandardSelectorWalksThroughTheAlphabet() throws {
        let bank = try Fixtures.bank()
        var generator = SeededGenerator(seed: 1)
        var cursor = 0
        let picked = StandardSelector().pick(count: 6, from: bank.words, excluding: [],
                                             cursor: &cursor, using: &generator)
        // A (arbeiten/auto), B (buch), H (haus), O (öffnen), Z (zeit), then A again.
        XCTAssertEqual(picked.map { Alphabet.german.letter(for: $0.native)! }, ["A", "B", "H", "O", "Z", "A"])
        XCTAssertEqual(Set(picked.map(\.id)).count, 6)
    }

    func testSelectorStopsWhenWordsRunOut() throws {
        let bank = try Fixtures.bank()
        var generator = SeededGenerator(seed: 2)
        var cursor = 0
        let picked = StandardSelector().pick(count: 20, from: bank.words, excluding: ["haus"],
                                             cursor: &cursor, using: &generator)
        XCTAssertEqual(picked.count, 5)
        XCTAssertFalse(picked.contains { $0.id == "haus" })
    }

    func testCandidatesWindowPrefersFrequentWords() {
        let words = (1...30).map { i in
            Word(id: "a\(i)", rank: i, native: "A\(i)", partOfSpeech: .noun, translation: "x\(i)",
                 exampleNative: "", exampleTarget: "")
        }
        var generator = SeededGenerator(seed: 3)
        for _ in 0..<50 {
            var cursor = 0
            let pick = StandardSelector(candidatesPerLetter: 5).pick(count: 1, from: words, excluding: [],
                                                                     cursor: &cursor, using: &generator)
            XCTAssertLessThanOrEqual(pick[0].rank, 5)
        }
    }
}

final class PlannerTests: XCTestCase {
    func testPlansAreStableAndDoNotRepeatWords() throws {
        let bank = try Fixtures.bank()
        let planner = DailyPlanner(bank: bank, calendar: Fixtures.utcCalendar)
        var progress = LearnerProgress()
        var generator = SeededGenerator(seed: 4)
        let today = DayKey(rawValue: "2026-10-23")

        planner.ensurePlans(&progress, today: today, daysAhead: 3, using: &generator)
        XCTAssertEqual(progress.plans.count, 4)
        let firstPlan = progress.plans[today]
        planner.ensurePlans(&progress, today: today, daysAhead: 3, using: &generator)
        XCTAssertEqual(progress.plans[today], firstPlan)

        let all = progress.plans.values.flatMap(\.wordIDs)
        XCTAssertEqual(all.count, Set(all).count)
    }

    func testChangingWordsPerDayReplansFutureFromSameLetter() throws {
        let bank = try Fixtures.bank()
        let planner = DailyPlanner(bank: bank, calendar: Fixtures.utcCalendar)
        var progress = LearnerProgress()
        var generator = SeededGenerator(seed: 5)
        let today = DayKey(rawValue: "2026-10-23")
        planner.ensurePlans(&progress, today: today, daysAhead: 2, using: &generator)
        let todayPlan = progress.plans[today]
        let cursorForTomorrow = progress.plans[today.adding(days: 1, calendar: Fixtures.utcCalendar)]!.cursorBefore

        progress.settings.newWordsPerDay = 2
        planner.replanFuture(&progress, today: today, daysAhead: 2, using: &generator)

        XCTAssertEqual(progress.plans[today], todayPlan)
        let tomorrow = progress.plans[today.adding(days: 1, calendar: Fixtures.utcCalendar)]!
        XCTAssertEqual(tomorrow.cursorBefore, cursorForTomorrow)
        XCTAssertEqual(tomorrow.wordIDs.count, 2)
    }

    func testExtraWordIsAddedToToday() throws {
        let bank = try Fixtures.bank()
        let planner = DailyPlanner(bank: bank, calendar: Fixtures.utcCalendar)
        var progress = LearnerProgress()
        var generator = SeededGenerator(seed: 6)
        let today = DayKey(rawValue: "2026-10-23")
        planner.ensurePlans(&progress, today: today, daysAhead: 1, using: &generator)
        let added = planner.addExtraWords(1, to: &progress, today: today, using: &generator)
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(progress.plans[today]?.wordIDs.count, 2)
        XCTAssertEqual(progress.pendingNewWords(upTo: today).count, 2)
        let all = progress.plans.values.flatMap(\.wordIDs)
        XCTAssertEqual(all.count, Set(all).count)
    }

    func testMissedDaysRollOver() {
        var progress = LearnerProgress()
        progress.plans[DayKey(rawValue: "2026-10-21")] = DayPlan(wordIDs: ["a"], cursorBefore: 0)
        progress.plans[DayKey(rawValue: "2026-10-22")] = DayPlan(wordIDs: ["b"], cursorBefore: 1)
        progress.plans[DayKey(rawValue: "2026-10-24")] = DayPlan(wordIDs: ["c"], cursorBefore: 2)
        XCTAssertEqual(progress.pendingNewWords(upTo: DayKey(rawValue: "2026-10-23")), ["a", "b"])
    }
}

final class SchedulerTests: XCTestCase {
    let scheduler = FSRSScheduler()
    let start = Fixtures.date("2026-10-23T08:00:00Z")

    func testFirstGoodReviewSchedulesInDays() {
        let card = scheduler.schedule(nil, rating: .good, at: start)
        XCTAssertEqual(card.phase, .review)
        XCTAssertEqual(card.stability, 3.173, accuracy: 0.001)
        XCTAssertEqual(card.due.timeIntervalSince(start), 3 * 86_400, accuracy: 1)
    }

    func testAgainComesBackWithinTheSession() {
        let card = scheduler.schedule(nil, rating: .again, at: start)
        XCTAssertEqual(card.phase, .learning)
        XCTAssertEqual(card.due.timeIntervalSince(start), FSRSScheduler.againDelay, accuracy: 1)
    }

    func testIntervalsGrowWithSuccessfulReviews() {
        var card = scheduler.schedule(nil, rating: .good, at: start)
        var previousInterval = card.due.timeIntervalSince(start)
        var now = start
        for _ in 0..<5 {
            now = card.due
            card = scheduler.schedule(card, rating: .good, at: now)
            let interval = card.due.timeIntervalSince(now)
            XCTAssertGreaterThan(interval, previousInterval)
            previousInterval = interval
        }
    }

    func testForgettingLowersStabilityAndCountsLapse() {
        var card = scheduler.schedule(nil, rating: .good, at: start)
        card = scheduler.schedule(card, rating: .good, at: card.due)
        let before = card.stability
        let forgotten = scheduler.schedule(card, rating: .again, at: card.due)
        XCTAssertLessThan(forgotten.stability, before)
        XCTAssertEqual(forgotten.lapses, 1)
        XCTAssertEqual(forgotten.phase, .relearning)
    }

    func testRetrievabilityAtIntervalMatchesDesiredRetention() {
        let r = scheduler.retrievability(elapsedDays: 10, stability: 10)
        XCTAssertEqual(r, 0.9, accuracy: 0.0001)
        let strict = FSRSScheduler(desiredRetention: 0.95)
        XCTAssertLessThan(strict.interval(for: 10), scheduler.interval(for: 10))
    }

    func testDifficultyStaysInRange() {
        var card = scheduler.schedule(nil, rating: .again, at: start)
        for _ in 0..<20 { card = scheduler.schedule(card, rating: .again, at: card.due) }
        XCTAssertLessThanOrEqual(card.difficulty, 10)
        for _ in 0..<20 { card = scheduler.schedule(card, rating: .easy, at: card.due) }
        XCTAssertGreaterThanOrEqual(card.difficulty, 1)
    }
}

final class AnswerCheckerTests: XCTestCase {
    func testExactAndCaseInsensitive() {
        XCTAssertEqual(AnswerChecker.check("Ev", accepted: ["ev"]), .correct)
        XCTAssertEqual(AnswerChecker.check("  ev! ", accepted: ["ev"]), .correct)
        XCTAssertEqual(AnswerChecker.check("otomobil", accepted: ["araba", "otomobil"]), .correct)
    }

    func testTurkishDottedI() {
        XCTAssertEqual(TurkishText.lowercased("IŞIK"), "ışık")
        XCTAssertEqual(TurkishText.lowercased("İSTANBUL"), "istanbul")
        XCTAssertEqual(AnswerChecker.check("IŞIK", accepted: ["ışık"]), .correct)
    }

    func testMissingDiacriticsIsAcceptedAsHard() {
        let verdict = AnswerChecker.check("ogretmen", accepted: ["öğretmen"])
        XCTAssertEqual(verdict, .missingDiacritics(expected: "öğretmen"))
        XCTAssertEqual(verdict.rating, .hard)
    }

    func testTypo() {
        XCTAssertEqual(AnswerChecker.check("arabe", accepted: ["araba"]), .typo(expected: "araba"))
        XCTAssertEqual(AnswerChecker.check("ew", accepted: ["ev"]), .wrong(expected: "ev"))
        XCTAssertEqual(AnswerChecker.check("", accepted: ["ev"]), .wrong(expected: "ev"))
    }
}

final class ClozeTests: XCTestCase {
    func testParsing() {
        let cloze = ClozeSentence("Bir [kitap] okuyorum.")
        XCTAssertEqual(cloze.answer, "kitap")
        XCTAssertEqual(cloze.plain, "Bir kitap okuyorum.")
        XCTAssertEqual(cloze.masked(), "Bir _____ okuyorum.")
        XCTAssertEqual(cloze.tokens, ["Bir", "kitap", "okuyorum."])
    }

    func testNoMarker() {
        let cloze = ClozeSentence("Merhaba.")
        XCTAssertFalse(cloze.hasGap)
        XCTAssertEqual(cloze.plain, "Merhaba.")
    }
}

final class SessionTests: XCTestCase {
    func testDailySessionIntroducesAndChecksNewWords() throws {
        let bank = try Fixtures.bank()
        var progress = LearnerProgress()
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        progress.plans[DayKey(now, calendar: Fixtures.utcCalendar)] = DayPlan(wordIDs: ["haus"], cursorBefore: 0)
        var generator = SeededGenerator(seed: 7)
        let session = SessionBuilder.daily(progress: progress, words: WordIndex(bank), now: now, style: .words,
                                           calendar: Fixtures.utcCalendar, using: &generator)
        XCTAssertEqual(session.items.map(\.kind), [.introduction, .chooseNative, .chooseTarget])
    }

    func testWrongAnswerIsRepeatedLater() throws {
        let bank = try Fixtures.bank()
        var progress = LearnerProgress()
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        progress.plans[DayKey(now, calendar: Fixtures.utcCalendar)] = DayPlan(wordIDs: ["haus"], cursorBefore: 0)
        var generator = SeededGenerator(seed: 8)
        var session = SessionBuilder.daily(progress: progress, words: WordIndex(bank), now: now, style: .words,
                                           calendar: Fixtures.utcCalendar, using: &generator)
        session.advance(after: nil)
        session.advance(after: .again)
        XCTAssertEqual(session.items.count, 4)
        var guardCount = 0
        while !session.isFinished && guardCount < 20 {
            session.advance(after: .again)
            guardCount += 1
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertLessThanOrEqual(session.items.count, 3 + LearningSession.maxRetriesPerWord)
    }

    func testDueReviewsAreIncluded() throws {
        let bank = try Fixtures.bank()
        var progress = LearnerProgress()
        let scheduler = FSRSScheduler()
        let past = Fixtures.date("2026-10-10T08:00:00Z")
        progress.record(wordID: "auto", rating: .good, at: past, scheduler: scheduler, calendar: Fixtures.utcCalendar)
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        XCTAssertEqual(progress.dueWordIDs(at: now), ["auto"])
        var generator = SeededGenerator(seed: 9)
        let session = SessionBuilder.daily(progress: progress, words: WordIndex(bank), now: now, style: .mixed,
                                           calendar: Fixtures.utcCalendar, using: &generator)
        XCTAssertEqual(session.items.map(\.wordID), ["auto"])
    }
}

final class ProgressCodingTests: XCTestCase {
    func testRoundTrip() throws {
        var progress = LearnerProgress()
        progress.plans[DayKey(rawValue: "2026-10-23")] = DayPlan(wordIDs: ["haus"], cursorBefore: 3)
        progress.record(wordID: "haus", rating: .good, at: Fixtures.date("2026-10-23T08:00:00Z"),
                        scheduler: FSRSScheduler(), calendar: Fixtures.utcCalendar)
        let data = try progress.encoded()
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"2026-10-23\""))
        let decoded = try LearnerProgress.decode(from: data)
        XCTAssertEqual(decoded.plans, progress.plans)
        XCTAssertEqual(decoded.cards["haus"]?.phase, .review)
        XCTAssertEqual(decoded.stats[DayKey(rawValue: "2026-10-23")]?.newWords, 1)
    }

    func testStreak() {
        var progress = LearnerProgress()
        let calendar = Fixtures.utcCalendar
        for day in ["2026-10-20", "2026-10-21", "2026-10-22"] {
            progress.stats[DayKey(rawValue: day)] = DayStats(reviews: 3)
        }
        XCTAssertEqual(progress.streak(today: DayKey(rawValue: "2026-10-23"), calendar: calendar), 3)
        progress.stats[DayKey(rawValue: "2026-10-23")] = DayStats(reviews: 1)
        XCTAssertEqual(progress.streak(today: DayKey(rawValue: "2026-10-23"), calendar: calendar), 4)
        XCTAssertEqual(progress.streak(today: DayKey(rawValue: "2026-10-26"), calendar: calendar), 0)
    }
}

final class ReminderTests: XCTestCase {
    func testWordOfTheDayNamesThePlannedWord() throws {
        let bank = try Fixtures.bank()
        let calendar = Fixtures.utcCalendar
        var progress = LearnerProgress(settings: LearnerSettings(notificationHour: 8, eveningReminderHour: 19,
                                                                 onboardingCompleted: true))
        let now = Fixtures.date("2026-10-23T09:00:00Z")
        progress.plans[DayKey(rawValue: "2026-10-24")] = DayPlan(wordIDs: ["haus"], cursorBefore: 0)

        let entries = NotificationPlanner.entries(for: progress, words: WordIndex(bank), now: now,
                                                  calendar: calendar, hasOpenWorkToday: true)
        // Today 08:00 is already over, today's evening reminder is still ahead.
        XCTAssertEqual(entries.first?.id, "vocaday.evening.2026-10-23")
        let tomorrow = try XCTUnwrap(entries.first { $0.id == "vocaday.word.2026-10-24" })
        XCTAssertEqual(tomorrow.title, "Dein Wort des Tages")
        XCTAssertEqual(tomorrow.body, "ev – das Haus")
        XCTAssertEqual(tomorrow.date.hour, 8)
        XCTAssertEqual(entries.count, 2 * NotificationPlanner.daysAhead - 1)
    }

    func testNoEveningReminderWhenTodayIsDone() throws {
        let bank = try Fixtures.bank()
        let progress = LearnerProgress(settings: LearnerSettings(onboardingCompleted: true))
        let entries = NotificationPlanner.entries(for: progress, words: WordIndex(bank),
                                                  now: Fixtures.date("2026-10-23T09:00:00Z"),
                                                  calendar: Fixtures.utcCalendar, hasOpenWorkToday: false)
        XCTAssertFalse(entries.contains { $0.id == "vocaday.evening.2026-10-23" })
    }

    func testSeveralWords() {
        let words = ["a", "b", "c", "d"].enumerated().map { index, id in
            Word(id: id, rank: index, native: id.uppercased(), partOfSpeech: .noun, translation: "t\(id)",
                 exampleNative: "", exampleTarget: "")
        }
        let (title, body) = NotificationPlanner.wordOfTheDayText(words)
        XCTAssertEqual(title, "Deine 4 neuen Wörter")
        XCTAssertEqual(body, "ta (A), tb (B), tc (C) und 1 weitere")
    }
}
