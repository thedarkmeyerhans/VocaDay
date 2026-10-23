import SwiftUI
import UIKit
import VocaDayCore

// MARK: - Introduction

/// First encounter with a new word: meaning, pronunciation, example.
struct IntroductionView: View {
    let word: Word
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Neues Wort", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(word.translation)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Spacer()
                    SpeakButton(text: word.translation)
                }
                Text(word.nativeWithArticle)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                if !word.alternatives.isEmpty {
                    Text("auch: \(word.alternatives.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .card(padding: 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("Im Satz").font(.headline)
                HStack(alignment: .top) {
                    HighlightedSentence(cloze: word.cloze)
                        .font(.title3)
                    Spacer()
                    SpeakButton(text: word.cloze.plain)
                }
                Text(word.exampleNative)
                    .foregroundStyle(.secondary)
            }
            .card()

            if let note = word.note {
                Label(note, systemImage: "lightbulb")
                    .font(.subheadline)
                    .card()
            }

            Text("Sprich das Wort laut nach – das hilft beim Merken.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Verstanden", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .onAppear { Speaker.shared.speak(word.translation, language: .turkish) }
    }
}

// MARK: - Feedback

struct FeedbackPanel: View {
    enum Outcome { case correct, almost, wrong }

    let outcome: Outcome
    let detail: String?
    let word: Word
    let onContinue: () -> Void

    private var color: Color {
        switch outcome {
        case .correct: return Theme.correct
        case .almost: return .orange
        case .wrong: return Theme.wrong
        }
    }

    private var title: String {
        switch outcome {
        case .correct: return "Richtig!"
        case .almost: return "Fast richtig"
        case .wrong: return "Noch nicht ganz"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: outcome == .wrong ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(color)
            if let detail {
                Text(detail).font(.subheadline)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(word.translation) – \(word.nativeWithArticle)")
                        .font(.body.weight(.semibold))
                    HighlightedSentence(cloze: word.cloze)
                        .font(.subheadline)
                    Text(word.exampleNative)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SpeakButton(text: word.cloze.plain)
            }
            Button("Weiter", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(color: color))
                .padding(.top, 4)
        }
        .padding(16)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct PromptHeader: View {
    let title: String
    let prompt: String
    let subtitle: String?
    var speak: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(alignment: .top) {
                Text(prompt)
                    .font(.system(size: prompt.count > 24 ? 26 : 38, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let speak { SpeakButton(text: speak) }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 20)
    }
}

// MARK: - Multiple choice

struct ChoiceExerciseView: View {
    let title: String
    let prompt: String
    let speakPrompt: Bool
    let subtitle: String?
    let options: [String]
    let correctIndex: Int
    let word: Word
    let onComplete: (Rating?) -> Void

    @State private var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptHeader(title: title, prompt: prompt, subtitle: subtitle, speak: speakPrompt ? prompt : nil)
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        guard selected == nil else { return }
                        selected = index
                        haptic(index == correctIndex)
                    } label: {
                        HStack {
                            Text(option).font(.title3)
                            Spacer()
                            if selected != nil && index == correctIndex {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.correct)
                            } else if selected == index {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.wrong)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(for: index),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let selected {
                FeedbackPanel(outcome: selected == correctIndex ? .correct : .wrong,
                              detail: selected == correctIndex ? nil : "Richtig ist: \(options[correctIndex])",
                              word: word) {
                    onComplete(selected == correctIndex ? .good : .again)
                }
            }
        }
        .animation(.easeInOut, value: selected)
    }

    private func background(for index: Int) -> Color {
        guard let selected else { return Color(.secondarySystemGroupedBackground) }
        if index == correctIndex { return Theme.correct.opacity(0.2) }
        if index == selected { return Theme.wrong.opacity(0.2) }
        return Color(.secondarySystemGroupedBackground)
    }
}

// MARK: - Typing

struct TypingExerciseView: View {
    let title: String
    let prompt: String
    let subtitle: String?
    let accepted: [String]
    let hint: String?
    let word: Word
    let onComplete: (Rating?) -> Void

    @State private var input = ""
    @State private var verdict: AnswerVerdict?
    @State private var showHint = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptHeader(title: title, prompt: prompt, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Auf Türkisch …", text: $input)
                    .font(.title2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focused)
                    .disabled(verdict != nil)
                    .onSubmit(check)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                SpecialCharacterBar(characters: Language.turkish.specialCharacters) { input += $0 }
                    .disabled(verdict != nil)
            }

            if verdict == nil {
                if let hint {
                    Button(showHint ? hint : "Tipp anzeigen") { showHint = true }
                        .font(.subheadline)
                }
                Button("Prüfen", action: check)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Weiß ich nicht") {
                    verdict = .wrong(expected: accepted.first ?? "")
                }
                .frame(maxWidth: .infinity)
            }

            if let verdict {
                FeedbackPanel(outcome: outcome(verdict), detail: detail(verdict), word: word) {
                    onComplete(verdict.rating)
                }
                if case .wrong = verdict, !input.isEmpty {
                    Button("Meine Antwort war richtig") { onComplete(.hard) }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.easeInOut, value: verdict)
        .onAppear { focused = true }
    }

    private func check() {
        guard verdict == nil, !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let result = AnswerChecker.check(input, accepted: accepted)
        verdict = result
        focused = false
        haptic(result.isAccepted)
    }

    private func outcome(_ verdict: AnswerVerdict) -> FeedbackPanel.Outcome {
        switch verdict {
        case .correct: return .correct
        case .missingDiacritics, .typo: return .almost
        case .wrong: return .wrong
        }
    }

    private func detail(_ verdict: AnswerVerdict) -> String? {
        switch verdict {
        case .correct: return nil
        case .missingDiacritics(let expected): return "Achte auf die Sonderzeichen: \(expected)"
        case .typo(let expected): return "Kleiner Tippfehler – richtig: \(expected)"
        case .wrong(let expected): return "Richtig ist: \(expected)"
        }
    }
}

struct SpecialCharacterBar: View {
    let characters: [String]
    let onTap: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(characters, id: \.self) { character in
                Button(character) { onTap(character) }
                    .font(.title3.weight(.medium))
                    .frame(minWidth: 36, minHeight: 36)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Flashcard

/// Classic flip card with self-rating. The buttons show when the word would
/// come back, so the learner sees the effect of the rating.
struct FlashcardExerciseView: View {
    let word: Word
    let card: CardState?
    let scheduler: FSRSScheduler
    let onComplete: (Rating?) -> Void

    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptHeader(title: ExerciseKind.flashcard.title, prompt: word.nativeWithArticle,
                         subtitle: "Sag das türkische Wort laut, dann deck auf.")
            if revealed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(word.translation)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Spacer()
                        SpeakButton(text: word.translation)
                    }
                    HighlightedSentence(cloze: word.cloze)
                    Text(word.exampleNative).foregroundStyle(.secondary)
                }
                .card(padding: 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                Text("Wie gut wusstest du es?")
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(Rating.allCases, id: \.self) { rating in
                        Button {
                            onComplete(rating)
                        } label: {
                            VStack(spacing: 4) {
                                Text(rating.displayName).font(.subheadline.weight(.semibold))
                                Text(intervalLabel(for: rating)).font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(color(for: rating).opacity(0.18),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(color(for: rating))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Button("Antwort zeigen") {
                    withAnimation { revealed = true }
                    Speaker.shared.speak(word.translation, language: .turkish)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func intervalLabel(for rating: Rating) -> String {
        let now = Date()
        return scheduler.schedule(card, rating: rating, at: now).due.timeIntervalSince(now).shortIntervalLabel
    }

    private func color(for rating: Rating) -> Color {
        switch rating {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }
}

// MARK: - Sentence builder

/// Put the shuffled words of the target sentence in order.
struct SentenceBuilderView: View {
    let word: Word
    let tokens: [String]
    let onComplete: (Rating?) -> Void

    @State private var chosen: [Int] = []
    @State private var result: Bool?

    private var built: String { chosen.map { tokens[$0] }.joined(separator: " ") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptHeader(title: ExerciseKind.sentenceBuilder.title, prompt: word.exampleNative,
                         subtitle: "Tippe die Wörter in der richtigen Reihenfolge an.")

            FlowLayout(spacing: 8) {
                ForEach(chosen, id: \.self) { index in
                    chip(tokens[index], filled: true) {
                        guard result == nil else { return }
                        chosen.removeAll { $0 == index }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            FlowLayout(spacing: 8) {
                ForEach(tokens.indices.filter { !chosen.contains($0) }, id: \.self) { index in
                    chip(tokens[index], filled: false) {
                        guard result == nil else { return }
                        chosen.append(index)
                    }
                }
            }

            if let result {
                FeedbackPanel(outcome: result ? .correct : .wrong,
                              detail: result ? nil : "Richtig ist: \(word.cloze.plain)", word: word) {
                    onComplete(result ? .good : .again)
                }
            } else {
                Button("Prüfen") {
                    let isCorrect = TurkishText.normalized(built) == TurkishText.normalized(word.cloze.plain)
                    result = isCorrect
                    haptic(isCorrect)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(chosen.count != tokens.count)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: chosen)
        .animation(.easeInOut, value: result)
    }

    private func chip(_ text: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(filled ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
func haptic(_ success: Bool) {
    UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
}
