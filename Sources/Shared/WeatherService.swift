import Foundation

enum WeatherService {
    private static let forecastBase = "https://api.open-meteo.com/v1/forecast"
    private static let geocodeBase = "https://geocoding-api.open-meteo.com/v1/search"

    static func forecast(for place: SavedPlace) async throws -> WeatherSnapshot {
        var components = URLComponents(string: forecastBase)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "5")
        ]
        guard let url = components?.url else { throw WeatherError.invalidURL }

        let payload: ForecastPayload = try await decode(url)
        let current = payload.current
        let daily = payload.daily
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        weekdayFormatter.dateFormat = "EEE"

        let iso = DateFormatter()
        iso.calendar = Calendar(identifier: .gregorian)
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"

        let days: [DailyForecast] = zip(zip(zip(daily.time, daily.temperature2mMax), daily.temperature2mMin), daily.weatherCode).map { pair in
            let date = pair.0.0.0
            let high = pair.0.0.1
            let low = pair.0.1
            let code = pair.1
            let weekday: String
            if let parsed = iso.date(from: date) {
                weekday = weekdayFormatter.string(from: parsed)
            } else {
                weekday = date
            }
            return DailyForecast(date: date, weekday: weekday, highC: high, lowC: low, weatherCode: code)
        }

        return WeatherSnapshot(
            celsius: current.temperature2m,
            feelsLikeC: current.apparentTemperature,
            humidity: current.relativeHumidity2m,
            windKmh: current.windSpeed10m,
            weatherCode: current.weatherCode,
            isDay: current.isDay == 1,
            highC: daily.temperature2mMax.first ?? current.temperature2m,
            lowC: daily.temperature2mMin.first ?? current.temperature2m,
            daily: days,
            updatedAt: Date()
        )
    }

    static func searchCities(_ query: String) async throws -> [GeoPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: geocodeBase)
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { throw WeatherError.invalidURL }

        let payload: GeocodePayload = try await decode(url)
        let results = payload.results ?? []
        if results.isEmpty { throw WeatherError.noResults }
        return results.map { item in
            let parts = [item.admin1, item.country].compactMap { $0 }.filter { !$0.isEmpty && $0 != item.name }
            return GeoPlace(
                name: item.name,
                detail: parts.joined(separator: " · "),
                latitude: item.latitude,
                longitude: item.longitude
            )
        }
    }

    private static func decode<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherError.badResponse
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

private struct ForecastPayload: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let apparentTemperature: Double
        let weatherCode: Int
        let relativeHumidity2m: Int
        let windSpeed10m: Double
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case relativeHumidity2m = "relative_humidity_2m"
            case windSpeed10m = "wind_speed_10m"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case weatherCode = "weather_code"
        }
    }

    let current: Current
    let daily: Daily
}

private struct GeocodePayload: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
    }

    let results: [Result]?
}
