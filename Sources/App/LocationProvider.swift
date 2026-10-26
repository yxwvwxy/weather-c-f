import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published var isLocating = false
    @Published var lastError: String?
    @Published var place: SavedPlace?

    var onPlaceChange: ((SavedPlace) -> Void)?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var authorizationReady: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var sawAuthorizationCallback = false
    private var lastReported: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 300
    }

    func currentPlace() async throws -> SavedPlace {
        isLocating = true
        defer { isLocating = false }
        lastError = nil

        try await ensureAuthorized()
        let location = try await fetchLocation()
        let resolved = await reverseGeocode(location)
        place = resolved
        lastReported = location
        return resolved
    }

    func startMonitoring() {
        manager.distanceFilter = 300
        manager.startUpdatingLocation()
    }

    func stopMonitoring() {
        manager.stopUpdatingLocation()
    }

    /// Asks only while the app is in use, and only when the system has no saved choice yet.
    private func ensureAuthorized() async throws {
        switch await resolvedAuthorization() {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied, .restricted:
            throw WeatherError.locationDenied
        case .notDetermined:
            let status = await requestWhenInUse()
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                return
            case .denied, .restricted:
                throw WeatherError.locationDenied
            default:
                throw WeatherError.locationFailed
            }
        @unknown default:
            throw WeatherError.locationFailed
        }
    }

    /// macOS reports `.notDetermined` until the first authorization callback, even after a previous Allow.
    /// Wait for that callback so a later launch does not show the prompt again.
    private func resolvedAuthorization() async -> CLAuthorizationStatus {
        if sawAuthorizationCallback {
            return manager.authorizationStatus
        }
        return await withCheckedContinuation { continuation in
            authorizationReady = continuation
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let waiter = self.authorizationReady else { return }
                self.authorizationReady = nil
                self.sawAuthorizationCallback = true
                waiter.resume(returning: self.manager.authorizationStatus)
            }
        }
    }

    private func requestWhenInUse() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
            let immediate = manager.authorizationStatus
            if immediate != .notDetermined, let pending = authContinuation {
                authContinuation = nil
                pending.resume(returning: immediate)
            }
        }
    }

    private func fetchLocation() async throws -> CLLocation {
        if let cached = manager.location, cached.timestamp.timeIntervalSinceNow > -120 {
            return cached
        }

        return try await withCheckedThrowingContinuation { continuation in
            if let existing = locationContinuation {
                existing.resume(throwing: WeatherError.locationFailed)
            }
            locationContinuation = continuation
            manager.startUpdatingLocation()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let waiting = self.locationContinuation else { return }
                self.locationContinuation = nil
                self.manager.stopUpdatingLocation()
                waiting.resume(throwing: WeatherError.locationFailed)
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> SavedPlace {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "en")
        let mark: CLPlacemark? = await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { marks, _ in
                continuation.resume(returning: marks?.first)
            }
        }
        if let mark {
            let name = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea ?? "My Location"
            let detail = [mark.administrativeArea, mark.country]
                .compactMap { $0 }
                .filter { $0 != name }
                .joined(separator: " · ")
            return SavedPlace(name: name, detail: detail, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        return SavedPlace(
            name: "My Location",
            detail: "",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func applyIncomingLocation(_ location: CLLocation) {
        if let waiting = locationContinuation {
            locationContinuation = nil
            manager.stopUpdatingLocation()
            waiting.resume(returning: location)
            return
        }

        if let lastReported, location.distance(from: lastReported) < 300 {
            return
        }
        lastReported = location
        Task {
            let resolved = await reverseGeocode(location)
            place = resolved
            onPlaceChange?(resolved)
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            applyIncomingLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            return
        }
        Task { @MainActor in
            lastError = error.localizedDescription
            if let waiting = locationContinuation {
                locationContinuation = nil
                waiting.resume(throwing: WeatherError.locationFailed)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            sawAuthorizationCallback = true
            if let waiter = authorizationReady {
                authorizationReady = nil
                waiter.resume(returning: status)
            }
            if let pending = authContinuation {
                authContinuation = nil
                pending.resume(returning: status)
            }
        }
    }
}
