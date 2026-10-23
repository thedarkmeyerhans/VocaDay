import Foundation

/// How new words are chosen. Only `standard` exists so far; further modes
/// (e.g. by topic) plug in here.
public enum SelectionMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        }
    }

    public var explanation: String {
        switch self {
        case .standard:
            return "Jeden Tag ein zufälliges Wort aus den häufigsten Wörtern – reihum von A bis Z, danach beginnt es wieder bei A."
        }
    }
}

/// The alphabet the standard mode cycles through.
public struct Alphabet: Sendable {
    public let letters: [String]
    private let folding: [Character: String]

    public init(letters: [String], folding: [Character: String] = [:]) {
        self.letters = letters
        self.folding = folding
    }

    /// German A–Z; words starting with an umlaut count towards the base letter.
    public static let german = Alphabet(
        letters: (UInt8(ascii: "A")...UInt8(ascii: "Z")).map { String(UnicodeScalar($0)) },
        folding: ["Ä": "A", "Ö": "O", "Ü": "U"]
    )

    /// Turkish alphabet (29 letters, no Q/W/X).
    public static let turkish = Alphabet(
        letters: ["A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H", "I", "İ", "J", "K", "L",
                  "M", "N", "O", "Ö", "P", "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"]
    )

    /// Alphabet used to rotate through words of the given native language.
    public static func forLanguage(_ language: Language) -> Alphabet {
        switch language {
        case .german: return .german
        case .turkish: return .turkish
        }
    }

    /// The rotation letter a word belongs to, or nil if it starts with
    /// something outside the alphabet.
    public func letter(for word: String) -> String? {
        guard let first = word.first else { return nil }
        let upper = Character(String(first).uppercased())
        let letter = folding[upper] ?? String(upper)
        return letters.contains(letter) ? letter : nil
    }
}

/// Standard mode: picks a random word among the most frequent remaining words
/// of the current letter, then moves on to the next letter. Letters without
/// remaining words are skipped. After Z it starts again at A.
public struct StandardSelector: Sendable {
    public var alphabet: Alphabet
    /// How many of the most frequent remaining words of a letter take part in
    /// the random draw.
    public var candidatesPerLetter: Int

    public init(alphabet: Alphabet = .german, candidatesPerLetter: Int = 8) {
        self.alphabet = alphabet
        self.candidatesPerLetter = max(1, candidatesPerLetter)
    }

    /// Picks up to `count` words.
    /// - Parameters:
    ///   - words: the word bank, any order.
    ///   - excluded: ids that were already planned or learned.
    ///   - cursor: index into the alphabet of the next letter; advanced in place.
    public func pick<G: RandomNumberGenerator>(
        count: Int,
        from words: [Word],
        excluding excluded: Set<String>,
        cursor: inout Int,
        using generator: inout G
    ) -> [Word] {
        let letterCount = alphabet.letters.count
        guard count > 0, letterCount > 0 else { return [] }

        var buckets: [String: [Word]] = [:]
        for word in words where !excluded.contains(word.id) {
            guard let letter = alphabet.letter(for: word.native) else { continue }
            buckets[letter, default: []].append(word)
        }
        for key in buckets.keys {
            buckets[key]?.sort { $0.rank < $1.rank }
        }

        cursor = ((cursor % letterCount) + letterCount) % letterCount
        var picked: [Word] = []
        while picked.count < count {
            var found = false
            for _ in 0..<letterCount {
                let letter = alphabet.letters[cursor]
                cursor = (cursor + 1) % letterCount
                guard var bucket = buckets[letter], !bucket.isEmpty else { continue }
                let window = min(candidatesPerLetter, bucket.count)
                let choice = Int.random(in: 0..<window, using: &generator)
                picked.append(bucket.remove(at: choice))
                buckets[letter] = bucket
                found = true
                break
            }
            if !found { break }
        }
        return picked
    }
}

/// Deterministic generator (SplitMix64) for reproducible plans and tests.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
