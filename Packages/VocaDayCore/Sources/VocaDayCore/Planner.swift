import Foundation

/// Assigns new words to days. Days are planned ahead so notifications can
/// already name the word of the day.
public struct DailyPlanner: Sendable {
    public var bank: WordBank
    public var selector: StandardSelector
    public var calendar: Calendar

    public init(bank: WordBank, calendar: Calendar = .current) {
        self.bank = bank
        self.selector = StandardSelector(alphabet: Alphabet.forLanguage(bank.pair.native))
        self.calendar = calendar
    }

    /// Makes sure `today` and the following `daysAhead` days have a plan.
    public func ensurePlans<G: RandomNumberGenerator>(
        _ progress: inout LearnerProgress, today: DayKey, daysAhead: Int = 13,
        using generator: inout G
    ) {
        for offset in 0...max(0, daysAhead) {
            let day = today.adding(days: offset, calendar: calendar)
            guard progress.plans[day] == nil else { continue }
            plan(day: day, count: progress.settings.newWordsPerDay, in: &progress, using: &generator)
        }
    }

    /// Throws away the plans after `today` and plans them again, e.g. after
    /// the number of words per day changed.
    public func replanFuture<G: RandomNumberGenerator>(
        _ progress: inout LearnerProgress, today: DayKey, daysAhead: Int = 13,
        using generator: inout G
    ) {
        let future = progress.plans.keys.filter { $0 > today }.sorted()
        if let first = future.first, let plan = progress.plans[first] {
            progress.letterCursor = plan.cursorBefore
        }
        for day in future { progress.plans[day] = nil }
        ensurePlans(&progress, today: today, daysAhead: daysAhead, using: &generator)
    }

    /// Adds `count` extra words to today ("Noch ein Wort") and re-plans the
    /// following days so the A–Z order continues seamlessly.
    @discardableResult
    public func addExtraWords<G: RandomNumberGenerator>(
        _ count: Int, to progress: inout LearnerProgress, today: DayKey,
        using generator: inout G
    ) -> [Word] {
        let future = progress.plans.keys.filter { $0 > today }.sorted()
        if let first = future.first, let plan = progress.plans[first] {
            progress.letterCursor = plan.cursorBefore
        }
        for day in future { progress.plans[day] = nil }

        let words = pickWords(count, excluding: plannedOrLearned(progress), cursor: &progress.letterCursor,
                              using: &generator)
        var todayPlan = progress.plans[today] ?? DayPlan(wordIDs: [], cursorBefore: progress.letterCursor)
        todayPlan.wordIDs.append(contentsOf: words.map(\.id))
        progress.plans[today] = todayPlan

        ensurePlans(&progress, today: today, using: &generator)
        return words
    }

    private func plan<G: RandomNumberGenerator>(
        day: DayKey, count: Int, in progress: inout LearnerProgress, using generator: inout G
    ) {
        let cursorBefore = progress.letterCursor
        let words = pickWords(count, excluding: plannedOrLearned(progress), cursor: &progress.letterCursor,
                              using: &generator)
        progress.plans[day] = DayPlan(wordIDs: words.map(\.id), cursorBefore: cursorBefore)
    }

    private func pickWords<G: RandomNumberGenerator>(
        _ count: Int, excluding excluded: Set<String>, cursor: inout Int, using generator: inout G
    ) -> [Word] {
        selector.pick(count: max(0, count), from: bank.words, excluding: excluded,
                      cursor: &cursor, using: &generator)
    }

    private func plannedOrLearned(_ progress: LearnerProgress) -> Set<String> {
        var ids = Set(progress.cards.keys)
        for plan in progress.plans.values { ids.formUnion(plan.wordIDs) }
        return ids
    }
}
