import SwiftUI
import VocaDayCore
import WidgetKit

// MARK: - Timeline

struct WordEntry: TimelineEntry {
    let date: Date
    let content: WidgetSnapshot.Entry
    let streak: Int
    let repetitions: Int
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), content: .init(date: Date(), kind: .word, word: Self.sample, next: nil),
                  streak: 3, repetitions: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(entries(now: Date()).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let list = entries(now: Date())
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: list, policy: .after(min(list.last?.date ?? refresh, refresh))))
    }

    private func entries(now: Date) -> [WordEntry] {
        if let snapshot = Self.loadSnapshot() {
            let current = snapshot.entry(at: now)
            let upcoming = snapshot.entries.filter { $0.date > now }
            return ([current].compactMap { $0 } + upcoming).map { entry in
                WordEntry(date: max(entry.date, now), content: entry, streak: snapshot.streak,
                          repetitions: snapshot.repetitions)
            }
        }
        // Without shared data (e.g. app not opened yet): a frequent word of the day from the bundle.
        let word = Self.fallbackWord(for: now)
        return [WordEntry(date: now, content: .init(date: now, kind: .word, word: word, next: nil),
                          streak: 0, repetitions: 3)]
    }

    static func loadSnapshot() -> WidgetSnapshot? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
                .appendingPathComponent("widget.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func fallbackWord(for date: Date) -> WidgetSnapshot.WordInfo? {
        guard let url = Bundle.main.url(forResource: "words_de_tr", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? WordBank.decode(from: data), !bank.words.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let pool = bank.words.prefix(300)
        return WidgetSnapshot.WordInfo(pool[pool.startIndex + day % pool.count])
    }

    static let sample = WidgetSnapshot.WordInfo(
        Word(id: "haus", rank: 1, native: "Haus", article: "das", partOfSpeech: .noun, translation: "ev",
             exampleNative: "Unser Haus ist klein.", exampleTarget: "[Evimiz] küçük."))
}

// MARK: - Views

private let coral = Color(red: 1, green: 0.54, blue: 0.36)
private let red = Color(red: 0.88, green: 0.27, blue: 0.23)
private let sunrise = LinearGradient(colors: [coral, red], startPoint: .topLeading, endPoint: .bottomTrailing)

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryRectangular: rectangular
            case .accessoryCircular: circular
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(url)
    }

    private var url: URL? {
        if let word = entry.content.word, entry.content.kind == .word {
            return URL(string: "vocaday://widget?word=\(word.id)")
        }
        return URL(string: "vocaday://today")
    }

    private func time(_ date: Date?) -> String {
        date?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    // Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            content(large: false)
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { sunrise }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 0)
                content(large: true)
            }
            if entry.content.kind == .word, let word = entry.content.word {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.example).font(.subheadline.weight(.semibold)).lineLimit(3)
                    Text(word.exampleNative).font(.caption).opacity(0.85).lineLimit(2)
                    Spacer(minLength: 0)
                    Label("\(entry.repetitions)× richtig = geschafft", systemImage: "hand.tap.fill")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { sunrise }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
            Text("VocaDay").font(.caption.weight(.bold))
            Spacer()
            if entry.streak > 0 {
                Image(systemName: "flame.fill")
                Text("\(entry.streak)").font(.caption.weight(.bold))
            }
        }
        .font(.caption)
        .opacity(0.95)
    }

    @ViewBuilder
    private func content(large: Bool) -> some View {
        switch entry.content.kind {
        case .word:
            if let word = entry.content.word {
                Text(word.translation)
                    .font(.system(size: large ? 32 : 28, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(word.nativeWithArticle).font(.subheadline.weight(.medium)).opacity(0.9).lineLimit(1)
                if word.irregular {
                    Text("unregelmäßig").font(.caption2.weight(.bold)).opacity(0.85)
                }
            }
        case .done:
            Image(systemName: "checkmark.seal.fill").font(.title)
            Text("Geschafft!").font(.headline)
            if let next = entry.content.next {
                Text("Nächstes Wort \(time(next))").font(.caption).opacity(0.85)
            }
        case .waiting:
            Image(systemName: "sunrise.fill").font(.title)
            Text("Neues Wort").font(.headline)
            Text("um \(time(entry.content.next))").font(.caption).opacity(0.85)
        }
    }

    // Lock screen

    private var inline: some View {
        Group {
            if entry.content.kind == .word, let word = entry.content.word {
                Text("\(word.translation) – \(word.nativeWithArticle)")
            } else if entry.content.kind == .done {
                Text("VocaDay ✓ geschafft")
            } else {
                Text("Neues Wort um \(time(entry.content.next))")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.content.kind == .word, let word = entry.content.word {
                Text(word.translation).font(.headline).widgetAccentable()
                Text(word.nativeWithArticle).font(.caption)
                Text(word.example).font(.caption2).lineLimit(1).opacity(0.8)
            } else if entry.content.kind == .done {
                Label("Wort geschafft", systemImage: "checkmark.seal.fill").font(.headline)
                Text("Nächstes \(time(entry.content.next))").font(.caption)
            } else {
                Label("VocaDay", systemImage: "sunrise.fill").font(.headline)
                Text("Neues Wort um \(time(entry.content.next))").font(.caption)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.content.kind == .done {
                Image(systemName: "checkmark")
            } else if let word = entry.content.word {
                Text(word.translation).font(.caption2.weight(.bold)).minimumScaleFactor(0.5).padding(4)
            } else {
                Image(systemName: "sunrise.fill")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget

struct VocaDayWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VocaDayWord", provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Wort des Tages")
        .description("Zeigt zur eingestellten Uhrzeit oder an deinen Orten ein neues Wort. Antippen zum Lernen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct VocaDayWidgets: WidgetBundle {
    var body: some Widget {
        VocaDayWordWidget()
    }
}
