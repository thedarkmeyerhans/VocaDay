import Charts
import SwiftUI
import VocaDayCore

struct StatisticsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showTestSetup = false

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)]

    var body: some View {
        let stats = model.statistics
        ScrollView {
            VStack(spacing: 16) {
                overview(stats)
                LazyVGrid(columns: columns, spacing: 16) {
                    CoverageCard(stats: stats)
                    ActivityCard(days: stats.recentDays, accuracy: stats.accuracy30)
                    HeatmapCard(days: stats.heatmap, activeDays: stats.activeDays)
                    ForecastCard(forecast: stats.forecast)
                    StagesCard(stats: stats)
                    RetentionCard(stats: stats)
                    LettersCard(letters: stats.letters)
                    TestsCard(tests: stats.tests) { showTestSetup = true }
                    FactsCard(stats: stats)
                }
            }
            .padding()
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Statistik")
        .environment(\.locale, Locale(identifier: "de_DE"))
        .sheet(isPresented: $showTestSetup) { TestSetupView() }
    }

    private func overview(_ stats: LearningStatistics) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            OverviewTile(value: "\(stats.learned)", unit: "von \(stats.totalWords)", label: "Wörter gelernt",
                         systemImage: "book.fill", color: Theme.coral)
            OverviewTile(value: "\(stats.stages[.mature] ?? 0)", unit: nil, label: "gefestigt",
                         systemImage: "brain.head.profile", color: Theme.correct)
            OverviewTile(value: "\(stats.currentStreak)", unit: "Rekord \(stats.longestStreak)", label: "Tage in Folge",
                         systemImage: "flame.fill", color: Theme.streak)
            OverviewTile(value: stats.totalSeconds.durationLabel, unit: nil, label: "Lernzeit gesamt",
                         systemImage: "clock.fill", color: Theme.sentence)
        }
    }
}

// MARK: - Cards

private struct StatCard<Content: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(color)
            content()
        }
        .card(padding: 18)
    }
}

private struct OverviewTile: View {
    let value: String
    let unit: String?
    let label: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GradientIcon(systemName: systemImage, color: color, size: 34)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .card(padding: 14)
    }
}

private struct CoverageCard: View {
    let stats: LearningStatistics

    var body: some View {
        StatCard(title: "Textabdeckung", systemImage: "text.magnifyingglass", color: Theme.red) {
            HStack(spacing: 18) {
                ProgressRing(progress: stats.coverage, lineWidth: 14) {
                    Text(stats.coverage.percentLabel)
                        .font(.title3.weight(.bold).monospacedDigit())
                }
                .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("So viel eines typischen deutschen Alltagsgesprächs besteht aus Wörtern, die du schon auf Türkisch kennst.")
                        .font(.subheadline)
                    Text("Mit allen \(stats.totalWords) Wörtern: \(stats.maximumCoverage.percentLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ActivityCard: View {
    let days: [LearningStatistics.Day]
    let accuracy: Double?

    var body: some View {
        StatCard(title: "Aktivität · 30 Tage", systemImage: "chart.bar.fill", color: Theme.review) {
            Chart(days) { day in
                BarMark(x: .value("Tag", day.date, unit: .day),
                        y: .value("Antworten", day.stats.correct))
                    .foregroundStyle(by: .value("Art", "richtig"))
                    .cornerRadius(3)
                BarMark(x: .value("Tag", day.date, unit: .day),
                        y: .value("Antworten", day.stats.reviews - day.stats.correct))
                    .foregroundStyle(by: .value("Art", "falsch"))
                    .cornerRadius(3)
            }
            .chartForegroundStyleScale(["richtig": Theme.correct, "falsch": Theme.wrong.opacity(0.7)])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 170)
            HStack {
                Text("Antworten: \(days.reduce(0) { $0 + $1.stats.reviews })")
                Spacer()
                if let accuracy {
                    Text("Trefferquote: \(accuracy.percentLabel)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct HeatmapCard: View {
    let days: [LearningStatistics.Day]
    let activeDays: Int

    private var weeks: [[LearningStatistics.Day]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private var maxReviews: Int { max(1, days.map(\.stats.reviews).max() ?? 1) }

    var body: some View {
        StatCard(title: "Lernkalender", systemImage: "calendar", color: Theme.coral) {
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(["M", "D", "M", "D", "F", "S", "S"].indices, id: \.self) { index in
                        Text(["M", "D", "M", "D", "F", "S", "S"][index])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: 10, height: 14)
                    }
                }
                ForEach(weeks.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        ForEach(weeks[index]) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: day))
                                .frame(height: 14)
                                .frame(maxWidth: .infinity)
                        }
                        if weeks[index].count < 7 {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("\(activeDays) Lerntage")
                Spacer()
                Text("weniger")
                ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == 0 ? Color(.tertiarySystemFill) : Theme.red.opacity(0.25 + level * 0.75))
                        .frame(width: 10, height: 10)
                }
                Text("mehr")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func color(for day: LearningStatistics.Day) -> Color {
        guard day.stats.reviews > 0 else { return Color(.tertiarySystemFill) }
        let level = Double(day.stats.reviews) / Double(maxReviews)
        return Theme.red.opacity(0.25 + level * 0.75)
    }
}

private struct ForecastCard: View {
    let forecast: [LearningStatistics.Forecast]

    var body: some View {
        StatCard(title: "Wiederholungen · nächste 14 Tage", systemImage: "calendar.badge.clock", color: Theme.sentence) {
            Chart(forecast) { entry in
                BarMark(x: .value("Tag", entry.date, unit: .day),
                        y: .value("Wörter", entry.count))
                    .foregroundStyle(Theme.gradient(Theme.sentence))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if entry.count > 0 {
                            Text("\(entry.count)").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 150)
            Text("So viele Wörter fragt die Wiederholungsplanung an den nächsten Tagen ab. Heute enthält auch überfällige Wörter.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StagesCard: View {
    let stats: LearningStatistics

    var body: some View {
        StatCard(title: "Wortstatus", systemImage: "chart.pie.fill", color: Theme.correct) {
            if stats.learned == 0 {
                Text("Noch keine Wörter gelernt.").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 20) {
                    Chart(LearningStatistics.Stage.allCases, id: \.self) { stage in
                        SectorMark(angle: .value("Wörter", stats.stages[stage] ?? 0),
                                   innerRadius: .ratio(0.62), angularInset: 2)
                            .foregroundStyle(stage.color)
                            .cornerRadius(4)
                    }
                    .chartBackground { _ in
                        VStack(spacing: 0) {
                            Text("\(stats.learned)").font(.title2.bold())
                            Text("Wörter").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 130, height: 130)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(LearningStatistics.Stage.allCases, id: \.self) { stage in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(stage.color).frame(width: 10, height: 10).padding(.top, 4)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(stage.rawValue): \(stats.stages[stage] ?? 0)")
                                        .font(.subheadline.weight(.semibold))
                                    Text(stage.explanation).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RetentionCard: View {
    let stats: LearningStatistics

    var body: some View {
        StatCard(title: "Behaltensquote", systemImage: "target", color: Theme.test) {
            if let retention = stats.retention30, stats.retentionSamples30 >= 5 {
                HStack(alignment: .firstTextBaseline) {
                    Text(retention.percentLabel)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.test)
                    Text("Ziel \(stats.desiredRetention.percentLabel)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule().fill(Theme.gradient(Theme.test))
                            .frame(width: proxy.size.width * retention)
                        Rectangle().fill(Color.primary)
                            .frame(width: 2, height: 18)
                            .offset(x: proxy.size.width * stats.desiredRetention - 1)
                    }
                }
                .frame(height: 12)
                Text(verdict(retention))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Wie viele fällige Wörter du wirklich noch weißt. Das Ziel stellst du in den Einstellungen ein – der FSRS-Algorithmus plant die Abstände so, dass du es triffst.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Pill(text: "Erscheint nach den ersten Wiederholungen", systemImage: "hourglass", color: Theme.test)
            }
        }
    }

    private func verdict(_ retention: Double) -> String {
        let difference = retention - stats.desiredRetention
        if abs(difference) <= 0.05 {
            return "Genau im Ziel: Die Abstände passen zu deinem Gedächtnis. (\(stats.retentionSamples30) fällige Wörter, 30 Tage)"
        }
        if difference > 0 {
            return "Über dem Ziel – du könntest ein niedrigeres Behaltensziel wählen und sparst Wiederholungen."
        }
        return "Unter dem Ziel – wiederhole möglichst täglich, dann kommen die Wörter rechtzeitig dran."
    }
}

private struct LettersCard: View {
    let letters: [LearningStatistics.LetterProgress]

    var body: some View {
        StatCard(title: "Fortschritt A–Z", systemImage: "textformat.abc", color: Theme.coral) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 10) {
                ForEach(letters) { letter in
                    VStack(spacing: 4) {
                        ProgressRing(progress: letter.fraction, lineWidth: 4) {
                            Text(letter.letter).font(.subheadline.bold())
                        }
                        .frame(width: 40, height: 40)
                        Text("\(letter.learned)/\(letter.total)")
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct TestsCard: View {
    let tests: [TestResult]
    let onStart: () -> Void

    var body: some View {
        StatCard(title: "Wortschatz-Tests", systemImage: "checklist", color: Theme.test) {
            if tests.isEmpty {
                Text("Prüfe alle gelernten Wörter auf einmal und verfolge hier deine Ergebnisse.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(Array(tests.suffix(12).enumerated()), id: \.element.id) { index, result in
                    LineMark(x: .value("Test", index + 1), y: .value("Ergebnis", result.score * 100))
                        .foregroundStyle(Theme.test)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Test", index + 1), y: .value("Ergebnis", result.score * 100))
                        .foregroundStyle(Theme.test)
                    AreaMark(x: .value("Test", index + 1), y: .value("Ergebnis", result.score * 100))
                        .foregroundStyle(LinearGradient(colors: [Theme.test.opacity(0.3), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 120)
                if let last = tests.last {
                    TestResultRow(result: last)
                }
            }
            Button(action: onStart) {
                Label("Test starten", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.test))
        }
    }
}

private struct FactsCard: View {
    let stats: LearningStatistics

    var body: some View {
        StatCard(title: "Kennzahlen", systemImage: "list.bullet.rectangle", color: .secondary) {
            VStack(spacing: 10) {
                fact("Lerntage gesamt", "\(stats.activeDays)")
                fact("Antworten gesamt", "\(stats.totalReviews)")
                fact("Trefferquote (30 Tage)", stats.accuracy30?.percentLabel ?? "–")
                fact("Ø Gedächtnis-Stabilität", String(format: "%.1f Tage", stats.averageStability))
                fact("Schon geplante Wörter", "\(stats.plannedAhead)")
                fact("Tests absolviert", "\(stats.tests.count)")
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.subheadline)
    }
}
