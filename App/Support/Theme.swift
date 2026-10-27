import SwiftUI
import VocaDayCore

// MARK: - Design tokens

enum Theme {
    static let cornerRadius: CGFloat = 22
    /// Keeps lines readable on the wide iPad screen.
    static let maxContentWidth: CGFloat = 760

    static let coral = Color(hex: 0xFF8A5C)
    static let red = Color(hex: 0xE0453A)
    static let sun = Color(hex: 0xFFD166)

    static let correct = Color(hex: 0x2EB872)
    static let wrong = Color(hex: 0xE5484D)
    static let almost = Color(hex: 0xF5A524)

    static let review = Color(hex: 0x3B82F6)
    static let sentence = Color(hex: 0x8B5CF6)
    static let test = Color(hex: 0x14B8A6)
    static let practice = Color(hex: 0xF59E0B)
    static let streak = Color(hex: 0xFF7A1A)

    /// The sunrise gradient of the app icon.
    static let sunrise = LinearGradient(colors: [coral, red], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func gradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.opacity(0.85), color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Classic colour coding of German articles, helps to remember the gender.
    static func articleColor(_ article: String?) -> Color {
        switch article {
        case "der": return Color(hex: 0x3B82F6)
        case "die": return Color(hex: 0xE5484D)
        case "das": return Color(hex: 0x2EB872)
        default: return .secondary
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Modifiers

extension View {
    /// Card look used throughout the app.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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
        case .notYet: return Color(.systemGray4)
        case .learning: return Theme.practice
        case .review: return Theme.review
        case .mature: return Theme.correct
        }
    }
}

extension LearningStatistics.Stage {
    var color: Color {
        switch self {
        case .learning: return Theme.practice
        case .young: return Theme.review
        case .mature: return Theme.correct
        }
    }
}

// MARK: - Components

struct SpeakButton: View {
    let text: String
    var language: Language = .turkish
    var tint: Color = .accentColor

    var body: some View {
        Button {
            Speaker.shared.speak(text, language: language)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
                .padding(10)
                .background(tint.opacity(0.15), in: Circle())
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(tint)
        .accessibilityLabel("Vorlesen")
    }
}

/// Shows a target-language sentence with the learned word highlighted.
struct HighlightedSentence: View {
    let cloze: ClozeSentence
    var highlight: Color = .accentColor

    var body: some View {
        let highlighted = Text(cloze.answer).bold().foregroundStyle(highlight)
        Text("\(cloze.before)\(highlighted)\(cloze.after)")
    }
}

/// "das Haus" with the article in its gender colour.
struct ArticleWord: View {
    let word: Word
    var font: Font = .title3

    var body: some View {
        if let article = word.article {
            let colored = Text(article).foregroundStyle(Theme.articleColor(article)).bold()
            Text("\(colored) \(word.native)").font(font)
        } else {
            Text(word.native).font(font)
        }
    }
}

struct GradientIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.gradient(color), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .shadow(color: color.opacity(0.35), radius: 6, y: 3)
    }
}

/// Animated circular progress.
struct ProgressRing<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var colors: [Color] = [Theme.coral, Theme.red]
    @ViewBuilder var center: () -> Center

    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(colors.last!.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(AngularGradient(colors: colors + [colors.first!], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.2)) { shown = min(max(progress, 0), 1) }
        }
        .onChange(of: progress) { _, value in
            withAnimation(.spring(duration: 0.6)) { shown = min(max(value, 0), 1) }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.sunrise

    init(gradient: LinearGradient = Theme.sunrise) {
        self.gradient = gradient
    }

    init(color: Color) {
        self.gradient = Theme.gradient(color)
    }

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, gradient: gradient)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let gradient: LinearGradient
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(duration: 0.25), value: configuration.isPressed)
        }
    }
}

/// Subtle press feedback for custom buttons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.bold())
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Pill: View {
    let text: String
    var systemImage: String?
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

// MARK: - Confetti

/// Falling confetti for finished sessions and good test results.
struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let spin: Double
        let size: CGSize
        let color: Color
    }

    @State private var pieces: [Piece] = (0..<90).map { _ in
        Piece(x: .random(in: 0...1), delay: .random(in: 0...0.8), speed: .random(in: 0.25...0.5),
              drift: .random(in: -40...40), spin: .random(in: 2...8),
              size: CGSize(width: .random(in: 6...11), height: .random(in: 9...16)),
              color: [Theme.coral, Theme.red, Theme.sun, Theme.correct, Theme.review, Theme.sentence].randomElement()!)
    }
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 2 + piece.drift) * piece.drift
                    var copy = context
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(t * piece.spin))
                    copy.fill(Path(CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2),
                                          size: piece.size)),
                              with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Formatting

extension Date {
    /// "in 3 Tagen", "morgen", "jetzt fällig"
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

    /// "1 Std 20 Min", "12 Min", "40 Sek"
    var durationLabel: String {
        let total = Int(self.rounded())
        if total < 60 { return "\(total) Sek" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes) Min" }
        return "\(minutes / 60) Std \(minutes % 60) Min"
    }
}

extension Double {
    /// 0.873 → "87 %"
    var percentLabel: String { "\(Int((self * 100).rounded())) %" }
}
