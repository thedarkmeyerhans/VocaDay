import SwiftUI
import VocaDayCore

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSession: ActiveSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PracticeCard(icon: "arrow.triangle.2.circlepath", color: .blue,
                             title: "Tägliche Wiederholung",
                             text: model.dueCount > 0
                                ? "\(model.dueCount) Wörter sind jetzt dran."
                                : "Gerade ist nichts fällig – gut gemacht!",
                             isEnabled: model.hasWorkToday) {
                    activeSession = model.makeDailySession()
                }
                PracticeCard(icon: "text.bubble", color: .purple,
                             title: "Satztrainer",
                             text: "Wörter aktiv im Satz verwenden: Lückentexte und Sätze bauen.",
                             isEnabled: model.learnedCount > 0) {
                    activeSession = model.makeSentenceSession()
                }
                PracticeCard(icon: "dumbbell", color: .orange,
                             title: "Freies Üben",
                             text: "Die Wörter, die du am ehesten vergisst – auch wenn sie noch nicht fällig sind.",
                             isEnabled: model.learnedCount > 0) {
                    activeSession = model.makeFreePracticeSession()
                }
                NavigationLink {
                    LearningMethodView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "graduationcap")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("So lernst du mit VocaDay").font(.headline)
                            Text("Die Wissenschaft hinter den Übungen").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
                if model.learnedCount == 0 {
                    Text("Lerne zuerst dein Wort des Tages im Tab „Heute“.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Üben")
        .fullScreenCover(item: $activeSession) { active in
            SessionView(active: active)
        }
    }
}

private struct PracticeCard: View {
    let icon: String
    let color: Color
    let title: String
    let text: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(text).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "play.fill").foregroundStyle(color)
            }
            .card()
        }
        .buttonStyle(.plain)
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
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
