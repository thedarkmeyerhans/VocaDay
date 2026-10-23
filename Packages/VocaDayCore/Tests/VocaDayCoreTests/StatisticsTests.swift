import Foundation
import XCTest
@testable import VocaDayCore

final class VocabularyTestTests: XCTestCase {
    private func learnedProgress(_ ids: [String], at date: Date) -> LearnerProgress {
        var progress = LearnerProgress()
        for id in ids {
            progress.record(wordID: id, rating: .good, at: date, scheduler: FSRSScheduler(),
                            calendar: Fixtures.utcCalendar)
        }
        return progress
    }

    func testAllScopeAsksEveryLearnedWordOnce() throws {
        let bank = try Fixtures.bank()
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        let progress = learnedProgress(["haus", "auto", "buch"], at: now)
        var generator = SeededGenerator(seed: 1)
        let test = VocabularyTest.make(scope: .all, direction: .toTarget, answerMode: .typing,
                                       progress: progress, words: WordIndex(bank), now: now,
                                       scheduler: FSRSScheduler(), calendar: Fixtures.utcCalendar,
                                       using: &generator)
        XCTAssertEqual(test.wordCount, 3)
        XCTAssertEqual(Set(test.items.map(\.wordID)), ["haus", "auto", "buch"])
        XCTAssertTrue(test.items.allSatisfy { $0.kind == .typeTarget })
    }

    func testMistakesComeBackAndOnlyFirstAttemptCounts() throws {
        let bank = try Fixtures.bank()
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        let progress = learnedProgress(["haus", "auto"], at: now)
        var generator = SeededGenerator(seed: 2)
        var test = VocabularyTest.make(scope: .all, direction: .toNative, answerMode: .typing,
                                       progress: progress, words: WordIndex(bank), now: now,
                                       scheduler: FSRSScheduler(), calendar: Fixtures.utcCalendar,
                                       using: &generator)
        let first = try XCTUnwrap(test.current?.wordID)
        XCTAssertTrue(test.currentIsFirstAttempt)
        test.record(correct: false)
        test.record(correct: true)
        XCTAssertTrue(test.isInMistakesRound)
        XCTAssertEqual(test.current?.wordID, first)
        XCTAssertEqual(test.current?.kind, .chooseNative)
        XCTAssertFalse(test.currentIsFirstAttempt)
        test.record(correct: true)
        XCTAssertTrue(test.isFinished)
        XCTAssertEqual(test.score, 0.5)
        XCTAssertEqual(test.mistakes, [first])

        let result = test.result(at: now.addingTimeInterval(90))
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.correctFirstTry, 1)
        XCTAssertEqual(result.seconds, 90, accuracy: 0.1)
    }

    func testRetriesAreLimited() throws {
        let bank = try Fixtures.bank()
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        let progress = learnedProgress(["haus"], at: now)
        var generator = SeededGenerator(seed: 3)
        var test = VocabularyTest.make(scope: .all, direction: .toTarget, answerMode: .choice,
                                       progress: progress, words: WordIndex(bank), now: now,
                                       scheduler: FSRSScheduler(), using: &generator)
        var steps = 0
        while !test.isFinished && steps < 10 {
            test.record(correct: false)
            steps += 1
        }
        XCTAssertEqual(steps, VocabularyTest.maxAttempts)
    }

    func testWeakestAndRecentScopes() throws {
        let bank = try Fixtures.bank()
        let calendar = Fixtures.utcCalendar
        let scheduler = FSRSScheduler()
        var progress = LearnerProgress()
        let old = Fixtures.date("2026-09-01T08:00:00Z")
        let now = Fixtures.date("2026-10-23T08:00:00Z")
        progress.record(wordID: "haus", rating: .good, at: old, scheduler: scheduler, calendar: calendar)
        progress.record(wordID: "auto", rating: .easy, at: now, scheduler: scheduler, calendar: calendar)
        progress.plans[DayKey(rawValue: "2026-09-01")] = DayPlan(wordIDs: ["haus"], cursorBefore: 0)
        progress.plans[DayKey(rawValue: "2026-10-23")] = DayPlan(wordIDs: ["auto", "buch"], cursorBefore: 1)
        var generator = SeededGenerator(seed: 4)

        let weakest = VocabularyTest.wordIDs(for: .weakest(1), progress: progress, words: WordIndex(bank),
                                             now: now, scheduler: scheduler, calendar: calendar,
                                             using: &generator)
        XCTAssertEqual(weakest, ["haus"])
        let recent = VocabularyTest.wordIDs(for: .recent(days: 7), progress: progress, words: WordIndex(bank),
                                            now: now, scheduler: scheduler, calendar: calendar,
                                            using: &generator)
        XCTAssertEqual(recent, ["auto"])
        let fixed = VocabularyTest.wordIDs(for: .words(["auto", "zeit"]), progress: progress,
                                           words: WordIndex(bank), now: now, scheduler: scheduler,
                                           calendar: calendar, using: &generator)
        XCTAssertEqual(fixed, ["auto"])
    }

    func testGrades() {
        XCTAssertEqual(TestResult.grade(for: 0.95), "Ausgezeichnet")
        XCTAssertEqual(TestResult.grade(for: 0.5), "Weiter üben")
    }
}

final class StatisticsTests: XCTestCase {
    func testCountsStreaksAndRetention() throws {
        let bank = try Fixtures.bank()
        let calendar = Fixtures.utcCalendar
        let scheduler = FSRSScheduler()
        var progress = LearnerProgress()
        let day1 = Fixtures.date("2026-10-20T08:00:00Z")
        progress.record(wordID: "haus", rating: .good, at: day1, scheduler: scheduler, calendar: calendar)
        progress.record(wordID: "auto", rating: .good, at: day1, scheduler: scheduler, calendar: calendar)
        let day2 = Fixtures.date("2026-10-21T08:00:00Z")
        progress.stats[DayKey(day2, calendar: calendar)] = DayStats(reviews: 1, correct: 1)
        let day4 = Fixtures.date("2026-10-23T08:00:00Z")
        // Both words are due on day 4: one remembered, one forgotten.
        progress.record(wordID: "haus", rating: .good, at: day4, scheduler: scheduler, calendar: calendar)
        progress.record(wordID: "auto", rating: .again, at: day4, scheduler: scheduler, calendar: calendar)
        progress.addStudyTime(120, at: day4, calendar: calendar)

        let stats = LearningStatistics.make(progress: progress, words: WordIndex(bank), now: day4,
                                            calendar: calendar)
        XCTAssertEqual(stats.learned, 2)
        XCTAssertEqual(stats.stages[.learning], 1)
        XCTAssertEqual(stats.stages[.young], 1)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 2)
        XCTAssertEqual(stats.activeDays, 3)
        XCTAssertEqual(stats.totalReviews, 5)
        XCTAssertEqual(stats.totalSeconds, 120)
        XCTAssertEqual(stats.retention30, 0.5)
        XCTAssertEqual(stats.retentionSamples30, 2)
        XCTAssertEqual(stats.recentDays.count, 30)
        XCTAssertEqual(stats.recentDays.last?.day, DayKey(rawValue: "2026-10-23"))
        XCTAssertEqual(stats.heatmap.count % 7, 5)  // 2026-10-23 is a Friday
        XCTAssertEqual(stats.forecast.count, 14)
        XCTAssertEqual(stats.forecast.first?.count, 1)  // "auto" is due again today
        XCTAssertEqual(stats.letters.first { $0.letter == "H" }?.learned, 1)
    }

    func testCoverageUsesWordFrequency() {
        let words = [
            Word(id: "a", rank: 1, native: "A", partOfSpeech: .noun, translation: "x",
                 exampleNative: "", exampleTarget: "[x]", frequency: 100_000),
            Word(id: "b", rank: 2, native: "B", partOfSpeech: .noun, translation: "y",
                 exampleNative: "", exampleTarget: "[y]", frequency: 50_000),
        ]
        var progress = LearnerProgress()
        progress.record(wordID: "a", rating: .good, at: Date(), scheduler: FSRSScheduler())
        let stats = LearningStatistics.make(progress: progress, words: WordIndex(WordBank(pair: .germanTurkish, words: words)),
                                            now: Date())
        XCTAssertEqual(stats.coverage, 0.1, accuracy: 0.0001)
        XCTAssertEqual(stats.maximumCoverage, 0.15, accuracy: 0.0001)
    }

    func testOldProgressFilesStillLoad() throws {
        let json = """
        {"version":1,"letterCursor":2,"plans":{},"cards":{},
         "settings":{"pair":{"native":"de","target":"tr"},"mode":"standard","newWordsPerDay":1,
           "notificationsEnabled":true,"notificationHour":8,"notificationMinute":0,
           "eveningReminderEnabled":true,"eveningReminderHour":19,"desiredRetention":0.9,
           "mixSentenceExercises":true,"onboardingCompleted":true},
         "stats":{"2026-10-23":{"reviews":3,"correct":2,"newWords":1}}}
        """
        let progress = try LearnerProgress.decode(from: Data(json.utf8))
        XCTAssertEqual(progress.letterCursor, 2)
        XCTAssertEqual(progress.tests, [])
        XCTAssertEqual(progress.stats[DayKey(rawValue: "2026-10-23")]?.seconds, 0)
        XCTAssertEqual(progress.stats[DayKey(rawValue: "2026-10-23")]?.reviews, 3)
    }

    func testTestResultsRoundTrip() throws {
        var progress = LearnerProgress()
        progress.tests.append(TestResult(date: Fixtures.date("2026-10-23T08:00:00Z"), scope: .weakest(20),
                                         direction: .mixed, answerMode: .typing, total: 20,
                                         correctFirstTry: 17, seconds: 300, mistakes: ["haus"]))
        let decoded = try LearnerProgress.decode(from: progress.encoded())
        XCTAssertEqual(decoded.tests, progress.tests)
        XCTAssertEqual(decoded.tests.first?.score ?? 0, 0.85, accuracy: 0.0001)
    }
}
