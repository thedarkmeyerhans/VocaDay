import SwiftUI
import VocaDayCore

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var activeSession: ActiveSession?
    @State private var showTestSetup = false
    @State private var addedWord: Word?
    @State private var mastery: ActiveMastery?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                WeekStrip(days: model.currentWeek, streak: model.streak)
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        wordsOfTheDay.frame(maxWidth: .infinity)
                        VStack(spacing: 20) {
                            goalCard
                            quickActions
                        }
                        .frame(maxWidth: 360)
                    }
                } else {
                    wordsOfTheDay
                    goalCard
                    quickActions
                }
                AlphabetStrip(letters: model.statistics.letters, current: model.nextLetter)
            }
            .padding()
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Heute")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeSession) { active in
            SessionView(active: active)
        }
        .sheet(isPresented: $showTestSetup) {
            TestSetupView()
        }
        .fullScreenCover(item: $mastery) { MasteryPracticeView(active: $0) }
    }

    // MARK: Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return "Günaydın!"
        case 11..<18: return "İyi günler!"
        default: return "İyi akşamlar!"
        }
    }

    private var greetingTranslation: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return "Guten Morgen"
        case 11..<18: return "Guten Tag"
        default: return "Guten Abend"
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)
                    .locale(Locale(identifier: "de_DE"))).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(greeting)
                    .font(.largeTitle.bold())
                Text("\(greetingTranslation) · \(model.settings.pair.native.flag) → \(model.settings.pair.target.flag)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Speaker.shared.speak(greeting, language: .turkish)
            } label: {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.sun)
                    .shadow(color: Theme.sun.opacity(0.6), radius: 10)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Begrüßung vorlesen")
        }
    }

    // MARK: Words of the day

    @ViewBuilder
    private var wordsOfTheDay: some View {
        let words = model.todaysWords
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: words.count > 1 ? "Deine Wörter für heute" : "Dein Wort des Tages",
                         subtitle: "Buchstabe \(model.nextLetter) · aus den häufigsten Wörtern")
            if words.isEmpty {
                Text("Du hast alle Wörter der Datenbank geplant – stark! Wiederhole sie weiter, damit sie sitzen.")
                    .foregroundStyle(.secondary)
                    .card()
            }
            ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                NavigationLink {
                    WordDetailView(word: word)
                } label: {
                    if index == 0 {
                        HeroWordCard(word: word, isLearned: model.progress.isIntroduced(word.id))
                    } else {
                        CompactWordCard(word: word, isLearned: model.progress.isIntroduced(word.id))
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Daily goal

    private var goalCard: some View {
        HStack(spacing: 18) {
            ProgressRing(progress: model.hasWorkToday ? model.todayProgress : 1, lineWidth: 11) {
                VStack(spacing: 0) {
                    if model.hasWorkToday {
                        Text(model.todayProgress.percentLabel)
                            .font(.headline.monospacedDigit())
                    } else {
                        Image(systemName: "checkmark")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.correct)
                    }
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 10) {
                Text(model.hasWorkToday ? "Tagesziel" : "Alles erledigt!")
                    .font(.headline)
                Text(model.hasWorkToday ? workSummary : "Deine Wörter sind für heute versorgt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if model.hasWorkToday {
                    Button {
                        activeSession = model.makeDailySession()
                    } label: {
                        Label(model.pendingNewWords.isEmpty ? "Wiederholen" : "Jetzt lernen", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .card(padding: 18)
    }

    private var workSummary: String {
        var parts: [String] = []
        let new = model.pendingNewWords.count
        if new > 0 { parts.append(new == 1 ? "1 neues Wort" : "\(new) neue Wörter") }
        let due = model.dueCount
        if due > 0 { parts.append(due == 1 ? "1 Wiederholung" : "\(due) Wiederholungen") }
        return parts.joined(separator: " · ")
    }

    // MARK: Quick actions

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            QuickAction(title: "Noch ein Wort", subtitle: addedWord.map { "+ \($0.translation)" } ?? "zusätzlich lernen",
                        systemImage: "plus", color: Theme.coral) {
                withAnimation(.spring) { addedWord = model.addExtraWord() }
                haptic(true)
            }
            QuickAction(title: "Satztrainer", subtitle: "Wörter im Satz",
                        systemImage: "text.bubble.fill", color: Theme.sentence) {
                activeSession = model.makeSentenceSession()
            }
            .disabled(model.learnedCount == 0)
            QuickAction(title: "Wortschatz-Test", subtitle: "alle Wörter prüfen",
                        systemImage: "checklist", color: Theme.test) {
                showTestSetup = true
            }
            .disabled(model.learnedCount == 0)
            QuickAction(title: "Festigen", subtitle: "bis es sitzt",
                        systemImage: "dumbbell.fill", color: Theme.practice) {
                mastery = model.makeConsolidation()
            }
            .disabled(model.learnedCount == 0)
        }
    }
}

// MARK: - Components

struct HeroWordCard: View {
    let word: Word
    let isLearned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Pill(text: word.partOfSpeech.displayName, color: .white)
                if isLearned {
                    Pill(text: "gelernt", systemImage: "checkmark", color: .white)
                }
                IrregularBadge(word: word, onDark: true)
                Spacer()
                SpeakButton(text: word.translation, tint: .white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(word.translation)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(word.nativeWithArticle)
                    .font(.title2.weight(.medium))
                    .opacity(0.9)
            }
            Divider().overlay(.white.opacity(0.4))
            VStack(alignment: .leading, spacing: 4) {
                HighlightedSentence(cloze: word.cloze, highlight: Theme.sun)
                    .font(.body.weight(.medium))
                Text(word.exampleNative)
                    .font(.subheadline)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                Theme.sunrise
                Circle()
                    .fill(Theme.sun.opacity(0.35))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                    .offset(x: 50, y: -60)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.red.opacity(0.35), radius: 16, y: 10)
    }
}

struct CompactWordCard: View {
    let word: Word
    let isLearned: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(String(word.native.prefix(1)).uppercased())
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.sunrise, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(word.translation).font(.title3.bold())
                ArticleWord(word: word, font: .subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLearned {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.correct)
            }
            SpeakButton(text: word.translation)
        }
        .foregroundStyle(.primary)
        .card(padding: 14)
    }
}

struct WeekStrip: View {
    let days: [WeekDay]
    let streak: Int

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEEEE"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(streak > 0 ? AnyShapeStyle(LinearGradient(colors: [Theme.sun, Theme.streak],
                                                                               startPoint: .top, endPoint: .bottom))
                                                : AnyShapeStyle(Color.secondary))
                    .symbolEffect(.bounce, value: streak)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(streak)").font(.title2.bold().monospacedDigit())
                    Text(streak == 1 ? "Tag" : "Tage").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 70, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(streak) Tage in Folge")

            ForEach(days) { entry in
                VStack(spacing: 6) {
                    Text(Self.formatter.string(from: entry.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(entry.isToday ? Theme.red : .secondary)
                    ZStack {
                        Circle()
                            .fill(entry.active ? AnyShapeStyle(Theme.sunrise) : AnyShapeStyle(Color(.tertiarySystemFill)))
                        if entry.active {
                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                        }
                        if entry.isToday && !entry.active {
                            Circle().stroke(Theme.red, lineWidth: 2)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .card(padding: 14)
    }
}

struct QuickAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                GradientIcon(systemName: systemImage, color: color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .card(padding: 14)
        }
        .buttonStyle(PressableStyle())
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The A–Z rotation: how far each letter is learned, current letter highlighted.
struct AlphabetStrip: View {
    let letters: [LearningStatistics.LetterProgress]
    let current: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Dein Alphabet", subtitle: "Jeden Tag der nächste Buchstabe – reihum von A bis Z")
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(letters) { letter in
                            VStack(spacing: 6) {
                                ProgressRing(progress: letter.fraction, lineWidth: 4,
                                             colors: letter.letter == current ? [Theme.coral, Theme.red]
                                                : [Theme.review, Theme.test]) {
                                    Text(letter.letter)
                                        .font(.headline)
                                        .foregroundStyle(letter.letter == current ? Theme.red : .primary)
                                }
                                .frame(width: 44, height: 44)
                                Text("\(letter.learned)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .background(letter.letter == current ? Theme.red.opacity(0.1) : .clear,
                                        in: RoundedRectangle(cornerRadius: 14))
                            .id(letter.letter)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onAppear { proxy.scrollTo(current, anchor: .center) }
            }
        }
        .card()
    }
}
