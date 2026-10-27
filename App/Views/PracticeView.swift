import SwiftUI
import VocaDayCore

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSession: ActiveSession?
    @State private var mastery: ActiveMastery?
    @State private var showTestSetup = false

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LearningRoadmap()
                SectionTitle(title: "Wörter üben", subtitle: "Erst die Grundform sicher abrufen")
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
                                 title: "Festigen – bis es sitzt",
                                 text: "Deine 10 schwächsten Wörter. Jedes kommt so lange wieder, bis du es zweimal hintereinander weißt.",
                                 badge: nil, isEnabled: model.learnedCount > 0) {
                        mastery = model.makeConsolidation()
                    }
                }
                SectionTitle(title: "Grammatik",
                             subtitle: "Danach: Endungen und Konjugation – Schritt für Schritt bis es sitzt")
                GrammarPathView()
                    .card(padding: 18)
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
        .fullScreenCover(item: $mastery) { MasteryPracticeView(active: $0) }
        .sheet(isPresented: $showTestSetup) {
            TestSetupView()
        }
    }
}

/// Phase 1 words → phase 2 grammar, with progress.
private struct LearningRoadmap: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let stages = max(1, model.grammar.stages.count)
        HStack(spacing: 12) {
            phase(number: 1, title: "Wörter", detail: "\(model.learnedCount) gelernt · Grundform",
                  progress: min(1, Double(model.learnedCount) / 50), color: Theme.coral, active: true)
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            phase(number: 2, title: "Grammatik", detail: "\(model.completedStages)/\(stages) Stufen",
                  progress: Double(model.completedStages) / Double(stages), color: Theme.sentence,
                  active: model.learnedCount >= 5)
        }
        .card(padding: 16)
    }

    private func phase(number: Int, title: String, detail: String, progress: Double, color: Color,
                       active: Bool) -> some View {
        HStack(spacing: 10) {
            ProgressRing(progress: progress, lineWidth: 6, colors: [color.opacity(0.7), color]) {
                Text("\(number)").font(.headline).foregroundStyle(color)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .opacity(active ? 1 : 0.5)
        .frame(maxWidth: .infinity)
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
