import SwiftUI
import VocaDayCore

/// Zwangsmodus: one vocabulary question before the learner may use another app.
/// Correct → back to the app for a few minutes; wrong → the next word.
struct GateQuizView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let request: GateRequest

    @State private var word: Word?
    @State private var item: MasteryItem?
    @State private var showIntro = false
    @State private var unlocked = false
    @State private var round = 0
    @State private var wrongAnswers = 0
    @State private var returned = false

    var body: some View {
        NavigationStack {
            Group {
                if unlocked {
                    unlockedView
                } else if showIntro, let word {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Neues Wort – erst anschauen, dann kommt die Frage.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            IntroductionView(word: word) {
                                withAnimation { showIntro = false }
                            }
                        }
                        .padding()
                        .readableWidth()
                    }
                } else if let item {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            header
                            MasteryItemView(item: item, useChoices: model.settings.gateAnswerMode == .choice) { correct in
                                answered(correct)
                            }
                        }
                        .padding()
                        .readableWidth()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .id(round)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    ContentUnavailableView("Keine Vokabel verfügbar", systemImage: "lock.open",
                                           description: Text("Du kannst \(request.appName) direkt nutzen."))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Zwangsmodus")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(!unlocked && item != nil)
        .onAppear(perform: loadNext)
    }

    private var header: some View {
        HStack(spacing: 12) {
            GradientIcon(systemName: "lock.fill", color: Theme.coral, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Erst eine Vokabel, dann \(request.appName)").font(.headline)
                Text(wrongAnswers == 0
                     ? "Richtig = \(model.settings.gatePassMinutes) Min. frei"
                     : "Falsch – hier ist das nächste Wort")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card(padding: 14)
    }

    private var unlockedView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressRing(progress: 1, lineWidth: 14, colors: [Theme.correct, Theme.sentence]) {
                Image(systemName: "lock.open.fill").font(.system(size: 40, weight: .bold)).foregroundStyle(Theme.correct)
            }
            .frame(width: 130, height: 130)
            Text("Freigeschaltet!").font(.largeTitle.bold())
            Text("\(request.appName) ist jetzt \(model.settings.gatePassMinutes) Minuten frei.\nHeute sitzen schon \(model.gateKnownToday) Quiz-Wörter.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            if let url = request.returnURL {
                Button("Weiter zu \(request.appName)") { returnToApp(url) }
                .buttonStyle(PrimaryButtonStyle(color: Theme.correct))
            }
            Button("In VocaDay bleiben") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding()
        .readableWidth()
    }

    private func returnToApp(_ url: URL) {
        guard !returned else { return }
        returned = true
        dismiss()
        openURL(url)
    }

    private func loadNext() {
        guard let next = model.nextGateWord() else {
            word = nil
            item = nil
            return
        }
        word = next.word
        item = model.gateItem(for: next.word)
        showIntro = next.isNew
    }

    private func answered(_ correct: Bool) {
        guard let word else { return }
        model.answerGate(wordID: word.id, correct: correct)
        if correct {
            withAnimation(.spring) { unlocked = true }
            if let url = request.returnURL {
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    returnToApp(url)
                }
            }
        } else {
            wrongAnswers += 1
            withAnimation(.easeInOut(duration: 0.3)) {
                round += 1
                loadNext()
            }
        }
    }
}
