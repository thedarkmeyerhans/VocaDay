import Foundation

/// A local notification to schedule. Platform independent so it can be tested;
/// the app turns it into a `UNNotificationRequest`.
public struct Reminder: Hashable, Sendable {
    public enum Kind: String, Sendable { case wordOfTheDay, evening }

    public let id: String
    public let kind: Kind
    public let title: String
    public let body: String
    public let date: DateComponents
}

public enum NotificationPlanner {
    public static let identifierPrefix = "vocaday."
    /// iOS keeps at most 64 pending notifications per app.
    public static let daysAhead = 14

    /// - Parameter hasOpenWorkToday: whether new words or reviews are still open
    ///   today; if not, today's evening reminder is left out.
    public static func entries(for progress: LearnerProgress, words: WordIndex, now: Date,
                               calendar: Calendar = .current, hasOpenWorkToday: Bool) -> [Reminder] {
        let settings = progress.settings
        guard settings.onboardingCompleted else { return [] }
        let today = DayKey(now, calendar: calendar)
        var result: [Reminder] = []

        for offset in 0..<daysAhead {
            let day = today.adding(days: offset, calendar: calendar)
            guard let dayStart = day.date(calendar: calendar) else { continue }
            let base = calendar.dateComponents([.year, .month, .day], from: dayStart)

            if settings.notificationsEnabled {
                var components = base
                components.hour = settings.notificationHour
                components.minute = settings.notificationMinute
                if let fireDate = calendar.date(from: components), fireDate > now {
                    let planned = (progress.plans[day]?.wordIDs ?? []).compactMap { words[$0] }
                    let (title, body) = wordOfTheDayText(planned)
                    result.append(Reminder(id: "\(identifierPrefix)word.\(day)", kind: .wordOfTheDay,
                                           title: title, body: body, date: components))
                }
            }

            if settings.eveningReminderEnabled {
                if offset == 0 && !hasOpenWorkToday { continue }
                var components = base
                components.hour = settings.eveningReminderHour
                components.minute = 0
                if let fireDate = calendar.date(from: components), fireDate > now {
                    result.append(Reminder(
                        id: "\(identifierPrefix)evening.\(day)", kind: .evening,
                        title: "Deine Wörter warten",
                        body: "Fünf Minuten Wiederholung reichen, damit du sie nicht vergisst.",
                        date: components))
                }
            }
        }
        return result
    }

    static func wordOfTheDayText(_ words: [Word]) -> (String, String) {
        guard let first = words.first else {
            return ("Zeit zum Wiederholen", "Festige heute die Wörter, die du schon kennst.")
        }
        if words.count == 1 {
            return ("Dein Wort des Tages", "\(first.translation) – \(first.nativeWithArticle)")
        }
        let shown = words.prefix(3).map { "\($0.translation) (\($0.native))" }.joined(separator: ", ")
        let more = words.count > 3 ? " und \(words.count - 3) weitere" : ""
        return ("Deine \(words.count) neuen Wörter", shown + more)
    }
}
