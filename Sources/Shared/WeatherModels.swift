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

struct WeatherSnapshot: Hashable {
    var celsius: Double
    var feelsLikeC: Double
    var humidity: Int
    var windKmh: Double
    var weatherCode: Int
    var isDay: Bool
    var highC: Double
    var lowC: Double
    var daily: [DailyForecast]
    var updatedAt: Date

    var fahrenheit: Double { Self.fahrenheit(from: celsius) }
    var feelsLikeF: Double { Self.fahrenheit(from: feelsLikeC) }
    var highF: Double { Self.fahrenheit(from: highC) }
    var lowF: Double { Self.fahrenheit(from: lowC) }

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
        case .invalidURL: return "天气地址无效。"
        case .badResponse: return "天气数据暂时无法获取。"
        case .noResults: return "没有找到这座城市。"
        case .locationDenied: return "没有位置权限，请在系统设置里允许，或手动搜索城市。"
        case .locationFailed: return "定位失败，请手动搜索城市。"
        }
    }
}
