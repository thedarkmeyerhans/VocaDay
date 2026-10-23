import Foundation

/// Everything the statistics screen shows, computed from the progress.
public struct LearningStatistics: Sendable {
    public struct Day: Identifiable, Hashable, Sendable {
        public var id: DayKey { day }
        public let day: DayKey
        public let date: Date
        public let stats: DayStats

        public var accuracy: Double? {
            stats.reviews == 0 ? nil : Double(stats.correct) / Double(stats.reviews)
        }
    }

    public struct Forecast: Identifiable, Hashable, Sendable {
        public var id: Date { date }
        public let date: Date
        /// Words due that day (today includes overdue words).
        public let count: Int
    }

    public struct LetterProgress: Identifiable, Hashable, Sendable {
        public var id: String { letter }
        public let letter: String
        public let learned: Int
        public let total: Int

        public var fraction: Double { total == 0 ? 0 : Double(learned) / Double(total) }
    }

    /// Memory states of the learned words.
    public enum Stage: String, CaseIterable, Sendable {
        case learning = "Lernend"
        case young = "Jung"
        case mature = "Gefestigt"

        public var explanation: String {
            switch self {
            case .learning: return "gerade neu oder vergessen"
            case .young: return "sitzt für einige Tage"
            case .mature: return "sitzt drei Wochen und länger"
            }
        }
    }

    public let totalWords: Int
    public let learned: Int
    public let stages: [Stage: Int]
    public let plannedAhead: Int

    public let currentStreak: Int
    public let longestStreak: Int
    public let activeDays: Int
    public let totalReviews: Int
    public let totalSeconds: Double
    public let averageStability: Double

    /// Share of correct answers over the last 30 days.
    public let accuracy30: Double?
    /// Share of review-phase words remembered over the last 30 days. FSRS
    /// aims to keep this at the desired retention.
    public let retention30: Double?
    public let retentionSamples30: Int
    public let desiredRetention: Double

    /// Share of running text (subtitle corpus) made up of the learned words.
    public let coverage: Double
    /// Coverage if every word of the bank were learned.
    public let maximumCoverage: Double

    /// The last 30 days, oldest first.
    public let recentDays: [Day]
    /// The last 18 weeks for the calendar heatmap, starting on a Monday.
    public let heatmap: [Day]
    public let forecast: [Forecast]
    public let letters: [LetterProgress]
    public let tests: [TestResult]

    public var learnedToday: Int { recentDays.last?.stats.newWords ?? 0 }

    public static func make(progress: LearnerProgress, words: WordIndex, now: Date,
                            calendar: Calendar = .current) -> LearningStatistics {
        let today = DayKey(now, calendar: calendar)
        let cards = progress.cards.filter { words[$0.key] != nil }

        var stages: [Stage: Int] = [:]
        for card in cards.values {
            let stage: Stage = card.phase != .review ? .learning : (card.isMature ? .mature : .young)
            stages[stage, default: 0] += 1
        }

        func day(_ key: DayKey) -> Day {
            Day(day: key, date: key.date(calendar: calendar) ?? now, stats: progress.stats[key] ?? DayStats())
        }
        let recent = (0..<30).reversed().map { day(today.adding(days: -$0, calendar: calendar)) }

        // Heatmap: full weeks, Monday first, ending with the current week.
        let weekday = calendar.component(.weekday, from: now)  // 1 = Sunday
        let daysSinceMonday = (weekday + 5) % 7
        let heatmapStart = today.adding(days: -(17 * 7 + daysSinceMonday), calendar: calendar)
        let heatmapLength = 17 * 7 + daysSinceMonday + 1
        let heatmap = (0..<heatmapLength).map { day(heatmapStart.adding(days: $0, calendar: calendar)) }

        let forecast: [Forecast] = (0..<14).map { offset in
            let key = today.adding(days: offset, calendar: calendar)
            let count = cards.values.filter { card in
                let dueDay = DayKey(card.due, calendar: calendar)
                return offset == 0 ? dueDay <= key : dueDay == key
            }.count
            return Forecast(date: key.date(calendar: calendar) ?? now, count: count)
        }

        let alphabet = Alphabet.forLanguage(progress.settings.pair.native)
        var totals: [String: Int] = [:]
        var learnedPerLetter: [String: Int] = [:]
        for word in words.bank.words {
            guard let letter = alphabet.letter(for: word.native) else { continue }
            totals[letter, default: 0] += 1
            if cards[word.id] != nil { learnedPerLetter[letter, default: 0] += 1 }
        }
        let letters = alphabet.letters.compactMap { letter -> LetterProgress? in
            guard let total = totals[letter], total > 0 else { return nil }
            return LetterProgress(letter: letter, learned: learnedPerLetter[letter] ?? 0, total: total)
        }

        let last30 = recent.map(\.stats)
        let reviews30 = last30.reduce(0) { $0 + $1.reviews }
        let correct30 = last30.reduce(0) { $0 + $1.correct }
        let reviewTotal30 = last30.reduce(0) { $0 + $1.reviewTotal }
        let reviewCorrect30 = last30.reduce(0) { $0 + $1.reviewCorrect }

        let activeKeys = progress.stats.filter { $0.value.reviews > 0 }.keys.sorted()
        var longest = 0
        var run = 0
        var previous: DayKey?
        for key in activeKeys {
            if let previous, previous.adding(days: 1, calendar: calendar) == key {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = key
        }

        let frequencyTotal = 1_000_000.0
        let learnedFrequency = cards.keys.compactMap { words[$0]?.frequency }.reduce(0, +)
        let bankFrequency = words.bank.words.compactMap(\.frequency).reduce(0, +)

        return LearningStatistics(
            totalWords: words.bank.words.count,
            learned: cards.count,
            stages: stages,
            plannedAhead: progress.plans.filter { $0.key > today }.values.reduce(0) { $0 + $1.wordIDs.count },
            currentStreak: progress.streak(today: today, calendar: calendar),
            longestStreak: longest,
            activeDays: activeKeys.count,
            totalReviews: progress.stats.values.reduce(0) { $0 + $1.reviews },
            totalSeconds: progress.stats.values.reduce(0) { $0 + $1.seconds },
            averageStability: cards.isEmpty ? 0
                : cards.values.map(\.stability).reduce(0, +) / Double(cards.count),
            accuracy30: reviews30 == 0 ? nil : Double(correct30) / Double(reviews30),
            retention30: reviewTotal30 == 0 ? nil : Double(reviewCorrect30) / Double(reviewTotal30),
            retentionSamples30: reviewTotal30,
            desiredRetention: progress.settings.desiredRetention,
            coverage: min(1, learnedFrequency / frequencyTotal),
            maximumCoverage: min(1, bankFrequency / frequencyTotal),
            recentDays: recent,
            heatmap: heatmap,
            forecast: forecast,
            letters: letters,
            tests: progress.tests
        )
    }
}
