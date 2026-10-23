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

struct SessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let title: String
    @State private var session: LearningSession
    @State private var context: ExerciseContext?

    init(active: ActiveSession) {
        title = active.title
        _session = State(initialValue: active.session)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !session.isEmpty && !session.isFinished {
                    ProgressView(value: session.fractionDone)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .animation(.easeInOut, value: session.position)
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
            SessionSummaryView(session: session, onClose: close)
        } else if let context {
            ScrollView {
                exercise(for: context)
                    .padding()
                    .readableWidth()
            }
            .id(context.item.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        }
    }

    @ViewBuilder
    private func exercise(for context: ExerciseContext) -> some View {
        let word = context.word
        switch context.item.kind {
        case .introduction:
            IntroductionView(word: word) { complete(nil) }
        case .chooseNative:
            ChoiceExerciseView(title: context.item.kind.title, prompt: word.translation, speakPrompt: true,
                               subtitle: nil, options: context.options, correctIndex: context.correctOption,
                               word: word, onComplete: complete)
        case .chooseTarget:
            ChoiceExerciseView(title: context.item.kind.title, prompt: word.nativeWithArticle, speakPrompt: false,
                               subtitle: nil, options: context.options, correctIndex: context.correctOption,
                               word: word, onComplete: complete)
        case .clozeChoice:
            ChoiceExerciseView(title: context.item.kind.title, prompt: word.cloze.masked(), speakPrompt: false,
                               subtitle: word.exampleNative, options: context.options,
                               correctIndex: context.correctOption, word: word, onComplete: complete)
        case .typeTarget:
            TypingExerciseView(title: context.item.kind.title, prompt: word.nativeWithArticle, subtitle: nil,
                               accepted: word.acceptedTranslations, hint: nil, word: word, onComplete: complete)
        case .clozeType:
            TypingExerciseView(title: context.item.kind.title, prompt: word.cloze.masked(),
                               subtitle: word.exampleNative, accepted: [word.cloze.answer],
                               hint: "Grundform: \(word.translation)", word: word, onComplete: complete)
        case .flashcard:
            FlashcardExerciseView(word: word, card: model.card(for: word), scheduler: model.scheduler,
                                  onComplete: complete)
        case .sentenceBuilder:
            SentenceBuilderView(word: word, tokens: context.tokens, onComplete: complete)
        }
    }

    private func complete(_ rating: Rating?) {
        if let item = session.current, let rating {
            let cap = item.kind.ratingCap
            let capped = Rating(rawValue: min(rating.rawValue, cap.rawValue)) ?? rating
            model.record(wordID: item.wordID, rating: capped)
        }
        withAnimation(.easeInOut) {
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
        model.sessionFinished()
        dismiss()
    }
}

private struct EmptySessionView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
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
    let onClose: () -> Void

    private var accuracy: Int {
        session.answered == 0 ? 100 : Int((Double(session.correct) / Double(session.answered) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("Geschafft!")
                .font(.largeTitle.bold())
            HStack(spacing: 12) {
                StatTile(value: session.newWordIDs.count, label: "neue Wörter", systemImage: "sparkles")
                StatTile(value: session.answered, label: "Antworten", systemImage: "checkmark.circle")
                StatTile(value: accuracy, label: "% richtig", systemImage: "target")
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
    }
}
