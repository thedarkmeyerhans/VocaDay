import Foundation

public enum ExerciseKind: String, Codable, CaseIterable, Sendable {
    /// First encounter: word, translation, example, pronunciation.
    case introduction
    /// Target word shown, pick the native meaning (recognition).
    case chooseNative
    /// Native word shown, pick the target word.
    case chooseTarget
    /// Native word shown, type the target word (free recall).
    case typeTarget
    /// Flip card, the learner rates themself.
    case flashcard
    /// Target sentence with a gap, pick the missing word.
    case clozeChoice
    /// Target sentence with a gap, type the missing word.
    case clozeType
    /// Put the shuffled words of the target sentence into the right order.
    case sentenceBuilder

    public var isSentenceExercise: Bool {
        switch self {
        case .clozeChoice, .clozeType, .sentenceBuilder: return true
        default: return false
        }
    }

    public var isGraded: Bool { self != .introduction }

    /// The best rating this exercise can produce. Picking from options is
    /// easier than recalling, so it never counts as "easy".
    public var ratingCap: Rating {
        switch self {
        case .chooseNative, .chooseTarget, .clozeChoice: return .good
        default: return .easy
        }
    }

    public var title: String {
        switch self {
        case .introduction: return "Neues Wort"
        case .chooseNative: return "Was bedeutet das?"
        case .chooseTarget: return "Wie heißt das auf Türkisch?"
        case .typeTarget: return "Schreib das Wort"
        case .flashcard: return "Erinnerst du dich?"
        case .clozeChoice: return "Welches Wort fehlt?"
        case .clozeType: return "Ergänze den Satz"
        case .sentenceBuilder: return "Bilde den Satz"
        }
    }
}

/// Which kinds of practice a session contains.
public enum PracticeStyle: String, Codable, CaseIterable, Sendable {
    /// Single words (recognition → recall).
    case words
    /// Words in sentences (cloze, sentence building).
    case sentences
    /// Both, interleaved.
    case mixed
}

/// Chooses an exercise that is hard enough to be useful but not frustrating
/// ("desirable difficulty"): recognition for fresh words, free recall and
/// sentence production for well-known ones.
public enum ExercisePicker {
    public static func kind<G: RandomNumberGenerator>(
        for card: CardState?, style: PracticeStyle, word: Word, using generator: inout G
    ) -> ExerciseKind {
        let canUseSentence = word.cloze.hasGap
        let wantsSentence: Bool
        switch style {
        case .words: wantsSentence = false
        case .sentences: wantsSentence = canUseSentence
        case .mixed: wantsSentence = canUseSentence && Bool.random(using: &generator)
        }

        guard let card else {
            return wantsSentence ? .clozeChoice : .chooseNative
        }
        let stability = card.stability
        if wantsSentence {
            if stability < 3 || card.phase != .review { return .clozeChoice }
            if stability < 14 { return .clozeType }
            return Bool.random(using: &generator) ? .sentenceBuilder : .clozeType
        }
        if card.phase != .review { return .chooseTarget }
        if stability < 4 { return Bool.random(using: &generator) ? .chooseTarget : .flashcard }
        return Bool.random(using: &generator) ? .typeTarget : .flashcard
    }

    /// A slightly easier exercise for a word that was just answered wrongly.
    public static func retryKind(after kind: ExerciseKind) -> ExerciseKind {
        switch kind {
        case .typeTarget, .flashcard: return .chooseTarget
        case .clozeType, .sentenceBuilder: return .clozeChoice
        case .chooseTarget: return .chooseNative
        default: return kind
        }
    }
}

/// Builds answer options for multiple-choice exercises.
public enum DistractorPicker {
    /// Up to `count` other words, preferring the same part of speech and
    /// words close in frequency, with distinct answers. Words that mean the
    /// same (e.g. "reden" and "sprechen", both "konuşmak") are left out so
    /// that only one option is correct.
    public static func distractors<G: RandomNumberGenerator>(
        for word: Word, in words: [Word], count: Int = 3,
        answer: (Word) -> String, using generator: inout G
    ) -> [Word] {
        let correct = TurkishText.normalized(answer(word))
        let meanings = Set(word.acceptedTranslations.map(TurkishText.normalized))
        let native = TurkishText.normalized(word.native)
        var seen: Set<String> = [correct]
        var result: [Word] = []

        func isSynonym(_ other: Word) -> Bool {
            TurkishText.normalized(other.native) == native
                || other.acceptedTranslations.contains { meanings.contains(TurkishText.normalized($0)) }
        }

        let others = words.filter { $0.id != word.id && !isSynonym($0) }
        let samePOS = others.filter { $0.partOfSpeech == word.partOfSpeech }
        let nearby = samePOS.sorted { abs($0.rank - word.rank) < abs($1.rank - word.rank) }
            .prefix(60).shuffled(using: &generator)
        let fallback = others.shuffled(using: &generator)

        for candidate in Array(nearby) + fallback {
            guard result.count < count else { break }
            let key = TurkishText.normalized(answer(candidate))
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(candidate)
        }
        return result
    }
}
