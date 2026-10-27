import Charts
import SwiftUI
import VocaDayCore

/// Small horizontal bar of the current recall probability.
struct RecallBar: View {
    let value: Double

    private var color: Color {
        switch value {
        case 0.9...: return Theme.correct
        case 0.75..<0.9: return Theme.almost
        default: return Theme.wrong
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(color).frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Erinnerung \(value.percentLabel)")
    }
}

struct WordDetailView: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeroWordCard(word: word, isLearned: model.progress.isIntroduced(word.id))

                if !word.alternatives.isEmpty || word.note != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if !word.alternatives.isEmpty {
                            Label("auch: \(word.alternatives.joined(separator: ", "))", systemImage: "equal.circle")
                        }
                        if let note = word.note {
                            Label(note, systemImage: "lightbulb.fill")
                                .symbolRenderingMode(.multicolor)
                        }
                    }
                    .font(.subheadline)
                    .card()
                }

                HStack(spacing: 12) {
                    Button {
                        Speaker.shared.speak(word.cloze.plain, language: .turkish)
                    } label: {
                        Label("Satz anhören", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button {
                        Speaker.shared.speak(word.cloze.plain, language: .turkish, slow: true)
                    } label: {
                        Label("Langsam", systemImage: "tortoise.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.sentence))
                }

                if let card = model.card(for: word) {
                    memoryCard(card)
                    ForgettingCurveCard(card: card, scheduler: model.scheduler)
                } else {
                    LearnNowCard(word: word)
                }

                Text("\(word.partOfSpeech.displayName) · Platz \(word.rank) der häufigsten deutschen Wörter")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(word.translation)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func memoryCard(_ card: CardState) -> some View {
        let recall = model.scheduler.retrievability(of: card, at: Date())
        let status = model.status(of: word)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ProgressRing(progress: recall, lineWidth: 10, colors: [Theme.test, Theme.correct]) {
                    Text(recall.percentLabel).font(.subheadline.weight(.bold).monospacedDigit())
                }
                .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Erinnerung gerade").font(.headline)
                    Pill(text: status.rawValue, color: status.color)
                    Text("Nächste Wiederholung \(card.due.relativeDescription())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                metric("Stabilität", String(format: "%.1f T", card.stability))
                metric("Schwierigkeit", String(format: "%.1f", card.difficulty))
                metric("Abfragen", "\(card.reps)")
                metric("Vergessen", "\(card.lapses)×")
            }
        }
        .card(padding: 18)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// For words not learned yet: when they are planned, and "Heute lernen".
private struct LearnNowCard: View {
    @EnvironmentObject private var model: AppModel
    let word: Word
    @State private var session: ActiveSession?

    var body: some View {
        let planned = model.plannedDay(for: word)
        let isToday = planned.map { $0 <= model.today } ?? false
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                GradientIcon(systemName: isToday ? "star.fill" : "calendar",
                             color: isToday ? Theme.coral : Color(.systemGray), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? "Steht heute auf deinem Plan"
                         : planned.map { "Geplant für \(model.dayLabel($0))" } ?? "Noch nicht dran")
                        .font(.headline)
                    Text(isToday ? "Lerne es jetzt – danach wiederholt VocaDay es automatisch."
                         : planned != nil ? "Es kommt automatisch an die Reihe."
                         : "Platz \(word.rank) der Häufigkeitsliste – es kommt dran, wenn sein Buchstabe wieder an der Reihe ist.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if isToday {
                Button {
                    session = model.makeDailySession()
                } label: {
                    Label("Jetzt lernen", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    withAnimation { _ = model.learnNow(word) }
                    haptic(true)
                } label: {
                    Label("Heute lernen", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card(padding: 18)
        .fullScreenCover(item: $session) { SessionView(active: $0) }
    }
}

/// Predicted recall over the coming days (FSRS forgetting curve).
private struct ForgettingCurveCard: View {
    let card: CardState
    let scheduler: FSRSScheduler

    private struct Point: Identifiable {
        let id: Int
        let day: Double
        let recall: Double
    }

    private var horizon: Double { max(7, min(120, (card.due.timeIntervalSince(card.lastReview) / 86_400) * 2)) }

    private var points: [Point] {
        (0...40).map { step in
            let day = horizon * Double(step) / 40
            return Point(id: step, day: day,
                         recall: scheduler.retrievability(elapsedDays: day, stability: card.stability) * 100)
        }
    }

    private var dueDay: Double { card.due.timeIntervalSince(card.lastReview) / 86_400 }
    private var today: Double { Date().timeIntervalSince(card.lastReview) / 86_400 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Vergessenskurve", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)
                .foregroundStyle(Theme.sentence)
            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Tage", point.day), y: .value("Erinnerung", point.recall))
                        .foregroundStyle(LinearGradient(colors: [Theme.sentence.opacity(0.35), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Tage", point.day), y: .value("Erinnerung", point.recall))
                        .foregroundStyle(Theme.sentence)
                        .interpolationMethod(.catmullRom)
                }
                RuleMark(y: .value("Ziel", scheduler.desiredRetention * 100))
                    .foregroundStyle(Theme.test)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Ziel \(scheduler.desiredRetention.percentLabel)")
                            .font(.caption2).foregroundStyle(Theme.test)
                    }
                if dueDay <= horizon {
                    RuleMark(x: .value("Fällig", dueDay))
                        .foregroundStyle(Theme.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .annotation(position: .top) {
                            Text("Wiederholung").font(.caption2).foregroundStyle(Theme.red)
                        }
                }
                if today <= horizon {
                    PointMark(x: .value("Heute", today),
                              y: .value("Erinnerung", scheduler.retrievability(elapsedDays: today, stability: card.stability) * 100))
                        .foregroundStyle(Theme.coral)
                        .symbolSize(80)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxisLabel("Tage seit der letzten Abfrage")
            .frame(height: 180)
            Text("Ohne Wiederholung sinkt die Erinnerung. VocaDay fragt das Wort ab, kurz bevor sie unter dein Ziel fällt – jede richtige Antwort macht die Kurve flacher.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card(padding: 18)
    }
}
