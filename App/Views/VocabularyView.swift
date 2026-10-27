import SwiftUI
import VocaDayCore

/// The vocabulary tab: overview, A–Z letters, status rows and history instead
/// of one long list. Search covers the whole dictionary.
struct VocabularyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var mode: Mode = .letters
    @State private var historyDays = 14
    @State private var deck: CardDeck?

    enum Mode: String, CaseIterable, Identifiable {
        case letters = "A–Z"
        case status = "Status"
        case history = "Verlauf"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if search.trimmingCharacters(in: .whitespaces).isEmpty {
                    header
                    Picker("Ansicht", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .letters: letters
                    case .status: statusRows
                    case .history: history
                    }
                } else {
                    SearchResults(query: search)
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Wortschatz")
        .searchable(text: $search, prompt: "Wort suchen – Deutsch oder Türkisch")
        .fullScreenCover(item: $deck) { deck in
            FlashcardBrowserView(deck: deck)
        }
    }

    // MARK: Header

    private var header: some View {
        let groups = model.wordsByStatus
        let total = model.words.bank.words.count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ProgressRing(progress: Double(model.learnedCount) / Double(max(1, total)), lineWidth: 11) {
                    Text("\(model.learnedCount)").font(.subheadline.weight(.bold).monospacedDigit())
                }
                .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.learnedCount) von \(total) Wörtern").font(.title3.bold())
                    Text("Deine Wörter machen \(model.statistics.coverage.percentLabel) eines Alltagsgesprächs aus.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                ForEach(WordStatus.overview) { status in
                    let count = groups[status]?.count ?? 0
                    NavigationLink {
                        WordGroupView(status: status)
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(count)").font(.title2.bold().monospacedDigit())
                            Text(status.rawValue).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(status.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(status.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(count == 0)
                    .opacity(count == 0 ? 0.45 : 1)
                }
            }
            if model.learnedCount > 0 {
                Button {
                    let learned = model.introducedWords.sorted { recall($0) < recall($1) }
                    deck = CardDeck(title: "Gelernte Wörter", words: learned)
                } label: {
                    Label("Karteikarten üben", systemImage: "rectangle.stack.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card(padding: 18)
    }

    private func recall(_ word: Word) -> Double {
        model.card(for: word).map { model.scheduler.retrievability(of: $0, at: Date()) } ?? 2
    }

    // MARK: Modes

    private var letters: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                ForEach(model.statistics.letters) { letter in
                    NavigationLink {
                        LetterWordsView(letter: letter.letter)
                    } label: {
                        VStack(spacing: 6) {
                            ProgressRing(progress: letter.fraction, lineWidth: 5,
                                         colors: letter.learned > 0 ? [Theme.coral, Theme.red]
                                            : [Color(.systemGray4), Color(.systemGray4)]) {
                                Text(letter.letter).font(.title3.bold()).foregroundStyle(.primary)
                            }
                            .frame(width: 52, height: 52)
                            Text("\(letter.learned)/\(letter.total)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Text("Tippe auf einen Buchstaben, um seine Wörter zu sehen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusRows: some View {
        let groups = model.wordsByStatus
        if model.learnedCount == 0 && (groups[.upcoming]?.isEmpty ?? true) {
            EmptyVocabulary()
        }
        ForEach(WordStatus.overview) { status in
            if let words = groups[status], !words.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Circle().fill(status.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(status.rawValue) \(Text("\(words.count)").foregroundStyle(.secondary))")
                                .font(.headline)
                            Text(status.explanation).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        NavigationLink("Alle") { WordGroupView(status: status) }
                            .font(.subheadline.weight(.semibold))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(words.prefix(12)) { word in
                                WordTileLink(word: word).frame(width: 150)
                            }
                        }
                        .padding(.vertical, 4)
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        let groups = historyGroups
        if groups.isEmpty {
            EmptyVocabulary()
        }
        ForEach(groups.prefix(historyDays), id: \.day) { group in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.dayLabel(group.day)).font(.headline)
                    Spacer()
                    Text(group.words.count == 1 ? "1 Wort" : "\(group.words.count) Wörter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                FlowLayout(spacing: 8) {
                    ForEach(group.words) { word in
                        NavigationLink {
                            WordDetailView(word: word)
                        } label: {
                            WordChip(word: word, color: model.status(of: word).color)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .card()
        }
        if groups.count > historyDays {
            Button("Ältere Tage anzeigen") { historyDays += 14 }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }

    private var historyGroups: [(day: DayKey, words: [Word])] {
        let planned = model.progress.plannedDays
        var byDay: [DayKey: [Word]] = [:]
        for word in model.introducedWords {
            let day = planned[word.id] ?? DayKey(model.card(for: word)?.lastReview ?? Date())
            byDay[day, default: []].append(word)
        }
        return byDay.keys.sorted(by: >).map { (day: $0, words: byDay[$0] ?? []) }
    }
}

// MARK: - Components

/// Compact card for one word: Turkish, German with article colour, recall.
struct WordTile: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        let status = model.status(of: word)
        let card = model.card(for: word)
        VStack(alignment: .leading, spacing: 4) {
            Text(word.translation)
                .font(.title3.bold())
                .foregroundStyle(status == .notYet ? Color.secondary : Color.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.trailing, 12)
            ArticleWord(word: word, font: .subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let card {
                RecallBar(value: model.scheduler.retrievability(of: card, at: Date()))
            } else {
                Text(status.rawValue).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background {
            if status == .notYet {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle().fill(status.color).frame(width: 9, height: 9).padding(12)
        }
    }
}

struct WordTileLink: View {
    let word: Word

    var body: some View {
        NavigationLink {
            WordDetailView(word: word)
        } label: {
            WordTile(word: word)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct WordChip: View {
    let word: Word
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(word.translation).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text(word.native).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.35)))
    }
}

private struct EmptyVocabulary: View {
    var body: some View {
        ContentUnavailableView("Noch keine Wörter", systemImage: "books.vertical",
                               description: Text("Dein erstes Wort wartet im Tab „Heute“."))
    }
}

private let tileColumns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

/// All words of one letter: learned, planned and the rest of the dictionary.
struct LetterWordsView: View {
    @EnvironmentObject private var model: AppModel
    let letter: String
    @State private var showAll = false
    @State private var deck: CardDeck?

    var body: some View {
        let words = model.words(forLetter: letter)
        let learned = words.filter { model.card(for: $0) != nil }
            .sorted { $0.translation.localizedCompare($1.translation) == .orderedAscending }
        let planned = words.filter { model.status(of: $0) == .upcoming }
        let rest = words.filter { model.status(of: $0) == .notYet }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    ProgressRing(progress: Double(learned.count) / Double(max(1, words.count)), lineWidth: 9) {
                        Text(letter).font(.system(size: 30, weight: .heavy, design: .rounded))
                    }
                    .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buchstabe \(letter)").font(.title2.bold())
                        Text("\(learned.count) gelernt · \(planned.count) geplant · \(words.count) insgesamt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .card(padding: 18)

                if !learned.isEmpty {
                    Button {
                        deck = CardDeck(title: "Buchstabe \(letter)", words: learned)
                    } label: {
                        Label("Als Karteikarten üben", systemImage: "rectangle.stack.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                section("Gelernt", learned)
                section("Geplant", planned, hint: "Diese Wörter kommen in den nächsten Tagen.")
                if !rest.isEmpty {
                    let shown = showAll ? rest : Array(rest.prefix(12))
                    section("Noch nicht dran", shown, count: rest.count,
                            hint: "Tippe ein Wort an und wähle „Heute lernen“, wenn du es nicht abwarten willst.")
                    if shown.count < rest.count {
                        Button("Alle \(rest.count) anzeigen") { withAnimation { showAll = true } }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Buchstabe \(letter)")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $deck) { FlashcardBrowserView(deck: $0) }
    }

    @ViewBuilder
    private func section(_ title: String, _ words: [Word], count: Int? = nil, hint: String? = nil) -> some View {
        if !words.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(title) \(Text("\(count ?? words.count)").foregroundStyle(.secondary))").font(.headline)
                if let hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(words) { WordTileLink(word: $0) }
                }
            }
        }
    }
}

/// All words of one status with sorting.
struct WordGroupView: View {
    @EnvironmentObject private var model: AppModel
    let status: WordStatus
    @State private var sort: Sort = .recent
    @State private var deck: CardDeck?

    enum Sort: String, CaseIterable, Identifiable {
        case recent = "Zuletzt"
        case alphabetical = "A–Z"
        case weakest = "Schwächste"
        case frequent = "Häufigste"
        var id: String { rawValue }
    }

    private var words: [Word] {
        let words = model.wordsByStatus[status] ?? []
        switch sort {
        case .recent: return words
        case .alphabetical:
            return words.sorted { $0.translation.localizedCompare($1.translation) == .orderedAscending }
        case .weakest:
            let recall = { (word: Word) in
                model.card(for: word).map { model.scheduler.retrievability(of: $0, at: Date()) } ?? 2
            }
            return words.sorted { recall($0) < recall($1) }
        case .frequent: return words.sorted { $0.rank < $1.rank }
        }
    }

    var body: some View {
        let list = words
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Circle().fill(status.color).frame(width: 10, height: 10)
                    Text("\(list.count) Wörter · \(status.explanation)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Picker("Sortierung", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if status != .upcoming && !list.isEmpty {
                    Button {
                        deck = CardDeck(title: status.rawValue, words: list)
                    } label: {
                        Label("Als Karteikarten üben", systemImage: "rectangle.stack.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(list) { WordTileLink(word: $0) }
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(status.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $deck) { FlashcardBrowserView(deck: $0) }
    }
}

/// Search over the whole dictionary; learned words first.
private struct SearchResults: View {
    @EnvironmentObject private var model: AppModel
    let query: String

    var body: some View {
        let q = TurkishText.normalized(query)
        let folded = TurkishText.foldingDiacritics(q)
        let hits = model.words.bank.words.filter { word in
            TurkishText.normalized(word.nativeWithArticle).contains(q)
                || TurkishText.normalized(word.translation).contains(q)
                || TurkishText.foldingDiacritics(TurkishText.normalized(word.translation)).contains(folded)
                || word.alternatives.contains { TurkishText.normalized($0).contains(q) }
        }
        .sorted { lhs, rhs in
            let l = order(lhs), r = order(rhs)
            return l == r ? lhs.rank < rhs.rank : l < r
        }
        VStack(alignment: .leading, spacing: 10) {
            if hits.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                Text(hits.count > 60 ? "\(hits.count) Treffer – die ersten 60" : "\(hits.count) Treffer im Wörterbuch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(hits.prefix(60)) { WordTileLink(word: $0) }
                }
            }
        }
    }

    private func order(_ word: Word) -> Int {
        switch model.status(of: word) {
        case .notYet: return 2
        case .upcoming: return 1
        default: return 0
        }
    }
}

// MARK: - Flashcard browser

/// Swipe through words like a card stack; tap a card to turn it over.
struct FlashcardBrowserView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let title: String
    @State private var words: [Word]
    @State private var index = 0
    @State private var flipped = false

    init(deck: CardDeck) {
        title = deck.title
        _words = State(initialValue: deck.words)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    SessionProgressBar(progress: Double(index + 1) / Double(max(1, words.count)))
                    Text("\(index + 1)/\(words.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("Tippen zum Umdrehen, wischen zum Weiterblättern")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TabView(selection: $index) {
                    ForEach(Array(words.enumerated()), id: \.element.id) { offset, word in
                        FlipCard(word: word, flipped: offset == index && flipped,
                                 recall: model.card(for: word).map { model.scheduler.retrievability(of: $0, at: Date()) })
                            .padding(.horizontal, 4)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.5)) { flipped.toggle() }
                                if flipped { Speaker.shared.speak(word.translation, language: .turkish) }
                            }
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 460)
                .onChange(of: index) { _, _ in flipped = false }

                HStack(spacing: 16) {
                    roundButton("chevron.left", disabled: index == 0) { withAnimation { index -= 1 } }
                    Button {
                        if words.indices.contains(index) {
                            Speaker.shared.speak(words[index].translation, language: .turkish)
                        }
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Theme.sunrise, in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Vorlesen")
                    roundButton("shuffle", disabled: words.count < 2) {
                        withAnimation {
                            words.shuffle()
                            index = 0
                        }
                    }
                    roundButton("chevron.right", disabled: index >= words.count - 1) { withAnimation { index += 1 } }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .readableWidth()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Schließen")
                }
            }
        }
    }

    private func roundButton(_ systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .frame(width: 54, height: 54)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay(Circle().stroke(Color(.separator).opacity(0.5)))
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}

private struct FlipCard: View {
    let word: Word
    let flipped: Bool
    let recall: Double?

    var body: some View {
        ZStack {
            front
                .rotation3DEffect(.degrees(flipped ? -180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .opacity(flipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .opacity(flipped ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Doppeltippen zum Umdrehen")
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: 12) {
            Pill(text: "🇹🇷 Türkisch", color: .white)
            Text(word.translation)
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            if let recall {
                Text("Erinnerung \(recall.percentLabel)").opacity(0.85)
            }
            Spacer()
            Text("Was heißt das auf Deutsch?").opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.sunrise, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.red.opacity(0.3), radius: 14, y: 8)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 12) {
            Pill(text: "🇩🇪 Deutsch", color: Theme.red)
            ArticleWord(word: word, font: .system(size: 40, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            HighlightedSentence(cloze: word.cloze).font(.title3)
            Text(word.exampleNative).foregroundStyle(.secondary)
            if let note = word.note {
                Label(note, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.multicolor)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(.separator).opacity(0.5)))
    }
}
