import Foundation

/// Grammatical person with German and Turkish pronoun.
public enum Person: Int, CaseIterable, Codable, Sendable, Identifiable {
    case ben, sen, o, biz, siz, onlar

    public var id: Int { rawValue }

    public var turkish: String {
        switch self {
        case .ben: return "ben"
        case .sen: return "sen"
        case .o: return "o"
        case .biz: return "biz"
        case .siz: return "siz"
        case .onlar: return "onlar"
        }
    }

    public var german: String {
        switch self {
        case .ben: return "ich"
        case .sen: return "du"
        case .o: return "er/sie/es"
        case .biz: return "wir"
        case .siz: return "ihr"
        case .onlar: return "sie"
        }
    }
}

public enum Tense: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Şimdiki zaman: geliyorum – ich komme (gerade).
    case present
    /// Görülen geçmiş zaman: geldim – ich kam / bin gekommen.
    case past
    /// Gelecek zaman: geleceğim – ich werde kommen.
    case future
    /// Geniş zaman: gelirim – ich komme (allgemein, gewohnheitsmäßig).
    case aorist

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .present: return "Präsens"
        case .past: return "Vergangenheit"
        case .future: return "Zukunft"
        case .aorist: return "Breite Zeit"
        }
    }

    public var turkishName: String {
        switch self {
        case .present: return "Şimdiki zaman (-iyor)"
        case .past: return "Geçmiş zaman (-di)"
        case .future: return "Gelecek zaman (-ecek)"
        case .aorist: return "Geniş zaman (-ir / -er)"
        }
    }

    /// Short German cue shown in exercises.
    public var cue: String {
        switch self {
        case .present: return "jetzt"
        case .past: return "gestern"
        case .future: return "morgen"
        case .aorist: return "immer / allgemein"
        }
    }
}

/// Why a verb deviates from the regular patterns.
public enum Irregularity: String, Codable, CaseIterable, Sendable {
    /// One of the 13 verbs with -ir instead of -er/-ar in the aorist.
    case aorist
    /// Stem-final t becomes d before a vowel: git → gidiyorum.
    case softening
    /// e becomes i before -yor/-yecek: ye → yiyorum, de → diyorum.
    case vowelChange

    public var title: String {
        switch self {
        case .aorist: return "Breite Zeit unregelmäßig"
        case .softening: return "t wird zu d"
        case .vowelChange: return "e wird zu i"
        }
    }
}

/// Vowel harmony and sound rules of Turkish.
public enum TurkishSounds {
    static let backVowels: Set<Character> = ["a", "ı", "o", "u", "â", "û"]
    static let frontVowels: Set<Character> = ["e", "i", "ö", "ü", "î"]
    static let roundedVowels: Set<Character> = ["o", "u", "ö", "ü", "û"]
    static let voiceless: Set<Character> = ["ç", "f", "h", "k", "p", "s", "ş", "t"]

    public static func isVowel(_ c: Character) -> Bool { backVowels.contains(c) || frontVowels.contains(c) }

    public static func lastVowel(_ text: String) -> Character? { text.last(where: isVowel) }

    /// Two-way harmony: "a" after back vowels, "e" after front vowels.
    public static func a(after text: String) -> String {
        guard let v = lastVowel(text) else { return "e" }
        return backVowels.contains(v) ? "a" : "e"
    }

    /// Four-way harmony: ı, i, u or ü.
    public static func i(after text: String) -> String {
        guard let v = lastVowel(text) else { return "i" }
        let back = backVowels.contains(v)
        let round = roundedVowels.contains(v)
        switch (back, round) {
        case (true, false): return "ı"
        case (true, true): return "u"
        case (false, false): return "i"
        case (false, true): return "ü"
        }
    }

    static func syllables(_ text: String) -> Int { text.filter(isVowel).count }
}

/// A Turkish verb (possibly a phrase like "yardım etmek") that can be conjugated.
public struct TurkishVerb: Hashable, Sendable {
    /// Words before the conjugated verb, e.g. "yardım " in "yardım etmek".
    public let prefix: String
    /// The conjugated word in the dictionary form, e.g. "etmek".
    public let infinitive: String
    /// The stem without -mak/-mek, e.g. "et".
    public let stem: String

    /// Verbs of the 13 with -ir in the aorist (al-ır, gel-ir, …).
    public static let aoristExceptions: Set<String> = [
        "al", "bil", "bul", "dur", "gel", "gör", "kal", "ol", "öl", "san", "ver", "var", "vur",
    ]
    /// Stems whose final t softens to d before a vowel.
    static let softeningStems: Set<String> = [
        "git", "et", "tat", "güt", "dit", "kastet", "hisset", "kaybet", "emret", "affet", "bahset",
        "keşfet", "reddet", "seyret", "sabret", "kaydet", "hallet", "zannet", "hapset", "şükret", "terket",
    ]
    /// Dictionary entries that are not conjugated by person (possessive or impersonal phrases).
    public static let notConjugatable: Set<String> = [
        "-ebilmek", "-abilmek", "zorunda olmak", "ihtiyacı olmak", "adı olmak", "anlamına gelmek",
        "hoşuna gitmek", "mal olmak", "eksik olmak", "ait olmak", "tadı olmak", "yağmur yağmak", "kar yağmak",
        "kanamak", "yetmek", "acımak", "elinde tutmak", "yanına almak", "lezzetli olmak",
        "aklına gelmek", "başına gelmek", "ihtiyaç duymak", "gerekmek",
    ]

    public init?(_ phrase: String) {
        let text = TurkishText.lowercased(phrase.trimmingCharacters(in: .whitespaces))
        guard !text.isEmpty, !Self.notConjugatable.contains(text),
              text.hasSuffix("mak") || text.hasSuffix("mek") else { return nil }
        let words = text.split(separator: " ").map(String.init)
        guard let last = words.last, last.count > 3, last.allSatisfy(\.isLetter) else { return nil }
        prefix = words.dropLast().map { $0 + " " }.joined()
        infinitive = last
        stem = String(last.dropLast(3))
        guard TurkishSounds.lastVowel(stem) != nil else { return nil }
    }

    public var dictionaryForm: String { prefix + infinitive }
    /// "-mak" or "-mek".
    public var ending: String { String(infinitive.suffix(3)) }

    var softens: Bool { Self.softeningStems.contains(stem) }
    var narrowsE: Bool { stem == "de" || stem == "ye" }
    var aoristIrregular: Bool { Self.aoristExceptions.contains(stem) }

    public var irregularities: [Irregularity] {
        var result: [Irregularity] = []
        if aoristIrregular { result.append(.aorist) }
        if softens { result.append(.softening) }
        if narrowsE { result.append(.vowelChange) }
        return result
    }

    public var isIrregular: Bool { !irregularities.isEmpty }

    /// Explanation with this verb's forms, e.g. "gelir statt geler".
    public func explanation(of irregularity: Irregularity) -> String {
        switch irregularity {
        case .aorist:
            let regular = stem + TurkishSounds.a(after: stem) + "r"
            return "Breite Zeit: \(prefix)\(conjugate(.aorist, .o)) statt \(prefix)\(regular) – eines der 13 Verben mit -ir."
        case .softening:
            return "Vor einem Vokal wird t zu d: \(prefix)\(conjugate(.present, .ben)), aber \(prefix)\(conjugate(.past, .ben))."
        case .vowelChange:
            return "Vor -yor und -yecek wird e zu i: \(prefix)\(conjugate(.present, .ben)), \(prefix)\(conjugate(.future, .ben))."
        }
    }

    // MARK: Conjugation

    public func conjugate(_ tense: Tense, _ person: Person) -> String {
        prefix + word(tense, person)
    }

    /// The suffix chain for teaching, e.g. "gel + iyor + um".
    public func breakdown(_ tense: Tense, _ person: Person) -> String {
        let full = word(tense, person)
        let base = stemBefore(tense)
        let rest = String(full.dropFirst(min(base.count, full.count)))
        return "\(base) + \(rest)"
    }

    private func stemBefore(_ tense: Tense) -> String {
        switch tense {
        case .past: return stem
        case .present, .future:
            if narrowsE { return String(stem.dropLast()) }
            if softens { return soft(stem) }
            if tense == .present, let last = stem.last, last == "a" || last == "e" { return String(stem.dropLast()) }
            return stem
        case .aorist: return softens ? soft(stem) : stem
        }
    }

    private func soft(_ s: String) -> String {
        guard s.last == "t" else { return s }
        return String(s.dropLast()) + "d"
    }

    private func word(_ tense: Tense, _ person: Person) -> String {
        switch tense {
        case .present: return presentForm(person)
        case .past: return pastForm(person)
        case .future: return futureForm(person)
        case .aorist: return aoristForm(person)
        }
    }

    private func presentForm(_ person: Person) -> String {
        var base: String
        if narrowsE {
            base = String(stem.dropLast()) + "i"
        } else {
            base = softens ? soft(stem) : stem
            if let last = base.last, TurkishSounds.isVowel(last) {
                if last == "a" || last == "e" {
                    base.removeLast()
                    base += TurkishSounds.i(after: base)
                }
            } else {
                base += TurkishSounds.i(after: base)
            }
        }
        let endings = ["um", "sun", "", "uz", "sunuz", "lar"]
        return base + "yor" + endings[person.rawValue]
    }

    private func pastForm(_ person: Person) -> String {
        let consonant = stem.last.map { TurkishSounds.voiceless.contains($0) } == true ? "t" : "d"
        let v = TurkishSounds.i(after: stem)
        let a = TurkishSounds.a(after: v)
        let base = stem + consonant + v
        switch person {
        case .ben: return base + "m"
        case .sen: return base + "n"
        case .o: return base
        case .biz: return base + "k"
        case .siz: return base + "n" + v + "z"
        case .onlar: return base + "l" + a + "r"
        }
    }

    private func futureForm(_ person: Person) -> String {
        var base = narrowsE ? String(stem.dropLast()) + "i" : (softens ? soft(stem) : stem)
        let back = TurkishSounds.a(after: base) == "a"
        if let last = base.last, TurkishSounds.isVowel(last) { base += "y" }
        let suffixes = back
            ? ["acağım", "acaksın", "acak", "acağız", "acaksınız", "acaklar"]
            : ["eceğim", "eceksin", "ecek", "eceğiz", "eceksiniz", "ecekler"]
        return base + suffixes[person.rawValue]
    }

    private func aoristForm(_ person: Person) -> String {
        var base: String
        if let last = stem.last, TurkishSounds.isVowel(last) {
            base = stem + "r"
        } else {
            let s = softens ? soft(stem) : stem
            let rootSyllables = softens && stem.hasSuffix("et") ? 1 : TurkishSounds.syllables(stem)
            if aoristIrregular || rootSyllables > 1 {
                base = s + TurkishSounds.i(after: s) + "r"
            } else {
                base = s + TurkishSounds.a(after: s) + "r"
            }
        }
        let i = TurkishSounds.i(after: base)
        let a = TurkishSounds.a(after: base)
        switch person {
        case .ben: return base + i + "m"
        case .sen: return base + "s" + i + "n"
        case .o: return base
        case .biz: return base + i + "z"
        case .siz: return base + "s" + i + "n" + i + "z"
        case .onlar: return base + "l" + a + "r"
        }
    }
}

extension Word {
    /// The verb behind this entry if it can be conjugated.
    public var turkishVerb: TurkishVerb? {
        partOfSpeech == .verb ? TurkishVerb(translation) : nil
    }

    /// True if the gap of the example sentence is the dictionary form itself,
    /// so it can be practised before endings are learned.
    public var clozeIsBaseForm: Bool {
        let answer = TurkishText.normalized(cloze.answer)
        return acceptedTranslations.contains { TurkishText.normalized($0) == answer }
    }
}
