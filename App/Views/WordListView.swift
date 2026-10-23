import SwiftUI
import VocaDayCore

struct WordListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""

    var body: some View {
        List {
            if model.introducedWords.isEmpty && model.upcomingWords.isEmpty {
                ContentUnavailableView("Noch keine Wörter", systemImage: "books.vertical",
                                       description: Text("Dein erstes Wort wartet im Tab „Heute“."))
            }
            section("Gelernt", words: filtered(model.introducedWords))
            section("Demnächst", words: filtered(model.upcomingWords))
        }
        .searchable(text: $search, prompt: "Deutsch oder Türkisch suchen")
        .navigationTitle("Wörter")
    }

    @ViewBuilder
    private func section(_ title: String, words: [Word]) -> some View {
        if !words.isEmpty {
            Section("\(title) (\(words.count))") {
                ForEach(words) { word in
                    NavigationLink {
                        WordDetailView(word: word)
                    } label: {
                        WordRow(word: word, status: model.status(of: word), card: model.card(for: word))
                    }
                }
            }
        }
    }

    private func filtered(_ words: [Word]) -> [Word] {
        let query = TurkishText.normalized(search)
        guard !query.isEmpty else { return words }
        return words.filter {
            TurkishText.normalized($0.native).contains(query)
                || TurkishText.normalized($0.translation).contains(query)
                || TurkishText.foldingDiacritics(TurkishText.normalized($0.translation)).contains(query)
        }
    }
}

private struct WordRow: View {
    let word: Word
    let status: WordStatus
    let card: CardState?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.translation).font(.headline)
                Text(word.nativeWithArticle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(status.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(status.color)
                if let card {
                    Text(card.due.relativeDescription())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct WordDetailView: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(word.translation)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Spacer()
                        SpeakButton(text: word.translation)
                    }
                    Text(word.nativeWithArticle).font(.title2).foregroundStyle(.secondary)
                    if !word.alternatives.isEmpty {
                        Text("auch: \(word.alternatives.joined(separator: ", "))")
                            .foregroundStyle(.secondary)
                    }
                    Text("\(word.partOfSpeech.displayName) · Rang \(word.rank) der häufigsten Wörter")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .card(padding: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Beispiel").font(.headline)
                    HStack(alignment: .top) {
                        HighlightedSentence(cloze: word.cloze).font(.title3)
                        Spacer()
                        SpeakButton(text: word.cloze.plain)
                    }
                    Text(word.exampleNative).foregroundStyle(.secondary)
                    Button {
                        Speaker.shared.speak(word.cloze.plain, language: .turkish, slow: true)
                    } label: {
                        Label("Langsam vorlesen", systemImage: "tortoise")
                    }
                    .font(.subheadline)
                }
                .card()

                if let note = word.note {
                    Label(note, systemImage: "lightbulb").card()
                }

                if let card = model.card(for: word) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dein Lernstand").font(.headline)
                        LabeledContent("Status", value: model.status(of: word).rawValue)
                        LabeledContent("Nächste Wiederholung", value: card.due.relativeDescription())
                        LabeledContent("Erinnerung gerade",
                                       value: "\(Int((model.scheduler.retrievability(of: card, at: Date()) * 100).rounded())) %")
                        LabeledContent("Stabilität", value: String(format: "%.1f Tage", card.stability))
                        LabeledContent("Schwierigkeit", value: String(format: "%.1f / 10", card.difficulty))
                        LabeledContent("Wiederholungen", value: "\(card.reps)")
                        LabeledContent("Vergessen", value: "\(card.lapses)×")
                    }
                    .card()
                } else {
                    Label("Dieses Wort ist für einen der nächsten Tage geplant.", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                        .card()
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(word.translation)
        .navigationBarTitleDisplayMode(.inline)
    }
}
