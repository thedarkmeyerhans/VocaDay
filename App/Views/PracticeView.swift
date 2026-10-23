import SwiftUI
import VocaDayCore

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSession: ActiveSession?
    @State private var showTestSetup = false

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: columns, spacing: 14) {
                    PracticeCard(icon: "arrow.triangle.2.circlepath", color: Theme.review,
                                 title: "Tägliche Wiederholung",
                                 text: model.dueCount > 0
                                    ? "\(model.dueCount) Wörter sind jetzt dran."
                                    : "Gerade ist nichts fällig – gut gemacht!",
                                 badge: model.dueCount > 0 ? "\(model.dueCount)" : nil,
                                 isEnabled: model.hasWorkToday) {
                        activeSession = model.makeDailySession()
                    }
                    PracticeCard(icon: "checklist", color: Theme.test,
                                 title: "Wortschatz-Test",
                                 text: "Alle gelernten Wörter auf einmal abfragen – mit Auswertung und Fehlerrunde.",
                                 badge: model.lastTest.map { $0.score.percentLabel },
                                 isEnabled: model.learnedCount > 0) {
                        showTestSetup = true
                    }
                    PracticeCard(icon: "text.bubble.fill", color: Theme.sentence,
                                 title: "Satztrainer",
                                 text: "Wörter aktiv im Satz verwenden: Lückentexte und Sätze bauen.",
                                 badge: nil, isEnabled: model.learnedCount > 0) {
                        activeSession = model.makeSentenceSession()
                    }
                    PracticeCard(icon: "dumbbell.fill", color: Theme.practice,
                                 title: "Freies Üben",
                                 text: "Die Wörter, die du am ehesten vergisst – auch wenn sie noch nicht fällig sind.",
                                 badge: nil, isEnabled: model.learnedCount > 0) {
                        activeSession = model.makeFreePracticeSession()
                    }
                }
                NavigationLink {
                    LearningMethodView()
                } label: {
                    HStack(spacing: 14) {
                        GradientIcon(systemName: "graduationcap.fill", color: Theme.coral, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("So lernst du mit VocaDay").font(.headline).foregroundStyle(.primary)
                            Text("Die Wissenschaft hinter den Übungen").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .card()
                }
                .buttonStyle(PressableStyle())
                if model.learnedCount == 0 {
                    Label("Lerne zuerst dein Wort des Tages im Tab „Heute“.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Üben")
        .fullScreenCover(item: $activeSession) { active in
            SessionView(active: active)
        }
        .sheet(isPresented: $showTestSetup) {
            TestSetupView()
        }
    }
}

private struct PracticeCard: View {
    let icon: String
    let color: Color
    let title: String
    let text: String
    let badge: String?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    GradientIcon(systemName: icon, color: color, size: 52)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.15), in: Capsule())
                            .foregroundStyle(color)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold()).foregroundStyle(.primary)
                    Text(text).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(color)
                }
            }
            .card(padding: 18)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

struct LearningMethodView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MethodSection(icon: "chart.bar", title: "Häufige Wörter zuerst",
                              text: "Die Wörter stammen aus einer Häufigkeitsanalyse deutscher Untertitel. Die 1.000 häufigsten Wörter decken einen Großteil der Alltagssprache ab – du lernst also zuerst, was du am meisten brauchst.")
                MethodSection(icon: "textformat.abc", title: "Reihum von A bis Z",
                              text: "Im Standard-Modus kommt jeden Tag ein zufälliges Wort aus den häufigsten Wörtern des nächsten Buchstabens. So entsteht Abwechslung, und ähnliche Wörter landen nicht am selben Tag.")
                MethodSection(icon: "clock.arrow.circlepath", title: "Verteilte Wiederholung (FSRS)",
                              text: "Wir vergessen nach einer Vergessenskurve (Ebbinghaus). VocaDay berechnet mit dem FSRS-Algorithmus für jedes Wort, wann du es mit 90 % Wahrscheinlichkeit noch weißt, und fragt es genau dann ab. Jede erfolgreiche Wiederholung verlängert den Abstand – von Minuten über Tage bis zu Monaten.")
                MethodSection(icon: "questionmark.bubble", title: "Abrufen statt Lesen",
                              text: "Aktives Erinnern (Testing-Effekt) verankert Wörter deutlich stärker als wiederholtes Lesen. Darum fragt VocaDay ab, statt nur zu zeigen – und deine Antworten steuern die nächsten Abstände.")
                MethodSection(icon: "stairs", title: "Wachsende Schwierigkeit",
                              text: "Neue Wörter erkennst du zuerst unter Auswahlmöglichkeiten. Je sicherer ein Wort sitzt, desto mehr musst du selbst produzieren: Wort tippen, Lücke im Satz füllen, ganzen Satz bauen („wünschenswerte Erschwernis“).")
                MethodSection(icon: "text.bubble", title: "Lernen im Kontext",
                              text: "Jedes Wort kommt mit einem Beispielsatz. Der Satztrainer übt die Wörter mit Endungen und Satzstellung – so, wie du sie wirklich verwendest.")
                MethodSection(icon: "checklist", title: "Wortschatz-Test",
                              text: "Der Test fragt viele Wörter auf einmal ab. Nur der erste Versuch zählt – so misst er ehrlich, was du kannst. Falsche Wörter wiederholst du sofort in einer Fehlerrunde (Mastery Learning), und alle Antworten fließen in die FSRS-Planung ein.")
                MethodSection(icon: "shuffle", title: "Mischen und Aussprechen",
                              text: "Neue und alte Wörter werden gemischt (Interleaving), und jedes Wort kannst du dir vorlesen lassen. Laut Nachsprechen verknüpft Klang und Bedeutung (Produktionseffekt).")
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("So lernst du")
    }
}

private struct MethodSection: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GradientIcon(systemName: icon, color: Theme.coral, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
