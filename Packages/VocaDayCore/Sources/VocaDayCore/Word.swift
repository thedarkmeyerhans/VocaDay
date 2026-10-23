import Foundation

public enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
    case noun, verb, adjective, adverb, pronoun, preposition, conjunction
    case numeral, interjection, phrase, other

    public var displayName: String {
        switch self {
        case .noun: return "Nomen"
        case .verb: return "Verb"
        case .adjective: return "Adjektiv"
        case .adverb: return "Adverb"
        case .pronoun: return "Pronomen"
        case .preposition: return "Präposition"
        case .conjunction: return "Konjunktion"
        case .numeral: return "Zahlwort"
        case .interjection: return "Ausruf"
        case .phrase: return "Wendung"
        case .other: return "Sonstiges"
        }
    }
}

/// One entry of a word bank: a word in the native language, its translation
/// and an example sentence in both languages.
public struct Word: Codable, Hashable, Identifiable, Sendable {
    /// Stable identifier, used as key for the learner's progress.
    public let id: String
    /// Frequency rank of the native word (1 = most frequent).
    public let rank: Int
    /// Native word, e.g. "Haus".
    public let native: String
    /// Article for nouns ("der", "die", "das").
    public let article: String?
    public let partOfSpeech: PartOfSpeech
    /// Main translation in the target language, e.g. "ev".
    public let translation: String
    /// Further accepted translations.
    public let alternatives: [String]
    /// Example sentence in the native language.
    public let exampleNative: String
    /// Example sentence in the target language. The word being learned is
    /// marked with square brackets: "Bu [ev] çok büyük."
    public let exampleTarget: String
    /// Optional grammar or usage hint.
    public let note: String?
    /// Occurrences per million words in the frequency corpus.
    public let frequency: Double?

    public init(
        id: String, rank: Int, native: String, article: String? = nil,
        partOfSpeech: PartOfSpeech, translation: String, alternatives: [String] = [],
        exampleNative: String, exampleTarget: String, note: String? = nil, frequency: Double? = nil
    ) {
        self.id = id
        self.rank = rank
        self.native = native
        self.article = article
        self.partOfSpeech = partOfSpeech
        self.translation = translation
        self.alternatives = alternatives
        self.exampleNative = exampleNative
        self.exampleTarget = exampleTarget
        self.note = note
        self.frequency = frequency
    }

    /// "das Haus" for nouns, otherwise just the word.
    public var nativeWithArticle: String {
        guard let article, !article.isEmpty else { return native }
        return "\(article) \(native)"
    }

    /// All translations that count as correct.
    public var acceptedTranslations: [String] { [translation] + alternatives }

    public var cloze: ClozeSentence { ClozeSentence(exampleTarget) }
}

/// A sentence with one marked gap, parsed from "Bu [ev] çok büyük.".
public struct ClozeSentence: Hashable, Sendable {
    public let before: String
    public let answer: String
    public let after: String

    public init(_ raw: String) {
        if let open = raw.firstIndex(of: "["),
           let close = raw[open...].firstIndex(of: "]") {
            before = String(raw[..<open])
            answer = String(raw[raw.index(after: open)..<close])
            after = String(raw[raw.index(after: close)...])
        } else {
            before = raw
            answer = ""
            after = ""
        }
    }

    public var hasGap: Bool { !answer.isEmpty }

    /// The sentence without markers.
    public var plain: String { before + answer + after }

    /// The sentence with the gap replaced by a placeholder.
    public func masked(with placeholder: String = "_____") -> String {
        before + placeholder + after
    }

    /// The sentence split into words for the sentence builder exercise.
    /// Punctuation stays attached to its word.
    public var tokens: [String] {
        plain.split(whereSeparator: { $0 == " " }).map(String.init)
    }
}

/// All words of one language pair.
public struct WordBank: Codable, Sendable {
    public let pair: LanguagePair
    public let version: Int
    public let attribution: String
    public let words: [Word]

    public init(pair: LanguagePair, version: Int = 1, attribution: String = "", words: [Word]) {
        self.pair = pair
        self.version = version
        self.attribution = attribution
        self.words = words.sorted { $0.rank < $1.rank }
    }

    public static func decode(from data: Data) throws -> WordBank {
        let decoded = try JSONDecoder().decode(WordBank.self, from: data)
        return WordBank(pair: decoded.pair, version: decoded.version,
                        attribution: decoded.attribution, words: decoded.words)
    }
}

/// Fast id → word lookup. `WordBank` stays a plain value; the app keeps one
/// of these next to it.
public struct WordIndex: Sendable {
    public let bank: WordBank
    private let byID: [String: Word]

    public init(_ bank: WordBank) {
        self.bank = bank
        self.byID = Dictionary(bank.words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public subscript(id: String) -> Word? { byID[id] }
}
