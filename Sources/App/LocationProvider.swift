import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published var isLocating = false
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentPlace() async throws -> SavedPlace {
        isLocating = true
        defer { isLocating = false }
        lastError = nil

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            throw WeatherError.locationDenied
        }

        do {
            let location = try await requestLocation()
            let name = await reverseGeocode(location)
            return name
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            if let existing = self.continuation {
                existing.resume(throwing: WeatherError.locationFailed)
            }
            self.continuation = continuation
            self.manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> SavedPlace {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "zh_CN")
        let mark: CLPlacemark? = await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { marks, _ in
                continuation.resume(returning: marks?.first)
            }
        }
        if let mark {
            let name = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea ?? "我的位置"
            let detail = [mark.administrativeArea, mark.country]
                .compactMap { $0 }
                .filter { $0 != name }
                .joined(separator: " · ")
            return SavedPlace(name: name, detail: detail, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        return SavedPlace(
            name: "我的位置",
            detail: "",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: WeatherError.locationFailed)
            continuation = nil
            lastError = error.localizedDescription
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Requested location is issued after the user answers the prompt.
    }
}
