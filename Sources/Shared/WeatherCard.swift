import SwiftUI

enum WeatherCardLayout {
    case small
    case medium
    case large
}

struct WeatherCard: View {
    let placeName: String
    let snapshot: WeatherSnapshot
    var layout: WeatherCardLayout = .large
    var compact: Bool = false
    var onPlaceTap: (() -> Void)?

    var body: some View {
        Group {
            switch layout {
            case .small:
                small
            case .medium:
                medium
            case .large:
                large
            }
        }
        .foregroundStyle(Color(red: 0.97, green: 0.96, blue: 0.90))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            placeRow
            Text("\(WeatherSnapshot.format(snapshot.fahrenheit))°F")
                .font(.system(size: compact ? 38 : 56, weight: .thin, design: .rounded))
            Text("\(WeatherSnapshot.format(snapshot.celsius))°C")
                .font(compact ? .subheadline : .title3)
                .opacity(0.85)
            Spacer(minLength: 4)
            Text(snapshot.conditionLabel)
                .font(compact ? .caption.weight(.semibold) : .headline)
            highLow(alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            header
            hourlyRow(maxItems: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            header
            hourlyRow(maxItems: 6)
            dailyList
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                placeRow
                Text("\(WeatherSnapshot.format(snapshot.fahrenheit))°F")
                    .font(.system(size: compact ? 40 : 60, weight: .thin, design: .rounded))
                Text("\(WeatherSnapshot.format(snapshot.celsius))°C")
                    .font(compact ? .title3 : .title2)
                    .opacity(0.88)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: compact ? 4 : 6) {
                Text(snapshot.conditionLabel)
                    .font(compact ? .caption.weight(.semibold) : .headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                highLow(alignment: .trailing)
            }
        }
    }

    private var placeRow: some View {
        Button {
            onPlaceTap?()
        } label: {
            HStack(spacing: 4) {
                Text(placeName)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "location.fill")
                    .font(.system(size: compact ? 8 : 10))
                    .opacity(0.85)
            }
        }
        .buttonStyle(.plain)
        .disabled(onPlaceTap == nil)
    }

    private func highLow(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("H:\(WeatherSnapshot.format(snapshot.highF))°F  L:\(WeatherSnapshot.format(snapshot.lowF))°F")
                .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
            Text("H:\(WeatherSnapshot.format(snapshot.highC))°C  L:\(WeatherSnapshot.format(snapshot.lowC))°C")
                .font(compact ? .caption2 : .footnote)
                .opacity(0.7)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func hourlyRow(maxItems: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(snapshot.hourly.prefix(maxItems)) { hour in
                VStack(spacing: compact ? 4 : 6) {
                    Text(hour.label)
                        .font(.system(size: compact ? 10 : 13, weight: .semibold))
                        .opacity(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: icon(for: hour))
                        .font(.system(size: compact ? 14 : 18))
                        .symbolRenderingMode(.hierarchical)
                        .frame(height: compact ? 16 : 22)
                    Text("\(WeatherSnapshot.format(hour.fahrenheit))°F")
                        .font(.system(size: compact ? 12 : 16, weight: .semibold))
                    Text("\(WeatherSnapshot.format(hour.celsius))°C")
                        .font(.system(size: compact ? 10 : 13))
                        .opacity(0.65)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var dailyList: some View {
        let weekLow = snapshot.daily.map(\.lowC).min() ?? snapshot.lowC
        let weekHigh = snapshot.daily.map(\.highC).max() ?? snapshot.highC
        return VStack(spacing: compact ? 8 : 10) {
            ForEach(snapshot.daily.prefix(4)) { day in
                let dayLook = WeatherAppearance.resolve(code: day.weatherCode, isDay: true)
                HStack(spacing: compact ? 8 : 10) {
                    Text(shortWeekday(day.weekday))
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .frame(width: compact ? 30 : 40, alignment: .leading)
                    Image(systemName: dayLook.symbol)
                        .font(compact ? .caption : .body)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: compact ? 14 : 18)
                    dualTemp(lowC: day.lowC, high: false)
                    DayRangeBar(low: day.lowC, high: day.highC, weekLow: weekLow, weekHigh: weekHigh)
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 6 : 7)
                    dualTemp(lowC: day.highC, high: true)
                }
            }
        }
    }

    private func dualTemp(lowC value: Double, high: Bool) -> some View {
        let f = WeatherSnapshot.format(WeatherSnapshot.fahrenheit(from: value))
        let c = WeatherSnapshot.format(value)
        return VStack(alignment: high ? .leading : .trailing, spacing: 1) {
            Text("\(f)°F")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            Text("\(c)°C")
                .font(compact ? .system(size: 10) : .caption)
                .opacity(0.7)
        }
        .frame(width: compact ? 36 : 46, alignment: high ? .leading : .trailing)
    }

    private func shortWeekday(_ name: String) -> String {
        if name.count <= 3 { return name }
        return String(name.prefix(3))
    }

    private func icon(for hour: HourlyForecast) -> String {
        switch hour.kind {
        case .sunrise: return "sunrise.fill"
        case .sunset: return "sunset.fill"
        case .hour: return WeatherAppearance.resolve(code: hour.weatherCode, isDay: hour.isDay).symbol
        }
    }
}

struct DayRangeBar: View {
    let low: Double
    let high: Double
    let weekLow: Double
    let weekHigh: Double

    var body: some View {
        GeometryReader { geo in
            let span = max(weekHigh - weekLow, 1)
            let start = (low - weekLow) / span * geo.size.width
            let width = max((high - low) / span * geo.size.width, 8)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.78, blue: 0.95),
                                Color(red: 0.98, green: 0.86, blue: 0.45)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: min(width, geo.size.width))
                    .offset(x: min(max(start, 0), max(geo.size.width - 8, 0)))
            }
        }
        .frame(minHeight: 6)
    }
}
