import SwiftUI
import UserNotifications

@main
struct VocaDayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @StateObject private var gate = GateRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(gate)
                .onOpenURL { model.handle(url: $0) }
                .onAppear { delegate.openURL = { [weak model] in model?.handle(url: $0) } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.didBecomeActive() }
                }
        }
    }
}

/// Opens the link of a tapped notification (e.g. "neues Wort an deinem Ort").
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor var openURL: (@MainActor (URL) -> Void)? {
        didSet {
            if let pending, let openURL { openURL(pending) }
            pending = nil
        }
    }
    @MainActor private var pending: URL?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let link = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: link) {
            Task { @MainActor in
                if let openURL = self.openURL { openURL(url) } else { self.pending = url }
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var gate: GateRouter

    var body: some View {
        Group {
            if model.settings.onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $model.deepLinkMastery) { MasteryPracticeView(active: $0) }
        .sheet(item: $gate.request) { GateQuizView(request: $0) }
    }
}

struct MainTabView: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            // On iPad the tabs can be turned into a sidebar.
            TabView {
                ForEach(AppTab.allCases) { tab in
                    Tab(tab.title, systemImage: tab.icon) { tab.content }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView {
                ForEach(AppTab.allCases) { tab in
                    tab.content.tabItem { Label(tab.title, systemImage: tab.icon) }
                }
            }
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today, practice, statistics, words, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Heute"
        case .practice: return "Üben"
        case .statistics: return "Statistik"
        case .words: return "Wörter"
        case .settings: return "Einstellungen"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .practice: return "text.bubble.fill"
        case .statistics: return "chart.bar.xaxis"
        case .words: return "books.vertical.fill"
        case .settings: return "gearshape.fill"
        }
    }

    @MainActor @ViewBuilder
    var content: some View {
        NavigationStack {
            switch self {
            case .today: TodayView()
            case .practice: PracticeView()
            case .statistics: StatisticsView()
            case .words: VocabularyView()
            case .settings: SettingsView()
            }
        }
    }
}
