import SwiftUI
import VocaDayCore

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var settings = LearnerSettings()
    @State private var notificationTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? .now

    private let lastStep = 3

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step), total: Double(lastStep))
                .padding()
            ScrollView {
                Group {
                    switch step {
                    case 0: welcome
                    case 1: languages
                    case 2: pace
                    default: reminders
                    }
                }
                .padding(24)
                .readableWidth()
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
                    .combined(with: .opacity))
            }
            footer
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut, value: step)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.sun)
                    .shadow(color: Theme.sun.opacity(0.7), radius: 16)
                Text("Willkommen bei VocaDay")
                    .font(.largeTitle.bold())
                Text("Jeden Tag mindestens ein neues Wort – ausgewählt aus den häufigsten Wörtern, reihum von A bis Z.")
                    .font(.title3)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sunrise, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.red.opacity(0.3), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "bell.badge.fill", color: Theme.coral, title: "Wort des Tages",
                           text: "Morgens direkt in der Mitteilung, abends eine kurze Erinnerung.")
                FeatureRow(icon: "brain.head.profile", color: Theme.review, title: "Wissenschaftlich wiederholen",
                           text: "Der FSRS-Algorithmus fragt jedes Wort ab, kurz bevor du es vergessen würdest.")
                FeatureRow(icon: "text.bubble.fill", color: Theme.sentence, title: "Aktiv in Sätzen",
                           text: "Lückentexte und Satzbau trainieren die Wörter im Zusammenhang.")
                FeatureRow(icon: "checklist", color: Theme.test, title: "Wortschatz-Test & Statistik",
                           text: "Prüfe alles Gelernte auf einmal und sieh, wie dein Wortschatz wächst.")
            }
        }
    }

    private var languages: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welche Sprachen?")
                .font(.largeTitle.bold())
            Text("Deine Muttersprache")
                .font(.headline)
            LanguageChoice(language: .german, isSelected: settings.pair.native == .german)
            Text("Diese Sprache möchtest du lernen")
                .font(.headline)
            ForEach(LanguagePair.available.filter { $0.native == settings.pair.native }, id: \.self) { pair in
                Button {
                    settings.pair = pair
                } label: {
                    LanguageChoice(language: pair.target, isSelected: settings.pair == pair)
                }
                .buttonStyle(.plain)
            }
            Text("Weitere Sprachen folgen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var pace: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Dein Tempo")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 8) {
                Text("Modus").font(.headline)
                Picker("Modus", selection: $settings.mode) {
                    ForEach(SelectionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(settings.mode.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .card()
            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $settings.newWordsPerDay, in: LearnerSettings.newWordsRange) {
                    Text("Neue Wörter pro Tag: **\(settings.newWordsPerDay)**")
                }
                Text("Das sind \(settings.newWordsPerDay * 7) Wörter pro Woche. Du kannst das jederzeit ändern und zusätzlich jederzeit „Noch ein Wort“ antippen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .card()
            Toggle(isOn: $settings.mixSentenceExercises) {
                VStack(alignment: .leading) {
                    Text("Satzübungen einmischen")
                    Text("Wörter auch in Lückentexten und beim Satzbau wiederholen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .card()
        }
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Erinnerungen")
                .font(.largeTitle.bold())
            Text("VocaDay schickt dir jeden Morgen dein neues Wort – direkt in der Mitteilung.")
                .font(.title3)
            VStack(spacing: 12) {
                Toggle("Wort des Tages", isOn: $settings.notificationsEnabled)
                if settings.notificationsEnabled {
                    DatePicker("Uhrzeit", selection: $notificationTime, displayedComponents: .hourAndMinute)
                }
                Divider()
                Toggle("Erinnerung am Abend", isOn: $settings.eveningReminderEnabled)
                if settings.eveningReminderEnabled {
                    Picker("Abends um", selection: $settings.eveningReminderHour) {
                        ForEach(16...22, id: \.self) { hour in
                            Text("\(hour):00 Uhr").tag(hour)
                        }
                    }
                }
            }
            .card()
            Text("Die Abend-Erinnerung kommt nur, wenn an dem Tag noch etwas offen ist.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Zurück") { step -= 1 }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button(step == lastStep ? "Los geht's" : "Weiter") {
                if step == lastStep {
                    finish()
                } else {
                    step += 1
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .readableWidth()
    }

    private func finish() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        settings.notificationHour = components.hour ?? 8
        settings.notificationMinute = components.minute ?? 0
        let chosen = settings
        Task {
            if chosen.notificationsEnabled || chosen.eveningReminderEnabled {
                _ = await model.notifications.requestAuthorization()
            }
            model.completeOnboarding(with: chosen)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GradientIcon(systemName: icon, color: color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct LanguageChoice: View {
    let language: Language
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(language.flag).font(.largeTitle)
            Text(language.displayName).font(.title3.weight(.semibold))
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}
