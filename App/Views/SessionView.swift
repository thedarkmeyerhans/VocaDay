import SwiftUI
import VocaDayCore

/// Everything an exercise needs, prepared when the item becomes current.
struct ExerciseContext {
    let item: SessionItem
    let word: Word
    /// Answer options for multiple-choice exercises, already shuffled.
    var options: [String] = []
    var correctOption: Int = 0
    /// Shuffled sentence parts for the sentence builder.
    var tokens: [String] = []

    @MainActor
    static func make(for item: SessionItem, words: WordIndex) -> ExerciseContext? {
        guard let word = words[item.wordID] else { return nil }
        var generator = SystemRandomNumberGenerator()
        var context = ExerciseContext(item: item, word: word)
        let all = words.bank.words

        func choices(_ answer: (Word) -> String, pool: [Word]) {
            let others = DistractorPicker.distractors(for: word, in: pool, answer: answer, using: &generator)
            var options = others.map(answer) + [answer(word)]
            options.shuffle(using: &generator)
            context.options = options
            context.correctOption = options.firstIndex(of: answer(word)) ?? 0
        }

        switch item.kind {
        case .chooseNative:
            choices({ $0.nativeWithArticle }, pool: all)
        case .chooseTarget:
            choices({ $0.translation }, pool: all)
        case .clozeChoice:
            choices({ $0.cloze.answer }, pool: all.filter { $0.cloze.hasGap })
        case .sentenceBuilder:
            var tokens = word.cloze.tokens
            if Set(tokens).count > 1 {
                repeat { tokens.shuffle(using: &generator) } while tokens == word.cloze.tokens
            }
            context.tokens = tokens
        default:
            break
        }
        return context
    }
}

/// Shows the exercise for one item. Shared by learning sessions and tests.
struct ExerciseView: View {
    let context: ExerciseContext
    let card: CardState?
    let scheduler: FSRSScheduler
    let onComplete: (Rating?) -> Void

    var body: some View {
        let word = context.word
        let kind = context.item.kind
        switch kind {
        case .introduction:
            IntroductionView(word: word) { onComplete(nil) }
        case .chooseNative:
            ChoiceExerciseView(title: kind.title, prompt: word.translation, speakPrompt: true,
                               subtitle: nil, options: context.options, correctIndex: context.correctOption,
                               word: word, onComplete: onComplete)
        case .chooseTarget:
            ChoiceExerciseView(title: kind.title, prompt: word.nativeWithArticle, speakPrompt: false,
                               subtitle: nil, options: context.options, correctIndex: context.correctOption,
                               word: word, onComplete: onComplete)
        case .clozeChoice:
            ChoiceExerciseView(title: kind.title, prompt: word.cloze.masked(), speakPrompt: false,
                               subtitle: word.exampleNative, options: context.options,
                               correctIndex: context.correctOption, word: word, onComplete: onComplete)
        case .typeTarget:
            TypingExerciseView(title: kind.title, prompt: word.nativeWithArticle, subtitle: nil,
                               accepted: word.acceptedTranslations, hint: nil, language: .turkish,
                               word: word, onComplete: onComplete)
        case .typeNative:
            TypingExerciseView(title: kind.title, prompt: word.translation, subtitle: nil,
                               accepted: [word.native, word.nativeWithArticle], hint: nil, language: .german,
                               speakPrompt: true, word: word, onComplete: onComplete)
        case .clozeType:
            TypingExerciseView(title: kind.title, prompt: word.cloze.masked(),
                               subtitle: word.exampleNative, accepted: [word.cloze.answer],
                               hint: "Grundform: \(word.translation)", language: .turkish,
                               word: word, onComplete: onComplete)
        case .flashcard:
            FlashcardExerciseView(word: word, card: card, scheduler: scheduler, onComplete: onComplete)
        case .sentenceBuilder:
            SentenceBuilderView(word: word, tokens: context.tokens, onComplete: onComplete)
        }
    }
}

/// Thin progress bar with the sunrise gradient.
struct SessionProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(Theme.sunrise)
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 8)
        .animation(.spring(duration: 0.5), value: progress)
    }
}

struct SessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let title: String
    @State private var session: LearningSession
    @State private var context: ExerciseContext?
    @State private var startedAt = Date()

    init(active: ActiveSession) {
        title = active.title
        _session = State(initialValue: active.session)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !session.isEmpty && !session.isFinished {
                    HStack(spacing: 12) {
                        SessionProgressBar(progress: session.fractionDone)
                        Text("\(session.remaining)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                content
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
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
        .onAppear(perform: loadContext)
    }

    @ViewBuilder
    private var content: some View {
        if session.isEmpty {
            EmptySessionView(onClose: close)
        } else if session.isFinished {
            SessionSummaryView(session: session, seconds: Date().timeIntervalSince(startedAt), onClose: close)
        } else if let context {
            ScrollView {
                ExerciseView(context: context, card: model.card(for: context.word), scheduler: model.scheduler,
                             onComplete: complete)
                    .padding()
                    .readableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .id(context.item.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
    }

    private func complete(_ rating: Rating?) {
        if let item = session.current, let rating {
            let cap = item.kind.ratingCap
            let capped = Rating(rawValue: min(rating.rawValue, cap.rawValue)) ?? rating
            model.record(wordID: item.wordID, rating: capped)
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            session.advance(after: rating)
            loadContext()
        }
    }

    private func loadContext() {
        while let item = session.current {
            if let next = ExerciseContext.make(for: item, words: model.words) {
                context = next
                return
            }
            session.advance(after: nil)
        }
        context = nil
    }

    private func close() {
        model.sessionFinished(studyTime: session.answered > 0 ? Date().timeIntervalSince(startedAt) : 0)
        dismiss()
    }
}

private struct EmptySessionView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            GradientIcon(systemName: "checkmark", color: Theme.correct, size: 80)
            Text("Gerade gibt es nichts zu üben.")
                .font(.title3.bold())
            Text("Lerne zuerst ein paar Wörter – dann kannst du sie hier wiederholen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Schließen", action: onClose)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .readableWidth()
    }
}

private struct SessionSummaryView: View {
    let session: LearningSession
    let seconds: TimeInterval
    let onClose: () -> Void

    private var accuracy: Double {
        session.answered == 0 ? 1 : Double(session.correct) / Double(session.answered)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()
                ProgressRing(progress: accuracy, lineWidth: 16, colors: [Theme.correct, Theme.test]) {
                    VStack(spacing: 2) {
                        Text(accuracy.percentLabel)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("richtig").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 170, height: 170)
                Text("Geschafft!")
                    .font(.largeTitle.bold())
                HStack(spacing: 12) {
                    SummaryTile(value: "\(session.newWordIDs.count)", label: "neue Wörter",
                                systemImage: "sparkles", color: Theme.coral)
                    SummaryTile(value: "\(session.answered)", label: "Antworten",
                                systemImage: "checkmark.circle", color: Theme.review)
                    SummaryTile(value: seconds.durationLabel, label: "Lernzeit",
                                systemImage: "clock", color: Theme.sentence)
                }
                Text("Die Wörter kommen genau dann wieder, wenn du sie sonst vergessen würdest.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Fertig", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .readableWidth()
            ConfettiView()
        }
        .onAppear { haptic(true) }
    }
}

struct SummaryTile: View {
    let value: String
    let label: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 12)
    }
}
