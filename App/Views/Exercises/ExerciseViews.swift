import SwiftUI
import UIKit
import VocaDayCore

// MARK: - Introduction

/// First encounter with a new word: meaning, pronunciation, example.
struct IntroductionView: View {
    let word: Word
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Pill(text: "Neues Wort", systemImage: "sparkles", color: .white)
                    IrregularBadge(word: word, onDark: true)
                    Spacer()
                    SpeakButton(text: word.translation, tint: .white)
                }
                Text(word.translation)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Text(word.nativeWithArticle)
                    .font(.title2.weight(.medium))
                    .opacity(0.9)
                if !word.alternatives.isEmpty {
                    Text("auch: \(word.alternatives.joined(separator: ", "))")
                        .font(.subheadline)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sunrise, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: Theme.red.opacity(0.3), radius: 14, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Im Satz", systemImage: "text.quote").font(.headline)
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
                Label(note, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .symbolRenderingMode(.multicolor)
                    .card()
            }

            if let verb = word.turkishVerb {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Grundform: \(verb.prefix)\(verb.stem) + -\(verb.ending)").font(.subheadline.weight(.semibold))
                    ForEach(verb.irregularities, id: \.self) { irregularity in
                        Label(verb.explanation(of: irregularity), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.almost)
                    }
                    if !verb.isIrregular {
                        Text("Regelmäßiges Verb – die Endungen lernst du später im Grammatik-Pfad.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .card()
            }

            Label("Sprich das Wort laut nach – das hilft beim Merken.", systemImage: "mouth")
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
        case .almost: return Theme.almost
        case .wrong: return Theme.wrong
        }
    }

    private var title: String {
        switch outcome {
        case .correct: return ["Richtig!", "Super!", "Genau!", "Klasse!"].randomElement()!
        case .almost: return "Fast richtig"
        case .wrong: return "Noch nicht ganz"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: outcome == .wrong ? "xmark" : "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color, in: Circle())
                Text(title).font(.title3.bold()).foregroundStyle(color)
            }
            if let detail {
                Text(detail).font(.subheadline.weight(.medium))
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(word.translation).font(.body.weight(.bold))
                        Text("–").foregroundStyle(.secondary)
                        ArticleWord(word: word, font: .body)
                    }
                    HighlightedSentence(cloze: word.cloze, highlight: color)
                        .font(.subheadline)
                    Text(word.exampleNative)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SpeakButton(text: word.cloze.plain, tint: color)
            }
            Button("Weiter", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(color: color))
                .padding(.top, 4)
        }
        .padding(16)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(color.opacity(0.3), lineWidth: 1))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct PromptHeader: View {
    let title: String
    let prompt: String
    let subtitle: String?
    var speak: String?
    var speakLanguage: Language = .turkish

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.red)
            HStack(alignment: .top) {
                Text(prompt)
                    .font(.system(size: prompt.count > 24 ? 26 : 38, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let speak { SpeakButton(text: speak, language: speakLanguage) }
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
                        HStack(spacing: 12) {
                            Text(["A", "B", "C", "D", "E"][min(index, 4)])
                                .font(.subheadline.weight(.bold))
                                .frame(width: 30, height: 30)
                                .background(badgeColor(for: index).opacity(0.15), in: Circle())
                                .foregroundStyle(badgeColor(for: index))
                            Text(option).font(.title3).multilineTextAlignment(.leading)
                            Spacer()
                            if selected != nil && index == correctIndex {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.correct)
                            } else if selected == index {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.wrong)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(for: index),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(border(for: index), lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
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

    private func badgeColor(for index: Int) -> Color {
        guard let selected else { return Theme.red }
        if index == correctIndex { return Theme.correct }
        if index == selected { return Theme.wrong }
        return .secondary
    }

    private func background(for index: Int) -> Color {
        guard let selected else { return Color(.secondarySystemGroupedBackground) }
        if index == correctIndex { return Theme.correct.opacity(0.15) }
        if index == selected { return Theme.wrong.opacity(0.15) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func border(for index: Int) -> Color {
        guard let selected else { return Color(.separator).opacity(0.4) }
        if index == correctIndex { return Theme.correct }
        if index == selected { return Theme.wrong }
        return .clear
    }
}

// MARK: - Typing

struct TypingExerciseView: View {
    let title: String
    let prompt: String
    let subtitle: String?
    let accepted: [String]
    let hint: String?
    let language: Language
    var speakPrompt = false
    let word: Word
    let onComplete: (Rating?) -> Void

    @State private var input = ""
    @State private var verdict: AnswerVerdict?
    @State private var showHint = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PromptHeader(title: title, prompt: prompt, subtitle: subtitle, speak: speakPrompt ? prompt : nil)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(language.flag)
                    TextField("Auf \(language.displayName) …", text: $input)
                        .font(.title2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focused)
                        .disabled(verdict != nil)
                        .onSubmit(check)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focused ? Theme.red : Color(.separator).opacity(0.4), lineWidth: 1.5))
                SpecialCharacterBar(characters: language.specialCharacters) { input += $0 }
                    .disabled(verdict != nil)
            }

            if verdict == nil {
                if let hint {
                    Button {
                        withAnimation { showHint = true }
                    } label: {
                        Label(showHint ? hint : "Tipp anzeigen", systemImage: "lightbulb")
                    }
                    .font(.subheadline)
                }
                Button("Prüfen", action: check)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Weiß ich nicht") {
                    verdict = .wrong(expected: accepted.first ?? "")
                    focused = false
                }
                .foregroundStyle(.secondary)
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
                    .frame(minWidth: 38, minHeight: 38)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator).opacity(0.4)))
                    .buttonStyle(PressableStyle())
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
            ZStack {
                if revealed {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(word.translation)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Spacer()
                            SpeakButton(text: word.translation, tint: .white)
                        }
                        HighlightedSentence(cloze: word.cloze, highlight: .white)
                        Text(word.exampleNative).opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.sunrise, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { revealed = true }
                        Speaker.shared.speak(word.translation, language: .turkish)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill").font(.largeTitle)
                            Text("Antwort zeigen").font(.headline)
                        }
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .background(Theme.red.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .strokeBorder(Theme.red.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            if revealed {
                Text("Wie gut wusstest du es?")
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(Rating.allCases, id: \.self) { rating in
                        Button {
                            onComplete(rating)
                        } label: {
                            VStack(spacing: 4) {
                                Text(rating.displayName).font(.subheadline.weight(.semibold))
                                Text(intervalLabel(for: rating)).font(.caption).opacity(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(color(for: rating).opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(color(for: rating))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func intervalLabel(for rating: Rating) -> String {
        let now = Date()
        return scheduler.schedule(card, rating: rating, at: now).due.timeIntervalSince(now).shortIntervalLabel
    }

    private func color(for rating: Rating) -> Color {
        switch rating {
        case .again: return Theme.wrong
        case .hard: return Theme.almost
        case .good: return Theme.correct
        case .easy: return Theme.review
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
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(resultColor, style: StrokeStyle(lineWidth: 1.5, dash: result == nil ? [6] : [])))

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
        .animation(.spring(duration: 0.25), value: chosen)
        .animation(.easeInOut, value: result)
    }

    private var resultColor: Color {
        switch result {
        case .some(true): return Theme.correct
        case .some(false): return Theme.wrong
        case .none: return Color(.separator)
        }
    }

    private func chip(_ text: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.title3.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(filled ? AnyShapeStyle(Theme.sunrise) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(filled ? Color.white : Color.primary)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(filled ? Color.clear : Color(.separator).opacity(0.5)))
                .shadow(color: .black.opacity(filled ? 0.1 : 0.03), radius: 3, y: 2)
        }
        .buttonStyle(PressableStyle())
    }
}

@MainActor
func haptic(_ success: Bool) {
    UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
}
