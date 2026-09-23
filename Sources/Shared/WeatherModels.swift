import Foundation

struct SavedPlace: Codable, Hashable, Identifiable {
    var id: String { "\(latitude),\(longitude)" }
    var name: String
    var detail: String
    var latitude: Double
    var longitude: Double

    var subtitle: String {
        detail.isEmpty ? name : "\(name) · \(detail)"
    }
}

struct DailyForecast: Hashable, Identifiable {
    var id: String { date }
    var date: String
    var weekday: String
    var highC: Double
    var lowC: Double
    var weatherCode: Int
}

enum HourlyKind: Hashable {
    case hour
    case sunset
    case sunrise
}

struct HourlyForecast: Hashable, Identifiable {
    var id: String { "\(Int(time.timeIntervalSince1970))-\(kind)" }
    var time: Date
    var label: String
    var celsius: Double
    var weatherCode: Int
    var isDay: Bool
    var kind: HourlyKind

    var fahrenheit: Double { WeatherSnapshot.fahrenheit(from: celsius) }
}

struct WeatherSnapshot: Hashable {
    var celsius: Double
    var feelsLikeC: Double
    var humidity: Int
    var windKmh: Double
    var weatherCode: Int
    var isDay: Bool
    var highC: Double
    var lowC: Double
    var hourly: [HourlyForecast]
    var daily: [DailyForecast]
    var updatedAt: Date

    var fahrenheit: Double { Self.fahrenheit(from: celsius) }
    var feelsLikeF: Double { Self.fahrenheit(from: feelsLikeC) }
    var highF: Double { Self.fahrenheit(from: highC) }
    var lowF: Double { Self.fahrenheit(from: lowC) }

    var conditionLabel: String {
        if windKmh >= 25 { return "Windy" }
        return WeatherAppearance.resolve(code: weatherCode, isDay: isDay).label
    }

    static func fahrenheit(from celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    static func format(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

struct GeoPlace: Hashable, Identifiable {
    var id: String { "\(latitude),\(longitude)" }
    var name: String
    var detail: String
    var latitude: Double
    var longitude: Double

    var asSaved: SavedPlace {
        SavedPlace(name: name, detail: detail, latitude: latitude, longitude: longitude)
    }
}

enum WeatherError: LocalizedError {
    case invalidURL
    case badResponse
    case noResults
    case locationDenied
    case locationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The weather URL is invalid."
        case .badResponse: return "Weather data is temporarily unavailable."
        case .noResults: return "No matching city was found."
        case .locationDenied: return "Location access is off. Allow it in Settings, or search for a city."
        case .locationFailed: return "Could not get your location. Search for a city instead."
        }
    }
}
