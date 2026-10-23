import SwiftUI
import VocaDayCore

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeSession: ActiveSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                wordsOfTheDay
                actions
                statistics
            }
            .padding()
            .readableWidth()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Heute")
        .fullScreenCover(item: $activeSession) { active in
            SessionView(active: active)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE"))))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(model.settings.pair.native.flag) → \(model.settings.pair.target.flag)  \(model.settings.pair.target.displayName)")
                    .font(.headline)
            }
            Spacer()
            Label("\(model.streak)", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(model.streak > 0 ? Color.orange : Color.secondary)
                .accessibilityLabel("\(model.streak) Tage in Folge")
            Text(model.nextLetter)
                .font(.title2.bold())
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Aktueller Buchstabe \(model.nextLetter)")
        }
    }

    @ViewBuilder
    private var wordsOfTheDay: some View {
        let words = model.todaysWords
        VStack(alignment: .leading, spacing: 12) {
            Text(words.count == 1 ? "Dein Wort des Tages" : "Deine Wörter für heute")
                .font(.title2.bold())
            if words.isEmpty {
                Text("Du hast alle Wörter der Datenbank geplant – stark! Wiederhole sie weiter, damit sie sitzen.")
                    .foregroundStyle(.secondary)
                    .card()
            }
            ForEach(words) { word in
                NavigationLink {
                    WordDetailView(word: word)
                } label: {
                    WordOfTheDayCard(word: word, isLearned: model.progress.isIntroduced(word.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if model.hasWorkToday {
                Button {
                    activeSession = model.makeDailySession()
                } label: {
                    VStack(spacing: 4) {
                        Text(model.pendingNewWords.isEmpty ? "Wiederholen" : "Jetzt lernen")
                        Text(workSummary).font(.subheadline).opacity(0.9)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Label("Für heute ist alles erledigt!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .card()
            }
            HStack(spacing: 12) {
                Button {
                    model.addExtraWord()
                } label: {
                    Label("Noch ein Wort", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    activeSession = model.makeSentenceSession()
                } label: {
                    Label("Satztrainer", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.learnedCount == 0)
            }
        }
    }

    private var workSummary: String {
        var parts: [String] = []
        let new = model.pendingNewWords.count
        if new > 0 { parts.append(new == 1 ? "1 neues Wort" : "\(new) neue Wörter") }
        let due = model.dueCount
        if due > 0 { parts.append(due == 1 ? "1 Wiederholung" : "\(due) Wiederholungen") }
        return parts.joined(separator: " · ")
    }

    private var statistics: some View {
        HStack(spacing: 12) {
            StatTile(value: model.learnedCount, label: "gelernt", systemImage: "book")
            StatTile(value: model.matureCount, label: "gefestigt", systemImage: "brain.head.profile")
            StatTile(value: model.reviewsToday, label: "heute geübt", systemImage: "checkmark.circle")
        }
    }
}

struct WordOfTheDayCard: View {
    let word: Word
    let isLearned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.translation)
                        .font(.largeTitle.bold())
                    Text(word.nativeWithArticle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SpeakButton(text: word.translation)
            }
            HighlightedSentence(cloze: word.cloze)
                .font(.body)
            Text(word.exampleNative)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(word.partOfSpeech.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                Spacer()
                if isLearned {
                    Label("gelernt", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .card(padding: 20)
    }
}

struct StatTile: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text("\(value)")
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 12)
    }
}
