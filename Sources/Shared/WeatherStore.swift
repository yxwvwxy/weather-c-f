import Foundation

enum AppGroup {
    static var suiteName: String {
        #if os(macOS)
        "group.com.weathercf.app"
        #else
        "group.com.weathercf.ios"
        #endif
    }
}

enum WeatherStore {
    private static let placeKey = "savedPlace"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.suiteName) ?? .standard
    }

    static var place: SavedPlace? {
        get {
            guard let data = defaults.data(forKey: placeKey) else { return nil }
            return try? JSONDecoder().decode(SavedPlace.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: placeKey)
            } else {
                defaults.removeObject(forKey: placeKey)
            }
        }
    }
}
