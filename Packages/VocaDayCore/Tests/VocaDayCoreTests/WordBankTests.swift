import Foundation
import XCTest
@testable import VocaDayCore

/// Checks the word bank the app actually ships.
final class ShippedWordBankTests: XCTestCase {
    static var bankURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Resources/words_de_tr.json")
    }

    func loadBank() throws -> WordBank {
        guard FileManager.default.fileExists(atPath: Self.bankURL.path) else {
            throw XCTSkip("word bank not found at \(Self.bankURL.path)")
        }
        return try WordBank.decode(from: Data(contentsOf: Self.bankURL))
    }

    func testEveryWordIsUsable() throws {
        let bank = try loadBank()
        XCTAssertGreaterThan(bank.words.count, 1000)
        XCTAssertEqual(Set(bank.words.map(\.id)).count, bank.words.count)
        for word in bank.words {
            XCTAssertTrue(word.cloze.hasGap, "\(word.id) has no gap")
            XCTAssertFalse(word.translation.isEmpty, "\(word.id) has no translation")
            XCTAssertNotNil(Alphabet.german.letter(for: word.native), "\(word.id) has no rotation letter")
        }
    }

    func testRotationCoversTheAlphabet() throws {
        let bank = try loadBank()
        let planner = DailyPlanner(bank: bank, calendar: Fixtures.utcCalendar)
        var progress = LearnerProgress()
        var generator = SeededGenerator(seed: 42)
        planner.ensurePlans(&progress, today: DayKey(rawValue: "2026-01-01"), daysAhead: 23, using: &generator)
        let letters = (0..<24).compactMap { offset -> String? in
            let day = DayKey(rawValue: "2026-01-01").adding(days: offset, calendar: Fixtures.utcCalendar)
            guard let id = progress.plans[day]?.wordIDs.first else { return nil }
            return bank.words.first { $0.id == id }.flatMap { Alphabet.german.letter(for: $0.native) }
        }
        // X and Y have no frequent words and are skipped.
        XCTAssertEqual(letters.joined(), "ABCDEFGHIJKLMNOPQRSTUVWZ")
    }

    func testDistractorsAreNeverSynonyms() throws {
        let bank = try loadBank()
        var generator = SeededGenerator(seed: 1)
        let sprechen = try XCTUnwrap(bank.words.first { $0.id == "sprechen" })
        for _ in 0..<30 {
            let options = DistractorPicker.distractors(for: sprechen, in: bank.words, answer: \.native,
                                                       using: &generator)
            XCTAssertEqual(options.count, 3)
            XCTAssertFalse(options.contains { $0.translation == "konuşmak" })
        }
    }
}
