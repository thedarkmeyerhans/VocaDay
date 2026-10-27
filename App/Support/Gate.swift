import AppIntents
import Foundation
import SwiftUI

// MARK: - Pass

/// The "Zwangsmodus" pass: after a correct answer the learner may use the
/// other app for a few minutes. Stored in UserDefaults so the App Intents can
/// answer without loading the whole learning progress.
enum GatePass {
    private static let defaults = UserDefaults.standard
    private static let enabledKey = "gate.enabled"
    private static let passUntilKey = "gate.passUntil"

    static func mirror(enabled: Bool) {
        defaults.set(enabled, forKey: enabledKey)
    }

    static var isEnabled: Bool { defaults.bool(forKey: enabledKey) }

    static var passUntil: Date? {
        defaults.object(forKey: passUntilKey) as? Date
    }

    /// True when the learner has to answer a word before using the other app.
    static func isQuizNeeded(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        return (passUntil ?? .distantPast) <= date
    }

    static func grant(minutes: Int, from date: Date = Date()) {
        defaults.set(date.addingTimeInterval(TimeInterval(max(1, minutes) * 60)), forKey: passUntilKey)
    }

    static func revoke() {
        defaults.removeObject(forKey: passUntilKey)
    }
}

// MARK: - Router

/// A quiz the learner has to pass before returning to `target`.
struct GateRequest: Identifiable {
    let id = UUID()
    let target: GateTargetApp?
    let returnURL: URL?

    var appName: String { target?.name ?? "deine App" }
}

/// Bridges App Intents and deep links to the UI.
@MainActor
final class GateRouter: ObservableObject {
    static let shared = GateRouter()

    @Published var request: GateRequest?

    func present(target: GateTargetApp?) {
        request = GateRequest(target: target, returnURL: target?.url)
    }

    func present(returnURL: URL?) {
        let target = GateTargetApp.allCases.first { $0.url.scheme == returnURL?.scheme }
        request = GateRequest(target: target, returnURL: returnURL ?? target?.url)
    }
}

// MARK: - Apps

enum GateTargetApp: String, CaseIterable, AppEnum {
    case instagram, tiktok, youtube, x, facebook, snapchat, reddit, whatsapp, netflix

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "App"

    static var caseDisplayRepresentations: [GateTargetApp: DisplayRepresentation] = [
        .instagram: "Instagram", .tiktok: "TikTok", .youtube: "YouTube", .x: "X", .facebook: "Facebook",
        .snapchat: "Snapchat", .reddit: "Reddit", .whatsapp: "WhatsApp", .netflix: "Netflix",
    ]

    var name: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .x: return "X"
        case .facebook: return "Facebook"
        case .snapchat: return "Snapchat"
        case .reddit: return "Reddit"
        case .whatsapp: return "WhatsApp"
        case .netflix: return "Netflix"
        }
    }

    /// URL that opens the app again after the quiz.
    var url: URL {
        let scheme: String
        switch self {
        case .instagram: scheme = "instagram://"
        case .tiktok: scheme = "snssdk1233://"
        case .youtube: scheme = "youtube://"
        case .x: scheme = "twitter://"
        case .facebook: scheme = "fb://"
        case .snapchat: scheme = "snapchat://"
        case .reddit: scheme = "reddit://"
        case .whatsapp: scheme = "whatsapp://"
        case .netflix: scheme = "nflx://"
        }
        return URL(string: scheme)!
    }
}

// MARK: - Intents

/// "Quiz nötig?" – used as the condition in a Shortcuts automation.
struct QuizNeededIntent: AppIntent {
    static var title: LocalizedStringResource = "Quiz nötig?"
    static var description = IntentDescription(
        "Prüft, ob vor der App eine Vokabel abgefragt werden muss (VocaDay-Zwangsmodus).")

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: GatePass.isQuizNeeded())
    }
}

/// "VocaDay-Quiz öffnen" – opens the vocabulary quiz; after a correct answer
/// VocaDay switches back to the chosen app.
struct OpenGateQuizIntent: AppIntent {
    static var title: LocalizedStringResource = "VocaDay-Quiz öffnen"
    static var description = IntentDescription(
        "Öffnet die Vokabelabfrage. Nach einer richtigen Antwort geht es zurück zur gewählten App.")
    static var openAppWhenRun = true

    @Parameter(title: "Zurück zu")
    var app: GateTargetApp?

    static var parameterSummary: some ParameterSummary {
        Summary("VocaDay-Quiz öffnen, dann zurück zu \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if GatePass.isQuizNeeded() {
            GateRouter.shared.present(target: app)
        }
        return .result()
    }
}

struct VocaDayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenGateQuizIntent(), phrases: ["\(.applicationName)-Quiz öffnen"],
                    shortTitle: "Vokabel-Quiz", systemImageName: "lock.open.fill")
        AppShortcut(intent: QuizNeededIntent(), phrases: ["Brauche ich ein \(.applicationName)-Quiz?"],
                    shortTitle: "Quiz nötig?", systemImageName: "questionmark.circle")
    }
}
