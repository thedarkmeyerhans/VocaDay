import Foundation

public struct SessionItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let wordID: String
    public let kind: ExerciseKind
}

/// A queue of exercises. New words are introduced between reviews
/// (interleaving), checked right away and once more later in the session.
/// Wrong answers come back a few items later until they are remembered.
public struct LearningSession: Sendable {
    public private(set) var items: [SessionItem]
    public private(set) var position = 0
    public private(set) var answered = 0
    public private(set) var correct = 0
    public private(set) var newWordIDs: [String]
    private var retries: [String: Int] = [:]
    private var nextID: Int

    public static let maxRetriesPerWord = 3

    init(items: [SessionItem], newWordIDs: [String]) {
        self.items = items
        self.newWordIDs = newWordIDs
        self.nextID = items.count
    }

    public var current: SessionItem? { position < items.count ? items[position] : nil }
    public var isFinished: Bool { current == nil }
    public var isEmpty: Bool { items.isEmpty }
    public var remaining: Int { max(0, items.count - position) }
    public var fractionDone: Double { items.isEmpty ? 1 : Double(position) / Double(items.count) }

    /// Moves to the next exercise. `rating` is nil for introductions.
    public mutating func advance(after rating: Rating?) {
        guard let item = current else { return }
        if let rating {
            answered += 1
            if rating != .again { correct += 1 }
            let count = retries[item.wordID, default: 0]
            if rating == .again && count < Self.maxRetriesPerWord {
                retries[item.wordID] = count + 1
                insert(wordID: item.wordID, kind: ExercisePicker.retryKind(after: item.kind), gap: 3)
            } else if rating == .hard && item.kind != .introduction && count < Self.maxRetriesPerWord
                        && newWordIDs.contains(item.wordID) {
                retries[item.wordID] = count + 1
                insert(wordID: item.wordID, kind: item.kind, gap: 5)
            }
        }
        position += 1
    }

    private mutating func insert(wordID: String, kind: ExerciseKind, gap: Int) {
        let index = min(items.count, position + 1 + gap)
        items.insert(SessionItem(id: nextID, wordID: wordID, kind: kind), at: index)
        nextID += 1
    }
}

public enum SessionBuilder {
    /// Today's session: pending new words plus due reviews.
    public static func daily<G: RandomNumberGenerator>(
        progress: LearnerProgress, words: WordIndex, now: Date, style: PracticeStyle,
        includeNewWords: Bool = true, maxReviews: Int = 60, allowInflected: Bool? = nil,
        calendar: Calendar = .current, using generator: inout G
    ) -> LearningSession {
        let today = DayKey(now, calendar: calendar)
        let inflected = allowInflected ?? progress.inflectionUnlocked
        let newIDs = includeNewWords
            ? progress.pendingNewWords(upTo: today).filter { words[$0] != nil }
            : []
        let dueIDs = progress.dueWordIDs(at: now)
            .filter { words[$0] != nil && !newIDs.contains($0) }
            .prefix(maxReviews)

        var counter = 0
        func item(_ id: String, _ kind: ExerciseKind) -> SessionItem {
            defer { counter += 1 }
            return SessionItem(id: counter, wordID: id, kind: kind)
        }

        var reviews = dueIDs.compactMap { id -> SessionItem? in
            guard let word = words[id] else { return nil }
            let kind = ExercisePicker.kind(for: progress.cards[id], style: style, word: word,
                                           allowInflected: inflected, using: &generator)
            return item(id, kind)
        }[...]

        var queue: [SessionItem] = []
        for id in newIDs {
            guard let word = words[id] else { continue }
            let gap = word.cloze.hasGap && (inflected || word.clozeIsBaseForm)
            let firstCheck: ExerciseKind = style == .sentences && gap ? .clozeChoice : .chooseNative
            queue.append(item(id, .introduction))
            queue.append(item(id, firstCheck))
            queue.append(contentsOf: reviews.prefix(2))
            reviews = reviews.dropFirst(2)
        }
        queue.append(contentsOf: reviews)
        for id in newIDs {
            guard let word = words[id] else { continue }
            let gap = word.cloze.hasGap && (inflected || word.clozeIsBaseForm)
            let secondCheck: ExerciseKind = style != .words && gap ? .clozeChoice : .chooseTarget
            queue.append(item(id, secondCheck))
        }
        return LearningSession(items: queue, newWordIDs: newIDs)
    }

    /// Extra practice with already introduced words, weakest first. Used by
    /// the sentence trainer when nothing is due.
    public static func practice<G: RandomNumberGenerator>(
        progress: LearnerProgress, words: WordIndex, now: Date, style: PracticeStyle,
        count: Int = 12, scheduler: FSRSScheduler, using generator: inout G
    ) -> LearningSession {
        let ranked = progress.cards
            .filter { words[$0.key] != nil }
            .sorted { scheduler.retrievability(of: $0.value, at: now) < scheduler.retrievability(of: $1.value, at: now) }
            .prefix(count)
        var items: [SessionItem] = []
        for (index, entry) in ranked.enumerated() {
            guard let word = words[entry.key] else { continue }
            let kind = ExercisePicker.kind(for: entry.value, style: style, word: word,
                                           allowInflected: progress.inflectionUnlocked, using: &generator)
            items.append(SessionItem(id: index, wordID: entry.key, kind: kind))
        }
        return LearningSession(items: items.shuffled(using: &generator), newWordIDs: [])
    }
}
