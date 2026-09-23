import SwiftUI

struct WeatherAppearance {
    let symbol: String
    let label: String

    static func resolve(code: Int, isDay: Bool = true) -> WeatherAppearance {
        switch code {
        case 0:
            return WeatherAppearance(symbol: isDay ? "sun.max.fill" : "moon.stars.fill", label: "Clear")
        case 1:
            return WeatherAppearance(symbol: isDay ? "sun.min.fill" : "moon.fill", label: "Mostly clear")
        case 2:
            return WeatherAppearance(symbol: isDay ? "cloud.sun.fill" : "cloud.moon.fill", label: "Partly cloudy")
        case 3:
            return WeatherAppearance(symbol: "cloud.fill", label: "Overcast")
        case 45, 48:
            return WeatherAppearance(symbol: "cloud.fog.fill", label: "Fog")
        case 51, 53, 55:
            return WeatherAppearance(symbol: "cloud.drizzle.fill", label: "Drizzle")
        case 56, 57:
            return WeatherAppearance(symbol: "cloud.sleet.fill", label: "Freezing drizzle")
        case 61, 63:
            return WeatherAppearance(symbol: "cloud.rain.fill", label: "Rain")
        case 65:
            return WeatherAppearance(symbol: "cloud.heavyrain.fill", label: "Heavy rain")
        case 66, 67:
            return WeatherAppearance(symbol: "cloud.sleet.fill", label: "Freezing rain")
        case 71, 73:
            return WeatherAppearance(symbol: "cloud.snow.fill", label: "Snow")
        case 75, 77:
            return WeatherAppearance(symbol: "snowflake", label: "Heavy snow")
        case 80, 81:
            return WeatherAppearance(symbol: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill", label: "Showers")
        case 82:
            return WeatherAppearance(symbol: "cloud.heavyrain.fill", label: "Heavy showers")
        case 85, 86:
            return WeatherAppearance(symbol: "cloud.snow.fill", label: "Snow showers")
        case 95:
            return WeatherAppearance(symbol: "cloud.bolt.rain.fill", label: "Thunderstorm")
        case 96, 99:
            return WeatherAppearance(symbol: "cloud.bolt.rain.fill", label: "Thunderstorm with hail")
        default:
            return WeatherAppearance(symbol: "cloud.fill", label: "Weather")
        }
    }

    static func gradient(code: Int, isDay: Bool) -> [Color] {
        switch code {
        case 0, 1:
            return isDay
                ? [Color(red: 0.31, green: 0.62, blue: 0.96), Color(red: 0.18, green: 0.38, blue: 0.78)]
                : [Color(red: 0.12, green: 0.16, blue: 0.38), Color(red: 0.05, green: 0.07, blue: 0.18)]
        case 2:
            return isDay
                ? [Color(red: 0.45, green: 0.68, blue: 0.90), Color(red: 0.28, green: 0.45, blue: 0.70)]
                : [Color(red: 0.18, green: 0.22, blue: 0.38), Color(red: 0.08, green: 0.10, blue: 0.20)]
        case 45, 48, 3:
            return [Color(red: 0.45, green: 0.50, blue: 0.58), Color(red: 0.28, green: 0.32, blue: 0.38)]
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return [Color(red: 0.28, green: 0.38, blue: 0.50), Color(red: 0.14, green: 0.20, blue: 0.30)]
        case 71, 73, 75, 77, 85, 86:
            return [Color(red: 0.62, green: 0.74, blue: 0.86), Color(red: 0.38, green: 0.50, blue: 0.64)]
        case 95, 96, 99:
            return [Color(red: 0.22, green: 0.20, blue: 0.38), Color(red: 0.10, green: 0.08, blue: 0.18)]
        default:
            return [Color(red: 0.35, green: 0.55, blue: 0.82), Color(red: 0.20, green: 0.34, blue: 0.62)]
        }
    }
}

enum PopularCity {
    static let all: [SavedPlace] = [
        SavedPlace(name: "Beijing", detail: "China", latitude: 39.9042, longitude: 116.4074),
        SavedPlace(name: "Shanghai", detail: "China", latitude: 31.2304, longitude: 121.4737),
        SavedPlace(name: "Hong Kong", detail: "China", latitude: 22.3193, longitude: 114.1694),
        SavedPlace(name: "Taipei", detail: "Taiwan", latitude: 25.0330, longitude: 121.5654),
        SavedPlace(name: "New York", detail: "United States", latitude: 40.7128, longitude: -74.0060),
        SavedPlace(name: "San Francisco", detail: "United States", latitude: 37.7749, longitude: -122.4194),
        SavedPlace(name: "Los Angeles", detail: "United States", latitude: 34.0522, longitude: -118.2437),
        SavedPlace(name: "London", detail: "United Kingdom", latitude: 51.5072, longitude: -0.1276),
        SavedPlace(name: "Paris", detail: "France", latitude: 48.8566, longitude: 2.3522),
        SavedPlace(name: "Tokyo", detail: "Japan", latitude: 35.6762, longitude: 139.6503),
        SavedPlace(name: "Singapore", detail: "Singapore", latitude: 1.3521, longitude: 103.8198),
        SavedPlace(name: "Sydney", detail: "Australia", latitude: -33.8688, longitude: 151.2093)
    ]
}
