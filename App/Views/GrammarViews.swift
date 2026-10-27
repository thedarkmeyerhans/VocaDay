import SwiftUI
import VocaDayCore

// MARK: - Path

/// The grammar path: pronouns → verb endings → tenses, one stage after the other.
struct GrammarPathView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.grammar.stages.enumerated()), id: \.element.id) { index, stage in
                let state = model.state(of: stage)
                NavigationLink {
                    GrammarStageView(stage: stage)
                } label: {
                    StageRow(stage: stage, state: state, isLast: index == model.grammar.stages.count - 1)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

private struct StageRow: View {
    let stage: GrammarStage
    let state: StageState
    let isLast: Bool

    private var color: Color {
        switch state {
        case .completed: return Theme.correct
        case .open: return Theme.sentence
        case .locked: return Color(.systemGray3)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(state == .open ? AnyShapeStyle(Theme.gradient(Theme.sentence)) : AnyShapeStyle(color))
                        .frame(width: 46, height: 46)
                        .shadow(color: state == .open ? Theme.sentence.opacity(0.4) : .clear, radius: 8, y: 3)
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(state == .completed ? Theme.correct.opacity(0.5) : Color(.systemGray5))
                        .frame(width: 4, height: 34)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(stage.title).font(.headline).foregroundStyle(.primary)
                Text(stage.subtitle).font(.subheadline).foregroundStyle(.secondary)
                switch state {
                case .completed: Label("geschafft – jederzeit wiederholen", systemImage: "checkmark")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.correct)
                case .open: Label("bereit", systemImage: "play.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.sentence)
                case .locked(let reason): Text(reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary).padding(.top, 14)
        }
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch state {
        case .completed: return "checkmark"
        case .locked: return "lock.fill"
        case .open: return stage.icon
        }
    }
}

// MARK: - Stage

struct GrammarStageView: View {
    @EnvironmentObject private var model: AppModel
    let stage: GrammarStage
    @State private var practice: ActiveMastery?

    var body: some View {
        let state = model.state(of: stage)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    GradientIcon(systemName: stage.icon, color: Theme.sentence, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.title).font(.title2.bold())
                        Text(stage.subtitle).foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(stage.lesson.enumerated()), id: \.offset) { _, lesson in
                    LessonCard(lesson: lesson)
                }
                if stage.kind == .conjugation, let tense = stage.tense {
                    OwnVerbsPreview(tense: tense)
                }
                switch state {
                case .locked(let reason):
                    Label(reason, systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                        .card()
                case .open, .completed:
                    Button {
                        practice = model.makeGrammarPractice(stage)
                    } label: {
                        Label(state == .completed ? "Nochmal üben" : "Übung starten", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.sentence))
                    Text("Jede Aufgabe kommt so lange wieder, bis du sie zweimal hintereinander richtig hast.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stage.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $practice) { MasteryPracticeView(active: $0) }
    }
}

private struct LessonCard: View {
    let lesson: GrammarStage.Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lesson.title).font(.headline)
            Text(lesson.text).foregroundStyle(.secondary)
            if let table = lesson.table {
                SimpleTable(header: lesson.header, rows: table)
            }
            if let conjugation = lesson.conjugation {
                ConjugationTable(verbs: conjugation.verbs.compactMap { TurkishVerb($0) }, tense: conjugation.tense)
            }
        }
        .card(padding: 18)
    }
}

struct SimpleTable: View {
    let header: [String]?
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            if let header {
                GridRow {
                    ForEach(header, id: \.self) { Text($0).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                }
                Divider()
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                        Text(cell)
                            .font(index == row.count - 1 ? .body.weight(.semibold) : .body)
                            .foregroundStyle(index == row.count - 1 ? Theme.red : Color.primary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Person × verb table of one tense, with the endings highlighted.
struct ConjugationTable: View {
    let verbs: [TurkishVerb]
    let tense: Tense

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("").gridCellUnsizedAxes(.horizontal)
                ForEach(verbs, id: \.self) { Text($0.dictionaryForm).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            }
            Divider()
            ForEach(Person.allCases) { person in
                GridRow {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(person.turkish).font(.subheadline.weight(.semibold))
                        Text(person.german).font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(verbs, id: \.self) { verb in
                        highlighted(verb, person)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Stem in normal weight, everything after it in the accent colour.
    private func highlighted(_ verb: TurkishVerb, _ person: Person) -> some View {
        let parts = verb.breakdown(tense, person).components(separatedBy: " + ")
        let stem = verb.prefix + (parts.first ?? "")
        let ending = Text(parts.dropFirst().joined()).bold().foregroundStyle(Theme.red)
        return Text("\(stem)\(ending)").font(.body)
    }
}

private struct OwnVerbsPreview: View {
    @EnvironmentObject private var model: AppModel
    let tense: Tense

    var body: some View {
        let verbs = GrammarBuilder.learnedVerbs(progress: model.progress, words: model.words).prefix(3).map(\.1)
        if !verbs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Deine Verben").font(.headline)
                ConjugationTable(verbs: Array(verbs), tense: tense)
            }
            .card(padding: 18)
        }
    }
}

// MARK: - Mastery practice

struct MasteryPracticeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let active: ActiveMastery
    @State private var session: MasterySession
    @State private var startedAt = Date()
    @State private var round = 0
    @State private var finishedRecorded = false
    @State private var showIntro: Bool

    init(active: ActiveMastery) {
        self.active = active
        _session = State(initialValue: active.session)
        _showIntro = State(initialValue: active.introWordID != nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !showIntro && !session.isFinished && !session.isEmpty {
                    VStack(spacing: 6) {
                        SessionProgressBar(progress: session.progress)
                        HStack {
                            Text("\(session.masteredCount) von \(session.items.count) gemeistert")
                            Spacer()
                            Text(session.currentStreak == 0 ? "1. Runde" : "noch \(session.target - session.currentStreak)× richtig")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                content
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(active.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Schließen")
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if showIntro, let id = active.introWordID, let word = model.words[id] {
            ScrollView {
                IntroductionView(word: word) {
                    withAnimation(.easeInOut(duration: 0.3)) { showIntro = false }
                }
                .padding()
                .readableWidth()
            }
        } else if session.isEmpty {
            ContentUnavailableView("Noch nichts zu üben", systemImage: "text.book.closed",
                                   description: Text("Lerne zuerst ein paar Wörter."))
        } else if session.isFinished {
            MasterySummary(session: session, seconds: Date().timeIntervalSince(startedAt), onClose: close)
                .onAppear(perform: recordFinish)
        } else if let item = session.current {
            ScrollView {
                MasteryItemView(item: item, useChoices: session.currentStreak == 0 && !item.choices.isEmpty) { correct in
                    model.recordMastery(item: item, correct: correct, firstAttempt: session.isFirstAttempt)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        session.answer(correct: correct)
                        round += 1
                    }
                }
                .padding()
                .readableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .id(round)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
    }

    private func recordFinish() {
        guard !finishedRecorded else { return }
        finishedRecorded = true
        model.finishMastery(active, session: session, studyTime: Date().timeIntervalSince(startedAt))
    }

    private func close() {
        if !finishedRecorded && session.answers > 0 {
            model.finishMastery(active, session: session, studyTime: Date().timeIntervalSince(startedAt))
        }
        dismiss()
    }
}

/// One mastery question: multiple choice in the first round, typing afterwards.
struct MasteryItemView: View {
    let item: MasteryItem
    let useChoices: Bool
    let onAnswered: (Bool) -> Void

    @State private var selected: Int?
    @State private var input = ""
    @State private var verdict: AnswerVerdict?
    @FocusState private var focused: Bool

    private var isCorrect: Bool? {
        if let selected { return item.choices[selected] == item.answers.first }
        return verdict.map(\.isAccepted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.kicker.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.sentence)
                Text(item.prompt)
                    .font(.system(size: item.prompt.count > 22 ? 28 : 38, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail {
                    Text(detail).font(.title3).foregroundStyle(.secondary)
                }
            }
            .card(padding: 20)

            if useChoices {
                VStack(spacing: 10) {
                    ForEach(Array(item.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            guard selected == nil else { return }
                            selected = index
                            haptic(choice == item.answers.first)
                        } label: {
                            HStack {
                                Text(choice).font(.title3)
                                Spacer()
                                if selected != nil && choice == item.answers.first {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.correct)
                                } else if selected == index {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.wrong)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(choiceBackground(index, choice),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(.separator).opacity(0.4)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            } else {
                HStack {
                    Text(item.answerLanguage.flag)
                    TextField("Auf \(item.answerLanguage.displayName) …", text: $input)
                        .font(.title2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focused)
                        .disabled(verdict != nil)
                        .onSubmit(check)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(focused ? Theme.sentence : Color(.separator).opacity(0.4), lineWidth: 1.5))
                if verdict == nil {
                    SpecialCharacterBar(characters: item.answerLanguage.specialCharacters) { input += $0 }
                    Button("Prüfen", action: check)
                        .buttonStyle(PrimaryButtonStyle(color: Theme.sentence))
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Weiß ich nicht") { verdict = .wrong(expected: item.answers.first ?? "") }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            if let isCorrect {
                feedback(correct: isCorrect)
            }
        }
        .animation(.easeInOut, value: selected)
        .animation(.easeInOut, value: verdict)
        .onAppear { if !useChoices { focused = true } }
    }

    private func check() {
        guard verdict == nil, !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let result = AnswerChecker.check(input, accepted: item.answers)
        verdict = result
        focused = false
        haptic(result.isAccepted)
        if let speech = item.speech { Speaker.shared.speak(speech, language: .turkish) }
    }

    private func choiceBackground(_ index: Int, _ choice: String) -> Color {
        guard let selected else { return Color(.secondarySystemGroupedBackground) }
        if choice == item.answers.first { return Theme.correct.opacity(0.15) }
        if index == selected { return Theme.wrong.opacity(0.15) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func feedback(correct: Bool) -> some View {
        let color = correct ? Theme.correct : Theme.wrong
        return VStack(alignment: .leading, spacing: 10) {
            Label(correct ? "Richtig!" : "Noch nicht ganz", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3.bold())
                .foregroundStyle(color)
            if !correct, let answer = item.answers.first {
                Text("Richtig ist: \(answer)").font(.headline)
            }
            if case .missingDiacritics(let expected) = verdict {
                Text("Achte auf die Sonderzeichen: \(expected)").font(.subheadline)
            }
            if case .typo(let expected) = verdict {
                Text("Kleiner Tippfehler – richtig: \(expected)").font(.subheadline)
            }
            HStack(alignment: .top) {
                if let explanation = item.explanation {
                    Text(explanation).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let speech = item.speech { SpeakButton(text: speech, tint: color) }
            }
            Button(correct ? "Weiter" : "Verstanden") { onAnswered(correct) }
                .buttonStyle(PrimaryButtonStyle(color: color))
        }
        .padding(16)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct MasterySummary: View {
    let session: MasterySession
    let seconds: TimeInterval
    let onClose: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                Spacer()
                ProgressRing(progress: 1, lineWidth: 16, colors: [Theme.sentence, Theme.correct]) {
                    Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundStyle(Theme.correct)
                }
                .frame(width: 150, height: 150)
                Text("Alles gemeistert!").font(.largeTitle.bold())
                Text(session.target == 1 ? "Jede Aufgabe saß." : "Jede Aufgabe saß \(session.target)× hintereinander.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    SummaryTile(value: "\(session.items.count)", label: "Aufgaben", systemImage: "checklist", color: Theme.sentence)
                    SummaryTile(value: session.firstTryScore.percentLabel, label: "auf Anhieb", systemImage: "target",
                                color: Theme.correct)
                    SummaryTile(value: seconds.durationLabel, label: "Dauer", systemImage: "clock", color: Theme.coral)
                }
                Spacer()
                Button("Fertig", action: onClose).buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .readableWidth()
            ConfettiView()
        }
        .onAppear { haptic(true) }
    }
}

// MARK: - Verb info

/// Orange "unregelmäßig" marker for irregular verbs.
struct IrregularBadge: View {
    let word: Word
    var onDark = false

    var body: some View {
        if let verb = word.turkishVerb, verb.isIrregular {
            Label("unregelmäßig", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(onDark ? Color.white.opacity(0.22) : Theme.almost.opacity(0.18), in: Capsule())
                .foregroundStyle(onDark ? Color.white : Theme.almost)
        }
    }
}

/// Dictionary form, stem + ending, irregularities and a conjugation table.
struct VerbInfoCard: View {
    let word: Word
    @State private var tense: Tense = .present

    var body: some View {
        if let verb = word.turkishVerb {
            VStack(alignment: .leading, spacing: 12) {
                Label("Verb", systemImage: "puzzlepiece.fill").font(.headline).foregroundStyle(Theme.sentence)
                HStack(spacing: 0) {
                    Text(verb.prefix + verb.stem).font(.title2.bold())
                    Text(verb.ending).font(.title2.bold()).foregroundStyle(Theme.red)
                }
                Text("Grundform = Stamm „\(verb.stem)“ + Endung „-\(verb.ending)“. Der letzte Vokal „\(TurkishSounds.lastVowel(verb.stem).map(String.init) ?? "")“ bestimmt -\(verb.ending).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(verb.irregularities, id: \.self) { irregularity in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(irregularity.title).font(.subheadline.weight(.semibold))
                            Text(verb.explanation(of: irregularity)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.almost)
                    }
                }
                Picker("Zeit", selection: $tense) {
                    ForEach(Tense.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                ConjugationTable(verbs: [verb], tense: tense)
                Text(tense.turkishName).font(.caption).foregroundStyle(.secondary)
            }
            .card(padding: 18)
        }
    }
}
