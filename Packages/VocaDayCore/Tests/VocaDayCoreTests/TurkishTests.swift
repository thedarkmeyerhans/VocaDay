import Foundation
import XCTest
@testable import VocaDayCore

final class ConjugationTests: XCTestCase {
    struct Case: Decodable {
        let verb: String
        let tense: String
        let person: String
        let form: String
    }

    func testAllFixtureForms() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "conjugations", withExtension: "json",
                                                  subdirectory: "Fixtures"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(cases.count, 200)
        var failures: [String] = []
        for c in cases {
            let verb = try XCTUnwrap(TurkishVerb(c.verb), c.verb)
            let tense = try XCTUnwrap(Tense(rawValue: c.tense))
            let person = try XCTUnwrap(Person.allCases.first { $0.turkish == c.person })
            let form = verb.conjugate(tense, person)
            if form != c.form { failures.append("\(c.verb) \(c.tense) \(c.person): \(form) ≠ \(c.form)") }
        }
        XCTAssertEqual(failures, [])
    }

    func testIrregularities() throws {
        XCTAssertEqual(TurkishVerb("gelmek")?.irregularities, [.aorist])
        XCTAssertEqual(TurkishVerb("gitmek")?.irregularities, [.softening])
        XCTAssertEqual(TurkishVerb("yemek")?.irregularities, [.vowelChange])
        XCTAssertEqual(TurkishVerb("yapmak")?.irregularities, [])
        XCTAssertEqual(TurkishVerb("yardım etmek")?.irregularities, [.softening])
        let gel = try XCTUnwrap(TurkishVerb("gelmek"))
        XCTAssertTrue(gel.explanation(of: .aorist).contains("gelir statt geler"))
    }

    func testPhrasesThatCannotBeConjugated() {
        XCTAssertNil(TurkishVerb("ihtiyacı olmak"))
        XCTAssertNil(TurkishVerb("-ebilmek"))
        XCTAssertNil(TurkishVerb("ev"))
        XCTAssertEqual(TurkishVerb("telefon etmek")?.prefix, "telefon ")
    }

    func testBreakdownAndEnding() throws {
        let gel = try XCTUnwrap(TurkishVerb("gelmek"))
        XCTAssertEqual(gel.breakdown(.present, .ben), "gel + iyorum")
        XCTAssertEqual(gel.ending, "mek")
        XCTAssertEqual(TurkishVerb("beklemek")?.breakdown(.present, .o), "bekl + iyor")
        XCTAssertEqual(TurkishVerb("almak")?.ending, "mak")
    }

    func testEveryBankVerbConjugatesWithoutCrashing() throws {
        let url = ShippedWordBankTests.bankURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("no bank") }
        let bank = try WordBank.decode(from: Data(contentsOf: url))
        let verbs = bank.words.compactMap(\.turkishVerb)
        XCTAssertGreaterThan(verbs.count, 200)
        for verb in verbs {
            for tense in Tense.allCases {
                for person in Person.allCases {
                    XCTAssertFalse(verb.conjugate(tense, person).isEmpty)
                }
            }
        }
    }

    func testBaseFormCloze() {
        let ev = Word(id: "haus", rank: 1, native: "Haus", partOfSpeech: .noun, translation: "ev",
                      exampleNative: "", exampleTarget: "[Ev] büyük.")
        let evim = Word(id: "haus2", rank: 1, native: "Haus", partOfSpeech: .noun, translation: "ev",
                        exampleNative: "", exampleTarget: "[Evimiz] küçük.")
        XCTAssertTrue(ev.clozeIsBaseForm)
        XCTAssertFalse(evim.clozeIsBaseForm)
    }
}
