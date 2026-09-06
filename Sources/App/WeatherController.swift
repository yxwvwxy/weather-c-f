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
        guard let snapshot else { return "天气 C+F" }
        return "\(WeatherSnapshot.format(snapshot.celsius))°C  \(WeatherSnapshot.format(snapshot.fahrenheit))°F"
    }

    init() {
        place = WeatherStore.place
    }

    func start() {
        if place == nil {
            place = PopularCity.all.first
            WeatherStore.place = place
        }
        refresh()
        startTimer()
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
