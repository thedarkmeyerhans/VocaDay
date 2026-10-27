import CoreLocation
import Foundation
import VocaDayCore

/// Watches the learner's saved places. Entering one shows a new word on the
/// home screen widget. Uses CLMonitor, which also relaunches the app in the
/// background (needs "Always" location permission).
@MainActor
final class PlaceMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PlaceMonitor()

    @Published private(set) var authorization: CLAuthorizationStatus
    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    private var eventsTask: Task<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    var onEnter: (@MainActor (UUID) -> Void)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var canMonitor: Bool { authorization == .authorizedAlways }

    func requestPermission() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestAlwaysAuthorization()
        }
    }

    /// The current position, e.g. to save "Zuhause".
    func currentLocation() async -> CLLocation? {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        return await withCheckedContinuation { continuation in
            locationContinuation?.resume(returning: nil)
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Starts watching exactly the given places.
    func sync(places: [LearningPlace]) async {
        if monitor == nil {
            monitor = await CLMonitor("VocaDayPlaces")
            listen()
        }
        guard let monitor else { return }
        let wanted = Dictionary(uniqueKeysWithValues: places.map { ($0.id.uuidString, $0) })
        for identifier in await monitor.identifiers where wanted[identifier] == nil {
            await monitor.remove(identifier)
        }
        let existing = Set(await monitor.identifiers)
        for (identifier, place) in wanted where !existing.contains(identifier) {
            let condition = CLMonitor.CircularGeographicCondition(
                center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                radius: place.radius)
            await monitor.add(condition, identifier: identifier, assuming: .unsatisfied)
        }
    }

    private func listen() {
        eventsTask?.cancel()
        eventsTask = Task { [weak self] in
            guard let monitor = await self?.monitor else { return }
            do {
                for try await event in await monitor.events where event.state == .satisfied {
                    if let id = UUID(uuidString: event.identifier) {
                        self?.onEnter?(id)
                    }
                }
            } catch {
                print("Place monitoring stopped: \(error)")
            }
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse { self.manager.requestAlwaysAuthorization() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }
}
