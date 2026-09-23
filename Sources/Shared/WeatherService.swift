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
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "4")
        ]
        guard let url = components?.url else { throw WeatherError.invalidURL }

        let payload: ForecastPayload = try await decode(url)
        let timeZone = TimeZone(identifier: payload.timezone) ?? .current
        let current = payload.current
        let daily = payload.daily

        return WeatherSnapshot(
            celsius: current.temperature2m,
            feelsLikeC: current.apparentTemperature,
            humidity: current.relativeHumidity2m,
            windKmh: current.windSpeed10m,
            weatherCode: current.weatherCode,
            isDay: current.isDay == 1,
            highC: daily.temperature2mMax.first ?? current.temperature2m,
            lowC: daily.temperature2mMin.first ?? current.temperature2m,
            hourly: hourlyForecasts(payload: payload, timeZone: timeZone),
            daily: dailyForecasts(daily: daily, timeZone: timeZone),
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
            URLQueryItem(name: "language", value: "en"),
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

    private static func dailyForecasts(daily: ForecastPayload.Daily, timeZone: TimeZone) -> [DailyForecast] {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US")
        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.dateFormat = "EEE"

        let count = min(daily.time.count, daily.temperature2mMax.count, daily.temperature2mMin.count, daily.weatherCode.count)
        return (0..<count).map { index in
            let date = daily.time[index]
            let weekday: String
            if let parsed = parse(date, timeZone: timeZone) {
                weekday = weekdayFormatter.string(from: parsed)
            } else {
                weekday = date
            }
            return DailyForecast(
                date: date,
                weekday: weekday,
                highC: daily.temperature2mMax[index],
                lowC: daily.temperature2mMin[index],
                weatherCode: daily.weatherCode[index]
            )
        }
    }

    private static func hourlyForecasts(payload: ForecastPayload, timeZone: TimeZone) -> [HourlyForecast] {
        let hourly = payload.hourly
        let count = min(hourly.time.count, hourly.temperature2m.count, hourly.weatherCode.count, hourly.isDay.count)
        let hourFormatter = DateFormatter()
        hourFormatter.locale = Locale(identifier: "en_US")
        hourFormatter.timeZone = timeZone
        hourFormatter.dateFormat = "ha"

        let exactFormatter = DateFormatter()
        exactFormatter.locale = Locale(identifier: "en_US")
        exactFormatter.timeZone = timeZone
        exactFormatter.dateFormat = "h:mm"

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: Date())) ?? Date()

        var hours: [HourlyForecast] = []
        hours.reserveCapacity(count)
        for index in 0..<count {
            guard let time = parse(hourly.time[index], timeZone: timeZone), time >= start else { continue }
            hours.append(
                HourlyForecast(
                    time: time,
                    label: hourFormatter.string(from: time).replacingOccurrences(of: " ", with: ""),
                    celsius: hourly.temperature2m[index],
                    weatherCode: hourly.weatherCode[index],
                    isDay: hourly.isDay[index] == 1,
                    kind: .hour
                )
            )
        }

        let sunEvents = sunEvents(daily: payload.daily, hours: hours, timeZone: timeZone, formatter: exactFormatter)
        var items: [HourlyForecast] = []
        var eventIndex = 0
        for hour in hours {
            while eventIndex < sunEvents.count, sunEvents[eventIndex].time < hour.time {
                items.append(sunEvents[eventIndex])
                eventIndex += 1
                if items.count >= 6 { return items }
            }
            items.append(hour)
            if items.count >= 6 { break }
        }
        return items
    }

    private static func sunEvents(
        daily: ForecastPayload.Daily,
        hours: [HourlyForecast],
        timeZone: TimeZone,
        formatter: DateFormatter
    ) -> [HourlyForecast] {
        guard let first = hours.first?.time, let last = hours.dropFirst(5).first?.time ?? hours.last?.time else { return [] }
        let windowEnd = last.addingTimeInterval(60 * 60)
        var events: [HourlyForecast] = []

        func add(kind: HourlyKind, rawTimes: [String]?) {
            for raw in rawTimes ?? [] {
                guard let time = parse(raw, timeZone: timeZone), time > first, time < windowEnd else { continue }
                let nearest = hours.min(by: { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) })
                events.append(
                    HourlyForecast(
                        time: time,
                        label: formatter.string(from: time).replacingOccurrences(of: " ", with: ""),
                        celsius: nearest?.celsius ?? 0,
                        weatherCode: nearest?.weatherCode ?? 0,
                        isDay: kind == .sunset ? false : true,
                        kind: kind
                    )
                )
            }
        }

        add(kind: .sunrise, rawTimes: daily.sunrise)
        add(kind: .sunset, rawTimes: daily.sunset)
        return events.sorted { $0.time < $1.time }
    }

    private static func parse(_ string: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static func decode<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
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

    struct Hourly: Decodable {
        let time: [String]
        let temperature2m: [Double]
        let weatherCode: [Int]
        let isDay: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let weatherCode: [Int]
        let sunrise: [String]?
        let sunset: [String]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case weatherCode = "weather_code"
            case sunrise
            case sunset
        }
    }

    let timezone: String
    let current: Current
    let hourly: Hourly
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
