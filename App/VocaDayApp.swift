import SwiftUI

@main
struct VocaDayApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.didBecomeActive() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.settings.onboardingCompleted {
            MainTabView()
        } else {
            OnboardingView()
        }
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
            case .words: WordListView()
            case .settings: SettingsView()
            }
        }
    }
}
