import SwiftUI
import VocaDayCore

// MARK: - Setup

struct TestSetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private enum ScopeChoice: String, CaseIterable, Identifiable {
        case all, weakest, random, recent
        var id: String { rawValue }

        var scope: TestScope {
            switch self {
            case .all: return .all
            case .weakest: return .weakest(20)
            case .random: return .random(20)
            case .recent: return .recent(days: 7)
            }
        }

        var icon: String {
            switch self {
            case .all: return "square.stack.3d.up.fill"
            case .weakest: return "exclamationmark.triangle.fill"
            case .random: return "shuffle"
            case .recent: return "calendar"
            }
        }
    }

    @State private var scopeChoice: ScopeChoice = .all
    @State private var direction: TestDirection = .mixed
    @State private var answerMode: TestAnswerMode = .choice
    @State private var activeTest: ActiveTest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    optionGroup("Welche Wörter?") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ScopeChoice.allCases) { choice in
                                OptionChip(title: choice.scope.displayName,
                                           detail: "\(model.testWordCount(for: choice.scope)) Wörter",
                                           systemImage: choice.icon, isSelected: scopeChoice == choice) {
                                    scopeChoice = choice
                                }
                            }
                        }
                    }
                    optionGroup("Richtung") {
                        HStack(spacing: 10) {
                            ForEach(TestDirection.allCases, id: \.self) { value in
                                OptionChip(title: value.displayName, detail: nil, systemImage: nil,
                                           isSelected: direction == value) { direction = value }
                            }
                        }
                    }
                    optionGroup("Antworten") {
                        HStack(spacing: 10) {
                            OptionChip(title: TestAnswerMode.choice.displayName, detail: "erkennen",
                                       systemImage: "list.bullet", isSelected: answerMode == .choice) {
                                answerMode = .choice
                            }
                            OptionChip(title: TestAnswerMode.typing.displayName, detail: "selbst abrufen",
                                       systemImage: "keyboard", isSelected: answerMode == .typing) {
                                answerMode = .typing
                            }
                        }
                    }
                    if !model.progress.tests.isEmpty {
                        recentResults
                    }
                }
                .padding()
                .readableWidth()
            }
            .safeAreaInset(edge: .bottom) {
                let count = model.testWordCount(for: scopeChoice.scope)
                Button {
                    activeTest = model.makeTest(scope: scopeChoice.scope, direction: direction, answerMode: answerMode)
                } label: {
                    Label(count == 0 ? "Keine Wörter in dieser Auswahl" : "Test starten · \(count) Wörter",
                          systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.test))
                .disabled(count == 0)
                .padding()
                .readableWidth()
                .background(.bar)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wortschatz-Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $activeTest) { active in
            TestRunView(active: active)
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 16) {
            GradientIcon(systemName: "checklist", color: Theme.test, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("Wie gut sitzt dein Wortschatz?").font(.title3.bold())
                Text("Jedes Wort wird einmal abgefragt – gewertet zählt nur der erste Versuch. Falsche Wörter kommen danach in einer Fehlerrunde wieder, bis du sie kannst. Deine Antworten fließen in die Wiederholungsplanung ein.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 18)
    }

    private func optionGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private var recentResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Letzte Ergebnisse").font(.headline)
            ForEach(model.progress.tests.suffix(3).reversed()) { result in
                TestResultRow(result: result)
            }
        }
    }
}

private struct OptionChip: View {
    let title: String
    let detail: String?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8)
                }
                if let detail {
                    Text(detail).font(.caption).opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AnyShapeStyle(Theme.gradient(Theme.test))
                                   : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.clear : Color(.separator).opacity(0.4)))
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

struct TestResultRow: View {
    let result: TestResult

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(progress: result.score, lineWidth: 5, colors: [Theme.test, Theme.correct]) {
                Text("\(Int((result.score * 100).rounded()))")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(TestResult.grade(for: result.score)).font(.subheadline.weight(.semibold))
                Text("\(result.correctFirstTry) von \(result.total) · \(result.scope.displayName) · \(result.seconds.durationLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(result.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE"))))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card(padding: 12)
    }
}

// MARK: - Running test

struct TestRunView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var test: VocabularyTest
    @State private var context: ExerciseContext?
    @State private var round = 0
    @State private var saved = false

    init(active: ActiveTest) {
        _test = State(initialValue: active.test)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !test.isFinished {
                    header
                }
                content
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(test.scope.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Test beenden")
                }
            }
        }
        .onAppear(perform: loadContext)
    }

    private var header: some View {
        VStack(spacing: 8) {
            SessionProgressBar(progress: test.fractionDone)
            HStack {
                if test.isInMistakesRound {
                    Pill(text: "Fehlerrunde", systemImage: "arrow.uturn.backward", color: Theme.almost)
                } else {
                    Text("Frage \(min(test.position + 1, test.wordCount)) von \(test.wordCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(test.correctFirstTry)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.correct)
                Label("\(test.answeredFirstTry - test.correctFirstTry)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Theme.wrong)
            }
            .font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if test.isFinished {
            TestSummaryView(test: test, words: model.words, onPracticeMistakes: practiceMistakes, onClose: close)
        } else if let context {
            ScrollView {
                ExerciseView(context: context, card: model.card(for: context.word), scheduler: model.scheduler,
                             onComplete: complete)
                    .padding()
                    .readableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .id("\(round)-\(context.item.id)")
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
    }

    private func complete(_ rating: Rating?) {
        guard let item = test.current else { return }
        let answer = rating ?? .good
        if test.currentIsFirstAttempt {
            let capped = Rating(rawValue: min(answer.rawValue, item.kind.ratingCap.rawValue)) ?? answer
            model.record(wordID: item.wordID, rating: capped)
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            test.record(correct: answer != .again)
            loadContext()
        }
        if test.isFinished && !saved {
            model.finishTest(test)
            saved = true
        }
    }

    private func loadContext() {
        while let item = test.current {
            if let next = ExerciseContext.make(for: item, words: model.words) {
                context = next
                return
            }
            test.record(correct: true)
        }
        context = nil
    }

    private func practiceMistakes() {
        let mistakes = test.mistakes
        let next = model.makeTest(scope: .words(mistakes), direction: test.direction, answerMode: test.answerMode)
        withAnimation {
            round += 1
            saved = false
            test = next.test
            loadContext()
        }
    }

    private func close() {
        if !saved && test.answeredFirstTry > 0 {
            model.addStudyTime(Date().timeIntervalSince(test.startedAt))
        }
        model.sessionFinished(studyTime: 0)
        dismiss()
    }
}

// MARK: - Summary

private struct TestSummaryView: View {
    let test: VocabularyTest
    let words: WordIndex
    let onPracticeMistakes: () -> Void
    let onClose: () -> Void

    @State private var duration: TimeInterval = 0

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 22) {
                    ProgressRing(progress: test.score, lineWidth: 18, colors: [Theme.test, Theme.correct]) {
                        VStack(spacing: 2) {
                            Text(test.score.percentLabel)
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                            Text("beim 1. Versuch").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 190, height: 190)
                    .padding(.top, 20)

                    VStack(spacing: 4) {
                        Text(TestResult.grade(for: test.score)).font(.largeTitle.bold())
                        Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        SummaryTile(value: "\(test.correctFirstTry)/\(test.wordCount)", label: "gewusst",
                                    systemImage: "checkmark.circle", color: Theme.correct)
                        SummaryTile(value: "\(test.mistakes.count)", label: "Fehler",
                                    systemImage: "xmark.circle", color: Theme.wrong)
                        SummaryTile(value: duration.durationLabel, label: "Dauer",
                                    systemImage: "clock", color: Theme.sentence)
                    }

                    if !test.mistakes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Diese Wörter üben wir weiter").font(.headline)
                            ForEach(test.mistakes, id: \.self) { id in
                                if let word = words[id] {
                                    HStack {
                                        Text(word.translation).font(.body.weight(.semibold))
                                        Spacer()
                                        ArticleWord(word: word, font: .body).foregroundStyle(.secondary)
                                        SpeakButton(text: word.translation)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .card()
                    }

                    VStack(spacing: 10) {
                        if !test.mistakes.isEmpty {
                            Button(action: onPracticeMistakes) {
                                Label("Fehler noch einmal testen (\(test.mistakes.count))",
                                      systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.test))
                        }
                        Button("Fertig", action: onClose)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding()
                .readableWidth()
            }
            if test.score >= 0.8 {
                ConfettiView()
            }
        }
        .onAppear {
            duration = Date().timeIntervalSince(test.startedAt)
            haptic(test.score >= 0.6)
        }
    }

    private var message: String {
        switch test.score {
        case 0.9...: return "Dein Wortschatz sitzt richtig gut."
        case 0.75..<0.9: return "Fast alles gewusst – stark!"
        case 0.6..<0.75: return "Solide Basis. Die Fehler kommen bald wieder dran."
        default: return "Kein Problem – genau dafür ist der Test da. Die Wörter werden jetzt öfter wiederholt."
        }
    }
}
