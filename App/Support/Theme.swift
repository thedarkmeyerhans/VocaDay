import SwiftUI
import VocaDayCore

enum Theme {
    static let cornerRadius: CGFloat = 18
    /// Keeps lines readable on the wide iPad screen.
    static let maxContentWidth: CGFloat = 680

    static let correct = Color.green
    static let wrong = Color.red
}

extension View {
    /// Card look used throughout the app.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    /// Centers content with a readable width on iPad.
    func readableWidth() -> some View {
        frame(maxWidth: Theme.maxContentWidth).frame(maxWidth: .infinity)
    }
}

extension WordStatus {
    var color: Color {
        switch self {
        case .upcoming: return .gray
        case .learning: return .orange
        case .review: return .blue
        case .mature: return .green
        }
    }
}

struct SpeakButton: View {
    let text: String
    var language: Language = .turkish

    var body: some View {
        Button {
            Speaker.shared.speak(text, language: language)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
                .padding(10)
                .background(Color.accentColor.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Vorlesen")
    }
}

/// Shows a target-language sentence with the learned word highlighted.
struct HighlightedSentence: View {
    let cloze: ClozeSentence

    var body: some View {
        let highlighted = Text(cloze.answer).bold().foregroundStyle(Color.accentColor)
        Text("\(cloze.before)\(highlighted)\(cloze.after)")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
    }
}

extension Date {
    /// "in 3 Tagen", "morgen", "jetzt"
    func relativeDescription(from now: Date = Date()) -> String {
        if self <= now { return "jetzt fällig" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: now)
    }
}

extension TimeInterval {
    /// Short interval label for rating buttons: "1 Min", "3 T", "2 Mon".
    var shortIntervalLabel: String {
        let minutes = self / 60
        if minutes < 60 { return "\(max(1, Int(minutes.rounded()))) Min" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded())) Std" }
        let days = hours / 24
        if days < 31 { return "\(Int(days.rounded())) T" }
        if days < 365 { return "\(Int((days / 30).rounded())) Mon" }
        return String(format: "%.1f J", days / 365)
    }
}
