import Foundation

/// A language the app can use as native or target language.
public enum Language: String, Codable, CaseIterable, Sendable, Identifiable {
    case german = "de"
    case turkish = "tr"

    public var id: String { rawValue }

    /// Name shown in the (German) user interface.
    public var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .turkish: return "Türkisch"
        }
    }

    public var flag: String {
        switch self {
        case .german: return "🇩🇪"
        case .turkish: return "🇹🇷"
        }
    }

    /// BCP-47 code used for speech synthesis.
    public var speechCode: String {
        switch self {
        case .german: return "de-DE"
        case .turkish: return "tr-TR"
        }
    }

    /// Characters a German keyboard is missing for this language.
    public var specialCharacters: [String] {
        switch self {
        case .german: return ["ä", "ö", "ü", "ß"]
        case .turkish: return ["ç", "ğ", "ı", "İ", "ö", "ş", "ü"]
        }
    }
}

/// A native/target language combination for which a word bank exists.
public struct LanguagePair: Codable, Hashable, Sendable {
    public var native: Language
    public var target: Language

    public init(native: Language, target: Language) {
        self.native = native
        self.target = target
    }

    public static let germanTurkish = LanguagePair(native: .german, target: .turkish)

    /// Pairs that ship with a word bank.
    public static let available: [LanguagePair] = [.germanTurkish]

    /// Resource name of the bundled word bank, e.g. `words_de_tr`.
    public var resourceName: String { "words_\(native.rawValue)_\(target.rawValue)" }
}
