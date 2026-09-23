import AppIntents
import SwiftUI
import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let place: SavedPlace?
    let snapshot: WeatherSnapshot?
}

struct WeatherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        sample
    }

    func snapshot(for configuration: WeatherWidgetIntent, in context: Context) async -> WeatherEntry {
        await entry(for: configuration) ?? sample
    }

    func timeline(for configuration: WeatherWidgetIntent, in context: Context) async -> Timeline<WeatherEntry> {
        let next = Date().addingTimeInterval(15 * 60)
        if let entry = await entry(for: configuration) {
            return Timeline(entries: [entry], policy: .after(next))
        }
        return Timeline(entries: [WeatherEntry(date: Date(), place: configuration.resolvedPlace(), snapshot: nil)], policy: .after(next))
    }

    private func entry(for configuration: WeatherWidgetIntent) async -> WeatherEntry? {
        guard let place = configuration.resolvedPlace() else { return nil }
        guard let snapshot = try? await WeatherService.forecast(for: place) else {
            return WeatherEntry(date: Date(), place: place, snapshot: nil)
        }
        return WeatherEntry(date: Date(), place: place, snapshot: snapshot)
    }

    private var sample: WeatherEntry {
        let now = Date()
        let hours: [HourlyForecast] = (0..<6).map { offset in
            let time = now.addingTimeInterval(TimeInterval(offset * 3600))
            return HourlyForecast(
                time: time,
                label: hourLabel(time),
                celsius: 20 - Double(offset),
                weatherCode: 3,
                isDay: true,
                kind: .hour
            )
        }
        let days: [DailyForecast] = [
            DailyForecast(date: "1", weekday: "Wed", highC: 20, lowC: 12, weatherCode: 3),
            DailyForecast(date: "2", weekday: "Thu", highC: 19, lowC: 10, weatherCode: 3),
            DailyForecast(date: "3", weekday: "Fri", highC: 23, lowC: 11, weatherCode: 2),
            DailyForecast(date: "4", weekday: "Sat", highC: 25, lowC: 14, weatherCode: 1)
        ]
        return WeatherEntry(
            date: now,
            place: PopularCity.all.first,
            snapshot: WeatherSnapshot(
                celsius: 20,
                feelsLikeC: 19,
                humidity: 48,
                windKmh: 12,
                weatherCode: 3,
                isDay: true,
                highC: 20,
                lowC: 12,
                hourly: hours,
                daily: days,
                updatedAt: now
            )
        )
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "ha"
        return formatter.string(from: date).replacingOccurrences(of: " ", with: "")
    }
}

struct WeatherCFWidget: Widget {
    let kind = "WeatherCFWidget.v8"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WeatherWidgetIntent.self, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .padding(16)
                .containerBackground(for: .widget) {
                    Color(red: 0.16, green: 0.18, blue: 0.15)
                }
        }
        .configurationDisplayName("Weather C+F")
        .description("See Fahrenheit next to Celsius.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WeatherEntry

    var body: some View {
        #if os(iOS)
        if family == .accessoryInline {
            Text(inlineText)
        } else if family == .accessoryRectangular {
            accessoryRectangular
        } else {
            card
        }
        #else
        card
        #endif
    }

    @ViewBuilder
    private var card: some View {
        if let snapshot = entry.snapshot {
            WeatherCard(
                placeName: entry.place?.name ?? "Weather C+F",
                snapshot: snapshot,
                layout: layout,
                compact: true
            )
        } else {
            Text(entry.place?.name ?? "Pick a city")
                .foregroundStyle(Color(red: 0.97, green: 0.96, blue: 0.90))
        }
    }

    private var layout: WeatherCardLayout {
        switch family {
        case .systemSmall:
            return .small
        case .systemMedium:
            return .medium
        default:
            return .large
        }
    }

    private var inlineText: String {
        guard let snapshot = entry.snapshot else {
            return entry.place?.name ?? "Weather C+F"
        }
        return "\(entry.place?.name ?? "") \(WeatherSnapshot.format(snapshot.fahrenheit))°F/\(WeatherSnapshot.format(snapshot.celsius))°C"
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.place?.name ?? "Weather C+F")
                .font(.headline)
            if let snapshot = entry.snapshot {
                Text("\(WeatherSnapshot.format(snapshot.fahrenheit))°F  \(WeatherSnapshot.format(snapshot.celsius))°C")
                    .font(.title3.weight(.semibold))
            } else {
                Text("Pick a city")
                    .font(.caption)
            }
        }
    }
}

@main
struct WeatherCFWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherCFWidget()
    }
}
