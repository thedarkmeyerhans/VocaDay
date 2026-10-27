import Foundation
import VocaDayCore
import WidgetKit

/// Shares what the home screen widget shows through the app group container.
enum WidgetBridge {
    static let fileName = "widget.json"

    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String
    }

    static var snapshotURL: URL? {
        guard let groupID,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        else { return nil }
        return container.appendingPathComponent(fileName)
    }

    @MainActor
    static func update(model: AppModel) {
        let snapshot = WidgetPlanner.snapshot(progress: model.progress, words: model.words, now: Date())
        if let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: [.atomic])
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
