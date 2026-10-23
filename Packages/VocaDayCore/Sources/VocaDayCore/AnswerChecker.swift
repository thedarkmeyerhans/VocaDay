import Foundation

/// Locale-independent text helpers that respect Turkish casing (I/ı, İ/i).
public enum TurkishText {
    public static func lowercased(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for char in text {
            switch char {
            case "I": result.append("ı")
            case "İ": result.append("i")
            default: result.append(contentsOf: String(char).lowercased())
            }
        }
        return result
    }

    /// Removes Turkish and German diacritics: "öğretmen" → "ogretmen".
    public static func foldingDiacritics(_ text: String) -> String {
        let map: [Character: Character] = [
            "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
            "â": "a", "î": "i", "û": "u", "ä": "a", "ß": "s",
        ]
        return String(text.map { map[$0] ?? $0 })
    }

    /// Lowercases, drops punctuation and collapses whitespace.
    public static func normalized(_ text: String) -> String {
        let lower = lowercased(text)
        let kept = lower.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(kept).split(separator: " ").joined(separator: " ")
    }
}

public enum AnswerVerdict: Equatable, Sendable {
    /// Exactly right.
    case correct
    /// Right apart from missing diacritics (e.g. "ogretmen").
    case missingDiacritics(expected: String)
    /// A small typo.
    case typo(expected: String)
    case wrong(expected: String)

    public var isAccepted: Bool {
        if case .wrong = self { return false }
        return true
    }

    /// The rating fed into the scheduler for a typed answer.
    public var rating: Rating {
        switch self {
        case .correct: return .good
        case .missingDiacritics, .typo: return .hard
        case .wrong: return .again
        }
    }
}

public enum AnswerChecker {
    public static func check(_ input: String, accepted: [String]) -> AnswerVerdict {
        let answer = TurkishText.normalized(input)
        let candidates = accepted.map { (original: $0, normalized: TurkishText.normalized($0)) }
        guard let primary = candidates.first else { return .wrong(expected: "") }

        if candidates.contains(where: { $0.normalized == answer }) {
            return .correct
        }
        guard !answer.isEmpty else { return .wrong(expected: primary.original) }

        let foldedAnswer = TurkishText.foldingDiacritics(answer)
        if let match = candidates.first(where: { TurkishText.foldingDiacritics($0.normalized) == foldedAnswer }) {
            return .missingDiacritics(expected: match.original)
        }
        for candidate in candidates {
            let folded = TurkishText.foldingDiacritics(candidate.normalized)
            let allowed = folded.count >= 8 ? 2 : (folded.count >= 4 ? 1 : 0)
            if allowed > 0, levenshtein(foldedAnswer, folded) <= allowed {
                return .typo(expected: candidate.original)
            }
        }
        return .wrong(expected: primary.original)
    }

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
