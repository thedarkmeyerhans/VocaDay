import CoreLocation
import SwiftUI
import UIKit
import VocaDayCore

private struct SettingsBinding {
    let model: AppModel

    func callAsFunction<Value>(_ keyPath: WritableKeyPath<LearnerSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { value in model.updateSettings { $0[keyPath: keyPath] = value } })
    }
}

// MARK: - Widget & places

struct WidgetSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var places = PlaceMonitor.shared
    @State private var newHour = 12
    @State private var placeName = ""
    @State private var addingPlace = false
    @State private var placeError: String?

    private var binding: SettingsBinding { SettingsBinding(model: model) }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("So kommt das Widget auf den Homescreen", systemImage: "square.grid.2x2.fill")
                        .font(.headline)
                    Text("Homescreen lange drücken › „Bearbeiten“ › „Widget hinzufügen“ › VocaDay. Auch für den Sperrbildschirm verfügbar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(model.settings.widgetHours.sorted(), id: \.self) { hour in
                    Label("\(hour):00 Uhr", systemImage: "clock")
                }
                .onDelete { offsets in
                    let sorted = model.settings.widgetHours.sorted()
                    let removed = Set(offsets.map { sorted[$0] })
                    model.updateSettings { $0.widgetHours.removeAll { removed.contains($0) } }
                }
                HStack {
                    Picker("Neue Uhrzeit", selection: $newHour) {
                        ForEach(5...23, id: \.self) { Text("\($0):00 Uhr").tag($0) }
                    }
                    Button {
                        model.updateSettings {
                            if !$0.widgetHours.contains(newHour) { $0.widgetHours.append(newHour) }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.settings.widgetHours.contains(newHour))
                }
            } header: {
                Text("Uhrzeiten")
            } footer: {
                Text("Zu jeder Uhrzeit zeigt das Widget ein neues Wort. Vor der ersten Uhrzeit des Tages bleibt es zu.")
            }

            Section {
                Stepper(value: binding(\.widgetRepetitions), in: 1...10) {
                    LabeledContent("Richtig bis geschafft", value: "\(model.settings.widgetRepetitions)×")
                }
                Picker("Danach", selection: binding(\.widgetAfterCompletion)) {
                    ForEach(WidgetCompletion.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("Wort abschließen")
            } footer: {
                Text("Tippe auf das Widget: Das Wort wird vorgestellt und so lange abgefragt, bis du es \(model.settings.widgetRepetitions)× hintereinander richtig hast.")
            }

            Section {
                ForEach(model.settings.places) { place in
                    Label(place.name, systemImage: "mappin.circle.fill")
                }
                .onDelete { offsets in
                    for place in offsets.map({ model.settings.places[$0] }) { model.removePlace(place) }
                }
                TextField("Name, z. B. Zuhause oder Bahnhof", text: $placeName)
                Button {
                    addPlace()
                } label: {
                    if addingPlace {
                        ProgressView()
                    } else {
                        Label("Aktuellen Ort speichern", systemImage: "location.fill")
                    }
                }
                .disabled(addingPlace)
                if let placeError {
                    Text(placeError).font(.footnote).foregroundStyle(Theme.wrong)
                }
                if !model.settings.places.isEmpty && !places.canMonitor {
                    Button("Standort „Immer“ erlauben") { openSettings() }
                }
            } header: {
                Text("Orte")
            } footer: {
                Text("Kommst du an einem gespeicherten Ort an (Umkreis 150 m), erscheint sofort ein neues Wort im Widget und als Mitteilung. Dafür braucht VocaDay den Standort „Immer“. Der Standort bleibt auf deinem Gerät.")
            }
        }
        .navigationTitle("Widget & Orte")
    }

    private func addPlace() {
        addingPlace = true
        placeError = nil
        Task {
            let added = await model.addPlace(named: placeName.trimmingCharacters(in: .whitespaces))
            addingPlace = false
            if added {
                placeName = ""
            } else {
                placeError = "Kein Standort verfügbar. Bitte den Standortzugriff für VocaDay erlauben."
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

// MARK: - Zwangsmodus

struct GateSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var gate: GateRouter

    private var binding: SettingsBinding { SettingsBinding(model: model) }

    var body: some View {
        Form {
            Section {
                Toggle("Zwangsmodus", isOn: binding(\.gateEnabled))
                if model.settings.gateEnabled {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if let until = GatePass.passUntil, until > context.date {
                            Label("Frei bis \(until.formatted(date: .omitted, time: .shortened)) Uhr",
                                  systemImage: "lock.open.fill")
                                .foregroundStyle(Theme.correct)
                        } else {
                            Label("Nächste App-Öffnung startet ein Quiz", systemImage: "lock.fill")
                                .foregroundStyle(Theme.coral)
                        }
                    }
                }
            } footer: {
                Text("Bevor du Instagram, TikTok & Co. öffnest, fragt VocaDay eine Vokabel ab. Richtig: Die App ist für eine Weile frei. Falsch: Es kommt das nächste Wort.")
            }

            Section("Regeln") {
                Picker("Frei nach richtiger Antwort", selection: binding(\.gatePassMinutes)) {
                    ForEach([1, 5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { Text("\($0) Min.").tag($0) }
                }
                Stepper(value: binding(\.gateWordTarget), in: 1...5) {
                    LabeledContent("Wort sitzt nach", value: "\(model.settings.gateWordTarget)× richtig")
                }
                Picker("Antworten", selection: binding(\.gateAnswerMode)) {
                    ForEach(TestAnswerMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                LabeledContent("Heute gelernt", value: "\(model.gateKnownToday) Wörter")
                Button("Quiz jetzt ausprobieren") {
                    GatePass.revoke()
                    gate.present(target: nil)
                }
                .disabled(!model.settings.gateEnabled)
            }

            Section {
                SetupStep(number: 1, text: "Öffne die App **Kurzbefehle** › **Automation** › **+** › **App**.")
                SetupStep(number: 2, text: "Wähle Instagram (oder mehrere Apps), **Wird geöffnet**, und **Sofort ausführen**.")
                SetupStep(number: 3, text: "Füge die Aktion **Quiz nötig?** von VocaDay hinzu.")
                SetupStep(number: 4, text: "Füge **Wenn** hinzu: *Ergebnis* **ist** *wahr*.")
                SetupStep(number: 5, text: "Darin: **VocaDay-Quiz öffnen**, „Zurück zu“ = die gleiche App.")
                SetupStep(number: 6, text: "Fertig. Öffnest du Instagram, kommt erst die Vokabel – nach der richtigen Antwort geht es automatisch zurück.")
            } header: {
                Text("Einrichtung (einmalig, 2 Minuten)")
            } footer: {
                Text("Apple erlaubt eine echte Sperre nach Nutzungsdauer (Bildschirmzeit-API) nur mit kostenpflichtigem Entwicklerkonto. Deshalb nutzt VocaDay Kurzbefehle: Das Quiz kommt beim Öffnen der App, sobald die freie Zeit abgelaufen ist.")
            }
        }
        .navigationTitle("Zwangsmodus")
    }
}

private struct SetupStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.coral, in: Circle())
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
