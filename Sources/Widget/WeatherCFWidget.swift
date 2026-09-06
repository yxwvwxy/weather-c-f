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
        WeatherEntry(
            date: Date(),
            place: PopularCity.all.first,
            snapshot: WeatherSnapshot(
                celsius: 22,
                feelsLikeC: 21,
                humidity: 48,
                windKmh: 10,
                weatherCode: 0,
                isDay: true,
                highC: 25,
                lowC: 17,
                daily: [],
                updatedAt: Date()
            )
        )
    }
}

struct WeatherCFWidget: Widget {
    let kind = "WeatherCFWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WeatherWidgetIntent.self, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    widgetBackground(for: entry)
                }
        }
        .configurationDisplayName("天气 C+F")
        .description("同时显示摄氏度和华氏度。")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }

    @ViewBuilder
    private func widgetBackground(for entry: WeatherEntry) -> some View {
        let colors = WeatherAppearance.gradient(code: entry.snapshot?.weatherCode ?? 1, isDay: entry.snapshot?.isDay ?? true)
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WeatherEntry

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            accessoryRectangular
        #endif
        case .systemSmall:
            small
        case .systemMedium:
            medium
        default:
            large
        }
    }

    private var look: WeatherAppearance {
        WeatherAppearance.resolve(code: entry.snapshot?.weatherCode ?? 0, isDay: entry.snapshot?.isDay ?? true)
    }

    private var inlineText: String {
        guard let snapshot = entry.snapshot else {
            return entry.place?.name ?? "天气 C+F"
        }
        return "\(entry.place?.name ?? "") \(WeatherSnapshot.format(snapshot.celsius))°C/\(WeatherSnapshot.format(snapshot.fahrenheit))°F"
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.place?.name ?? "天气 C+F")
                .font(.headline)
            if let snapshot = entry.snapshot {
                Text("\(WeatherSnapshot.format(snapshot.celsius))°C  \(WeatherSnapshot.format(snapshot.fahrenheit))°F")
                    .font(.title3.weight(.semibold))
                Text(look.label)
                    .font(.caption)
            } else {
                Text("打开 App 选择城市")
                    .font(.caption)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.place?.name ?? "天气")
                .font(.headline)
                .lineLimit(1)
            Image(systemName: look.symbol)
                .font(.title)
            if let snapshot = entry.snapshot {
                Text("\(WeatherSnapshot.format(snapshot.celsius))°C")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("\(WeatherSnapshot.format(snapshot.fahrenheit))°F")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text("选择城市")
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.place?.name ?? "天气 C+F")
                        .font(.headline)
                    Text(look.label)
                        .font(.subheadline)
                }
                Spacer()
                Image(systemName: look.symbol)
                    .font(.largeTitle)
            }
            if let snapshot = entry.snapshot {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(WeatherSnapshot.format(snapshot.celsius))°C")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                    Text("\(WeatherSnapshot.format(snapshot.fahrenheit))°F")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text("最高 \(WeatherSnapshot.format(snapshot.highC))°C / \(WeatherSnapshot.format(snapshot.highF))°F   最低 \(WeatherSnapshot.format(snapshot.lowC))°C / \(WeatherSnapshot.format(snapshot.lowF))°F")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text("长按小组件选择城市，或先在 App 里定位。")
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            medium
            if let snapshot = entry.snapshot {
                VStack(spacing: 6) {
                    ForEach(snapshot.daily.prefix(4)) { day in
                        let dayLook = WeatherAppearance.resolve(code: day.weatherCode, isDay: true)
                        HStack {
                            Text(day.weekday).frame(width: 32, alignment: .leading)
                            Image(systemName: dayLook.symbol)
                            Spacer()
                            Text("\(WeatherSnapshot.format(day.lowC))°/\(WeatherSnapshot.format(day.highC))°C")
                            Text("\(WeatherSnapshot.format(WeatherSnapshot.fahrenheit(from: day.lowC)))°/\(WeatherSnapshot.format(WeatherSnapshot.fahrenheit(from: day.highC)))°F")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .font(.caption)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }
}

@main
struct WeatherCFWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherCFWidget()
    }
}
