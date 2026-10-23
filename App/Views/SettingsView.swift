import SwiftUI
import UIKit
import VocaDayCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false
    @State private var notificationsAllowed = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Muttersprache", value: "\(model.settings.pair.native.flag) \(model.settings.pair.native.displayName)")
                Picker("Ich lerne", selection: binding(\.pair)) {
                    ForEach(LanguagePair.available, id: \.self) { pair in
                        Text("\(pair.target.flag) \(pair.target.displayName)").tag(pair)
                    }
                }
            } header: {
                Text("Sprachen")
            } footer: {
                Text("Weitere Sprachen folgen.")
            }

            Section {
                Picker("Modus", selection: binding(\.mode)) {
                    ForEach(SelectionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Stepper(value: binding(\.newWordsPerDay), in: LearnerSettings.newWordsRange) {
                    LabeledContent("Neue Wörter pro Tag", value: "\(model.settings.newWordsPerDay)")
                }
                Toggle("Satzübungen einmischen", isOn: binding(\.mixSentenceExercises))
                Picker("Behaltensziel", selection: binding(\.desiredRetention)) {
                    Text("85 % – weniger Wiederholungen").tag(0.85)
                    Text("90 % – empfohlen").tag(0.9)
                    Text("95 % – sehr sicher").tag(0.95)
                }
            } header: {
                Text("Lernen")
            } footer: {
                Text(model.settings.mode.explanation + " Ein höheres Behaltensziel bedeutet häufigere Wiederholungen.")
            }

            Section {
                Toggle("Wort des Tages", isOn: binding(\.notificationsEnabled))
                if model.settings.notificationsEnabled {
                    DatePicker("Uhrzeit", selection: notificationTime, displayedComponents: .hourAndMinute)
                }
                Toggle("Erinnerung am Abend", isOn: binding(\.eveningReminderEnabled))
                if model.settings.eveningReminderEnabled {
                    Picker("Abends um", selection: binding(\.eveningReminderHour)) {
                        ForEach(16...22, id: \.self) { hour in
                            Text("\(hour):00 Uhr").tag(hour)
                        }
                    }
                }
                if !notificationsAllowed {
                    Button("Mitteilungen in den iOS-Einstellungen erlauben") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("Benachrichtigungen")
            }

            Section("Info") {
                NavigationLink("So funktioniert das Lernen") { LearningMethodView() }
                NavigationLink("Quellen & Lizenzen") { SourcesView() }
                LabeledContent("Wörter in der Datenbank", value: "\(model.words.bank.words.count)")
                LabeledContent("Version", value: appVersion)
            }

            Section {
                Button("Lernfortschritt zurücksetzen", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Einstellungen")
        .task { await refreshAuthorization() }
        .confirmationDialog("Wirklich alles zurücksetzen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) { model.resetProgress() }
        } message: {
            Text("Alle gelernten Wörter und Statistiken werden gelöscht.")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LearnerSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in
                model.updateSettings { $0[keyPath: keyPath] = value }
                Task { await refreshAuthorization(request: true) }
            }
        )
    }

    private var notificationTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: model.settings.notificationHour,
                                                           minute: model.settings.notificationMinute)) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.updateSettings {
                    $0.notificationHour = components.hour ?? 8
                    $0.notificationMinute = components.minute ?? 0
                }
            }
        )
    }

    private func refreshAuthorization(request: Bool = false) async {
        let wantsNotifications = model.settings.notificationsEnabled || model.settings.eveningReminderEnabled
        var allowed = await model.notifications.isAuthorized()
        if !allowed && request && wantsNotifications {
            allowed = await model.notifications.requestAuthorization()
            if allowed { model.rescheduleNotifications() }
        }
        notificationsAllowed = allowed || !wantsNotifications
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

struct SourcesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section("Wortdaten") {
                Text(model.words.bank.attribution)
                Link("FrequencyWords auf GitHub",
                     destination: URL(string: "https://github.com/hermitdave/FrequencyWords")!)
                Link("Lizenz CC BY-SA 4.0",
                     destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
            }
            Section("Lernalgorithmus") {
                Text("FSRS-5 (Free Spaced Repetition Scheduler) von Open Spaced Repetition, MIT-Lizenz.")
                Link("open-spaced-repetition auf GitHub",
                     destination: URL(string: "https://github.com/open-spaced-repetition")!)
            }
            Section("Aussprache") {
                Text("Die Aussprache nutzt die Sprachausgabe von iOS. Unter Einstellungen › Bedienungshilfen › Gesprochene Inhalte › Stimmen › Türkisch kannst du eine bessere Stimme laden.")
            }
        }
        .navigationTitle("Quellen & Lizenzen")
    }
}
