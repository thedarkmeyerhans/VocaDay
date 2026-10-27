import Foundation

// MARK: - Curriculum (decoded from grammar_<pair>.json)

public struct GrammarCurriculum: Codable, Sendable {
    public let stages: [GrammarStage]

    public init(stages: [GrammarStage]) {
        self.stages = stages
    }

    public static func decode(from data: Data) throws -> GrammarCurriculum {
        try JSONDecoder().decode(GrammarCurriculum.self, from: data)
    }
}

public struct GrammarStage: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// ich → ben …
        case pronouns
        /// -mak/-mek and the stem.
        case verbEndings
        /// Endings of one tense with fixed model verbs.
        case modelConjugation
        /// Conjugating the learner's own verbs.
        case conjugation
    }

    public struct Lesson: Codable, Hashable, Sendable {
        public struct Conjugation: Codable, Hashable, Sendable {
            public let verbs: [String]
            public let tense: Tense
        }

        public let title: String
        public let text: String
        public let header: [String]?
        public let table: [[String]]?
        public let conjugation: Conjugation?
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let subtitle: String
    public let icon: String
    public let webIcon: String
    public let tense: Tense?
    public let modelVerbs: [String]?
    /// Learned conjugatable verbs needed before the stage opens.
    public let requiresVerbs: Int
    public let lesson: [Lesson]
}

/// What the learner achieved in a stage.
public struct GrammarRecord: Codable, Hashable, Sendable {
    public var completedAt: Date?
    public var sessions: Int
    public var bestFirstTry: Double

    public init(completedAt: Date? = nil, sessions: Int = 0, bestFirstTry: Double = 0) {
        self.completedAt = completedAt
        self.sessions = sessions
        self.bestFirstTry = bestFirstTry
    }

    public var isCompleted: Bool { completedAt != nil }
}

public enum StageState: Equatable, Sendable {
    case locked(reason: String)
    case open
    case completed
}

// MARK: - Mastery practice

/// One question of a mastery practice.
public struct MasteryItem: Identifiable, Hashable, Sendable {
    public let id: String
    /// Small kicker above the prompt, e.g. "Präsens · ich".
    public let kicker: String
    /// What to translate or conjugate.
    public let prompt: String
    /// German hint below the prompt.
    public let detail: String?
    public let answers: [String]
    /// Options for the first (recognition) round; empty means typing only.
    public let choices: [String]
    /// Shown after answering, e.g. "gel + iyorum".
    public let explanation: String?
    /// Turkish text to read aloud after answering.
    public let speech: String?
    /// For vocabulary items: the word whose memory state is updated.
    public let wordID: String?
    /// Which keyboard helpers the answer needs.
    public let answerLanguage: Language

    public init(id: String, kicker: String, prompt: String, detail: String? = nil, answers: [String],
                choices: [String] = [], explanation: String? = nil, speech: String? = nil,
                wordID: String? = nil, answerLanguage: Language = .turkish) {
        self.id = id
        self.kicker = kicker
        self.prompt = prompt
        self.detail = detail
        self.answers = answers
        self.choices = choices
        self.explanation = explanation
        self.speech = speech
        self.wordID = wordID
        self.answerLanguage = answerLanguage
    }
}

/// Practice until every item was answered correctly `target` times in a row.
/// Wrong answers come back two items later, correct ones a bit later until
/// they reach the target ("mastery learning").
public struct MasterySession: Sendable {
    public let items: [MasteryItem]
    public let target: Int
    public private(set) var queue: [String]
    public private(set) var position = 0
    public private(set) var streaks: [String: Int] = [:]
    public private(set) var firstTry: [String: Bool] = [:]
    public private(set) var answers = 0
    public private(set) var correctAnswers = 0
    private let byID: [String: MasteryItem]

    public init<G: RandomNumberGenerator>(items: [MasteryItem], target: Int = 2, using generator: inout G) {
        self.items = items
        self.target = max(1, target)
        self.queue = items.map(\.id).shuffled(using: &generator)
        self.byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public var current: MasteryItem? { position < queue.count ? byID[queue[position]] : nil }
    public var isFinished: Bool { current == nil }
    public var isEmpty: Bool { items.isEmpty }

    /// Correct answers in a row for the current item; 0 means first round,
    /// shown as multiple choice when choices exist.
    public var currentStreak: Int { current.map { streaks[$0.id] ?? 0 } ?? 0 }
    public var isFirstAttempt: Bool { current.map { firstTry[$0.id] == nil } ?? false }

    public var masteredCount: Int { items.filter { (streaks[$0.id] ?? 0) >= target }.count }

    public var progress: Double {
        guard !items.isEmpty else { return 1 }
        let points = items.reduce(0) { $0 + min(streaks[$1.id] ?? 0, target) }
        return Double(points) / Double(items.count * target)
    }

    /// Share of items answered correctly on the very first try.
    public var firstTryScore: Double {
        guard !firstTry.isEmpty else { return 0 }
        return Double(firstTry.values.filter { $0 }.count) / Double(firstTry.count)
    }

    public mutating func answer(correct: Bool) {
        guard let item = current else { return }
        answers += 1
        if correct { correctAnswers += 1 }
        if firstTry[item.id] == nil { firstTry[item.id] = correct }
        let streak = correct ? (streaks[item.id] ?? 0) + 1 : 0
        streaks[item.id] = streak
        if streak < target {
            let gap = correct ? 4 : 2
            queue.insert(item.id, at: min(queue.count, position + 1 + gap))
        }
        position += 1
    }
}

// MARK: - Building exercises

public enum GrammarBuilder {
    /// Verbs the learner knows that can be conjugated, most recently reviewed first.
    public static func learnedVerbs(progress: LearnerProgress, words: WordIndex) -> [(Word, TurkishVerb)] {
        var seen = Set<String>()
        return progress.cards
            .sorted { $0.value.lastReview > $1.value.lastReview }
            .compactMap { entry -> (Word, TurkishVerb)? in
                guard let word = words[entry.key], let verb = word.turkishVerb,
                      seen.insert(verb.dictionaryForm).inserted else { return nil }
                return (word, verb)
            }
    }

    public static func state(of stage: GrammarStage, in stages: [GrammarStage], progress: LearnerProgress,
                             words: WordIndex) -> StageState {
        if progress.grammar[stage.id]?.isCompleted == true { return .completed }
        if let index = stages.firstIndex(of: stage), index > 0 {
            let previous = stages[index - 1]
            if progress.grammar[previous.id]?.isCompleted != true {
                return .locked(reason: "Schließe zuerst „\(previous.title)“ ab.")
            }
        }
        let verbs = learnedVerbs(progress: progress, words: words).count
        if verbs < stage.requiresVerbs {
            return .locked(reason: "Lerne zuerst \(stage.requiresVerbs) Verben (\(verbs)/\(stage.requiresVerbs)).")
        }
        return .open
    }

    /// The exercises of a stage.
    public static func items<G: RandomNumberGenerator>(
        for stage: GrammarStage, progress: LearnerProgress, words: WordIndex, using generator: inout G
    ) -> [MasteryItem] {
        switch stage.kind {
        case .pronouns: return pronounItems(using: &generator)
        case .verbEndings: return endingItems(progress: progress, words: words, using: &generator)
        case .modelConjugation:
            let verbs = (stage.modelVerbs ?? ["gelmek"]).compactMap { TurkishVerb($0) }
            return modelItems(verbs: verbs, tense: stage.tense ?? .present, using: &generator)
        case .conjugation:
            return conjugationItems(tense: stage.tense ?? .present, progress: progress, words: words,
                                    using: &generator)
        }
    }

    static func pronounItems<G: RandomNumberGenerator>(using generator: inout G) -> [MasteryItem] {
        let pairs: [(String, String)] = [
            ("ich", "ben"), ("du", "sen"), ("er / sie / es", "o"), ("wir", "biz"),
            ("ihr", "siz"), ("sie (Plural)", "onlar"), ("Sie (höflich)", "siz"),
        ]
        let all = ["ben", "sen", "o", "biz", "siz", "onlar"]
        return pairs.map { german, turkish in
            let others = all.filter { $0 != turkish }.shuffled(using: &generator).prefix(3)
            return MasteryItem(id: "pronoun-\(german)", kicker: "Personalpronomen", prompt: german,
                               detail: "Wie heißt das auf Türkisch?", answers: [turkish],
                               choices: (Array(others) + [turkish]).shuffled(using: &generator),
                               speech: turkish)
        }
    }

    static func endingItems<G: RandomNumberGenerator>(
        progress: LearnerProgress, words: WordIndex, using generator: inout G
    ) -> [MasteryItem] {
        var verbs = learnedVerbs(progress: progress, words: words).map(\.1).filter { $0.prefix.isEmpty }
        for fallback in ["gelmek", "yapmak", "okumak", "görmek", "bilmek", "almak", "içmek", "konuşmak"]
        where verbs.count < 8 {
            if let verb = TurkishVerb(fallback), !verbs.contains(verb) { verbs.append(verb) }
        }
        let chosen = Array(verbs.shuffled(using: &generator).prefix(8))
        var items: [MasteryItem] = []
        for (index, verb) in chosen.enumerated() {
            let german = germanMeaning(of: verb, in: words)
            if index.isMultiple(of: 2) {
                let ending = String(verb.ending)
                items.append(MasteryItem(
                    id: "ending-\(verb.infinitive)", kicker: "-mak oder -mek?", prompt: "\(verb.stem)___",
                    detail: german.map { "\($0) – welche Endung? Achte auf den letzten Vokal." },
                    answers: [ending], choices: ["mak", "mek"],
                    explanation: "Letzter Vokal „\(TurkishSounds.lastVowel(verb.stem).map(String.init) ?? "")“ → \(verb.infinitive)",
                    speech: verb.infinitive))
            } else {
                let distractors = [verb.infinitive.dropLast().description, verb.stem + "m",
                                   String(verb.stem.dropLast())].filter { !$0.isEmpty && $0 != verb.stem }
                items.append(MasteryItem(
                    id: "stem-\(verb.infinitive)", kicker: "Wie lautet der Stamm?", prompt: verb.infinitive,
                    detail: german.map { "\($0) – ohne -mak / -mek" },
                    answers: [verb.stem],
                    choices: (Array(distractors.prefix(3)) + [verb.stem]).shuffled(using: &generator),
                    explanation: "\(verb.stem) + \(verb.ending)", speech: verb.infinitive))
            }
        }
        return items
    }

    static func modelItems<G: RandomNumberGenerator>(
        verbs: [TurkishVerb], tense: Tense, using generator: inout G
    ) -> [MasteryItem] {
        var items: [MasteryItem] = []
        for (index, verb) in verbs.enumerated() {
            // The first model verb with all persons, further ones with three persons.
            let persons = index == 0 ? Person.allCases : Array(Person.allCases.shuffled(using: &generator).prefix(3))
            for person in persons {
                items.append(conjugationItem(verb: verb, german: nil, tense: tense, person: person,
                                             using: &generator))
            }
        }
        return items
    }

    static func conjugationItems<G: RandomNumberGenerator>(
        tense: Tense, progress: LearnerProgress, words: WordIndex, using generator: inout G
    ) -> [MasteryItem] {
        var verbs = learnedVerbs(progress: progress, words: words).shuffled(using: &generator)
        if tense == .aorist {
            // Irregular verbs first, so the exceptions are practised.
            verbs.sort { $0.1.irregularities.contains(.aorist) && !$1.1.irregularities.contains(.aorist) }
        }
        let chosen = Array(verbs.prefix(6))
        var items: [MasteryItem] = []
        var usedPersons: [Person] = Person.allCases.shuffled(using: &generator)
        for (word, verb) in chosen {
            let count = chosen.count < 4 ? 3 : 2
            for _ in 0..<count {
                if usedPersons.isEmpty { usedPersons = Person.allCases.shuffled(using: &generator) }
                let person = usedPersons.removeFirst()
                items.append(conjugationItem(verb: verb, german: word.native, tense: tense, person: person,
                                             wordID: word.id, using: &generator))
            }
        }
        return items
    }

    static func conjugationItem<G: RandomNumberGenerator>(
        verb: TurkishVerb, german: String?, tense: Tense, person: Person, wordID: String? = nil,
        using generator: inout G
    ) -> MasteryItem {
        let form = verb.conjugate(tense, person)
        var options = Set([form])
        for other in Person.allCases.shuffled(using: &generator) where options.count < 4 {
            options.insert(verb.conjugate(tense, other))
        }
        let germanPart = german.map { " (\($0))" } ?? ""
        var explanation = verb.breakdown(tense, person)
        if let irregular = verb.irregularities.first(where: { tense == .aorist || $0 != .aorist }) {
            explanation += " · " + irregular.title
        }
        return MasteryItem(
            id: "conj-\(tense.rawValue)-\(verb.dictionaryForm)-\(person.turkish)",
            kicker: "\(tense.displayName) · \(tense.cue)",
            prompt: "\(person.turkish) + \(verb.dictionaryForm)",
            detail: "\(person.german)\(germanPart)",
            answers: [form, "\(person.turkish) \(form)"],
            choices: Array(options).shuffled(using: &generator),
            explanation: explanation,
            speech: form,
            wordID: wordID)
    }

    static func germanMeaning(of verb: TurkishVerb, in words: WordIndex) -> String? {
        words.bank.words.first { $0.partOfSpeech == .verb && TurkishText.normalized($0.translation) == verb.dictionaryForm }?.native
    }

    // MARK: Vocabulary mastery ("Festigen")

    /// Learned words for the consolidation practice: German prompt, Turkish answer.
    public static func vocabularyItems<G: RandomNumberGenerator>(
        wordIDs: [String], words: WordIndex, using generator: inout G
    ) -> [MasteryItem] {
        wordIDs.compactMap { id -> MasteryItem? in
            guard let word = words[id] else { return nil }
            let distractors = DistractorPicker.distractors(for: word, in: words.bank.words, answer: \.translation,
                                                           using: &generator)
            var detail = word.partOfSpeech.displayName
            if let verb = word.turkishVerb, verb.isIrregular { detail += " · unregelmäßig" }
            return MasteryItem(
                id: "word-\(id)", kicker: "Wie heißt das auf Türkisch?", prompt: word.nativeWithArticle,
                detail: detail, answers: word.acceptedTranslations,
                choices: (distractors.map(\.translation) + [word.translation]).shuffled(using: &generator),
                explanation: word.cloze.plain, speech: word.translation, wordID: id)
        }
    }
}

extension LearnerProgress {
    /// Sentence exercises with inflected forms open once the present tense is mastered.
    public var inflectionUnlocked: Bool { grammar["present"]?.isCompleted == true }

    public mutating func recordGrammarSession(stageID: String, firstTryScore: Double, at date: Date) {
        var record = grammar[stageID] ?? GrammarRecord()
        record.sessions += 1
        record.bestFirstTry = max(record.bestFirstTry, firstTryScore)
        if record.completedAt == nil { record.completedAt = date }
        grammar[stageID] = record
    }
}
