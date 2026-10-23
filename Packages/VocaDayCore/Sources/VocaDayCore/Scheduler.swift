import Foundation

/// How well a word was remembered.
public enum Rating: Int, Codable, CaseIterable, Sendable {
    case again = 1, hard = 2, good = 3, easy = 4

    public var displayName: String {
        switch self {
        case .again: return "Nochmal"
        case .hard: return "Schwer"
        case .good: return "Gut"
        case .easy: return "Leicht"
        }
    }
}

/// Memory state of one word for one learner.
public struct CardState: Codable, Hashable, Sendable {
    public enum Phase: String, Codable, Sendable {
        /// Seen for the first time, not yet remembered once.
        case learning
        /// Remembered at least once; reviewed at growing intervals.
        case review
        /// Forgotten after having been in review.
        case relearning
    }

    /// Days after which the chance of recalling the word has dropped to 90 %.
    public var stability: Double
    /// 1 (easy) … 10 (hard).
    public var difficulty: Double
    public var due: Date
    public var lastReview: Date
    public var phase: Phase
    public var reps: Int
    public var lapses: Int

    public init(stability: Double, difficulty: Double, due: Date, lastReview: Date,
                phase: Phase, reps: Int, lapses: Int) {
        self.stability = stability
        self.difficulty = difficulty
        self.due = due
        self.lastReview = lastReview
        self.phase = phase
        self.reps = reps
        self.lapses = lapses
    }

    /// Words with a stability of three weeks or more count as consolidated.
    public var isMature: Bool { phase == .review && stability >= 21 }
}

/// FSRS-5 (Free Spaced Repetition Scheduler), the memory model used by Anki
/// since 23.10. It models every word with a stability S and a difficulty D and
/// schedules the next review when the predicted recall probability drops to
/// the desired retention.
///
/// Reference: Ye, Su, Cao: "A Stochastic Shortest Path Algorithm for
/// Optimizing Spaced Repetition Scheduling" (KDD 2022) and
/// https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
public struct FSRSScheduler: Sendable {
    /// Default FSRS-5 parameters, fitted on hundreds of millions of reviews.
    public static let defaultParameters: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
        2.9898, 0.51655, 0.6621,
    ]

    static let decay = -0.5
    static let factor = 19.0 / 81.0

    public var parameters: [Double]
    /// Target probability of remembering a word when it is due (0.7 … 0.97).
    public var desiredRetention: Double
    public var maximumInterval: Double

    /// Delay before a forgotten or new word comes back within the session.
    public static let againDelay: TimeInterval = 60
    public static let hardLearningDelay: TimeInterval = 5 * 60

    public init(desiredRetention: Double = 0.9,
                parameters: [Double] = FSRSScheduler.defaultParameters,
                maximumInterval: Double = 3650) {
        precondition(parameters.count == 19, "FSRS-5 needs 19 parameters")
        self.parameters = parameters
        self.desiredRetention = min(max(desiredRetention, 0.7), 0.97)
        self.maximumInterval = maximumInterval
    }

    private var w: [Double] { parameters }

    // MARK: Model

    /// Probability of recalling a word `elapsedDays` after the last review.
    public func retrievability(elapsedDays: Double, stability: Double) -> Double {
        pow(1 + Self.factor * max(0, elapsedDays) / stability, Self.decay)
    }

    public func retrievability(of card: CardState, at date: Date) -> Double {
        retrievability(elapsedDays: Self.days(from: card.lastReview, to: date), stability: card.stability)
    }

    /// Interval in days at which recall drops to `desiredRetention`.
    public func interval(for stability: Double) -> Double {
        let raw = stability / Self.factor * (pow(desiredRetention, 1 / Self.decay) - 1)
        return min(max(raw.rounded(), 1), maximumInterval)
    }

    func initialStability(_ rating: Rating) -> Double {
        max(w[rating.rawValue - 1], 0.1)
    }

    func initialDifficulty(_ rating: Rating) -> Double {
        clampDifficulty(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1)
    }

    func nextDifficulty(_ difficulty: Double, _ rating: Rating) -> Double {
        let delta = -w[6] * Double(rating.rawValue - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        let reverted = w[7] * initialDifficulty(.easy) + (1 - w[7]) * damped
        return clampDifficulty(reverted)
    }

    func recallStability(_ d: Double, _ s: Double, _ r: Double, _ rating: Rating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1
        let easyBonus = rating == .easy ? w[16] : 1
        return s * (exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1)
            * hardPenalty * easyBonus + 1)
    }

    func forgetStability(_ d: Double, _ s: Double, _ r: Double) -> Double {
        let longTerm = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        let shortTerm = s / exp(w[17] * w[18])
        return min(longTerm, shortTerm)
    }

    func shortTermStability(_ s: Double, _ rating: Rating) -> Double {
        var increase = exp(w[17] * (Double(rating.rawValue) - 3 + w[18]))
        if rating.rawValue >= Rating.good.rawValue { increase = max(increase, 1) }
        return s * increase
    }

    private func clampDifficulty(_ d: Double) -> Double { min(max(d, 1), 10) }

    // MARK: Scheduling

    /// Returns the new memory state after answering a word with `rating`.
    /// Pass `nil` for a word that is reviewed for the first time.
    public func schedule(_ card: CardState?, rating: Rating, at now: Date) -> CardState {
        guard let card else {
            let stability = initialStability(rating)
            return finish(stability: stability, difficulty: initialDifficulty(rating),
                          rating: rating, previousPhase: nil, reps: 1, lapses: 0, now: now)
        }

        let elapsed = Self.days(from: card.lastReview, to: now)
        let difficulty = nextDifficulty(card.difficulty, rating)
        let stability: Double
        var lapses = card.lapses

        if elapsed < 1 {
            stability = shortTermStability(card.stability, rating)
        } else {
            let r = retrievability(elapsedDays: elapsed, stability: card.stability)
            if rating == .again {
                stability = forgetStability(card.difficulty, card.stability, r)
            } else {
                stability = recallStability(card.difficulty, card.stability, r, rating)
            }
        }
        if rating == .again && card.phase == .review {
            lapses += 1
        }
        return finish(stability: max(stability, 0.1), difficulty: difficulty, rating: rating,
                      previousPhase: card.phase, reps: card.reps + 1, lapses: lapses, now: now)
    }

    private func finish(stability: Double, difficulty: Double, rating: Rating,
                        previousPhase: CardState.Phase?, reps: Int, lapses: Int,
                        now: Date) -> CardState {
        let phase: CardState.Phase
        let due: Date
        switch rating {
        case .again:
            phase = previousPhase == .review || previousPhase == .relearning ? .relearning : .learning
            due = now.addingTimeInterval(Self.againDelay)
        case .hard where previousPhase != .review:
            // Not remembered reliably yet: once more within the session.
            phase = previousPhase ?? .learning
            due = now.addingTimeInterval(Self.hardLearningDelay)
        default:
            phase = .review
            due = now.addingTimeInterval(interval(for: stability) * 86_400)
        }
        return CardState(stability: stability, difficulty: difficulty, due: due, lastReview: now,
                         phase: phase, reps: reps, lapses: lapses)
    }

    static func days(from start: Date, to end: Date) -> Double {
        end.timeIntervalSince(start) / 86_400
    }
}
