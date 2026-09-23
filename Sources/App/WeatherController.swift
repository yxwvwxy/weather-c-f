import Combine
import Foundation
import WidgetKit

@MainActor
final class WeatherController: ObservableObject {
    static let shared = WeatherController()

    @Published var place: SavedPlace?
    @Published var snapshot: WeatherSnapshot?
    @Published var query = ""
    @Published var searchResults: [GeoPlace] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var refreshTask: Task<Void, Never>?

    var statusTitle: String {
        guard let snapshot else { return "Weather C+F" }
        return "\(WeatherSnapshot.format(snapshot.celsius))°C  \(WeatherSnapshot.format(snapshot.fahrenheit))°F"
    }

    init() {
        place = Self.englishPlace(WeatherStore.place)
    }

    func start() {
        startTimer()
        if place != nil {
            refresh()
        }
    }

    func useCurrentLocation(_ provider: LocationProvider) async {
        isLoading = true
        errorMessage = nil
        do {
            let current = try await provider.currentPlace()
            select(current)
            provider.onPlaceChange = { [weak self] place in
                self?.select(place)
            }
            provider.startMonitoring()
        } catch {
            errorMessage = error.localizedDescription
            if place != nil {
                refresh()
            }
            isLoading = false
        }
    }

    private static func englishPlace(_ place: SavedPlace?) -> SavedPlace? {
        guard let place else { return nil }
        return PopularCity.all.first { $0.id == place.id } ?? place
    }

    func refresh() {
        guard let place else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let weather = try await WeatherService.forecast(for: place)
                self.snapshot = weather
                self.errorMessage = nil
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func select(_ place: SavedPlace) {
        self.place = place
        WeatherStore.place = place
        searchResults = []
        query = ""
        refresh()
    }

    func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                searchResults = try await WeatherService.searchCities(text)
            } catch {
                searchResults = []
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    func applyCurrentLocation(_ place: SavedPlace) {
        select(place)
    }

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
                if Task.isCancelled { break }
                refresh()
            }
        }
    }
}
