import SwiftUI

struct ContentView: View {
    @ObservedObject var weather: WeatherController
    @StateObject private var location = LocationProvider()
    @State private var locating = false

    var body: some View {
        let look = WeatherAppearance.resolve(code: weather.snapshot?.weatherCode ?? 0, isDay: weather.snapshot?.isDay ?? true)
        let colors = WeatherAppearance.gradient(code: weather.snapshot?.weatherCode ?? 0, isDay: weather.snapshot?.isDay ?? true)

        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(look: look)
                    if let snapshot = weather.snapshot {
                        currentTemps(snapshot)
                        stats(snapshot)
                        forecast(snapshot)
                    } else if weather.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        Text("选择城市后即可同时看到摄氏度和华氏度")
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    if let message = weather.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    searchSection
                    #if os(macOS)
                    Button("放到桌面") {
                        NotificationCenter.default.post(name: .putWeatherOnDesktop, object: nil)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
                    #endif
                    instruction
                }
                .padding(20)
            }
        }
        .foregroundStyle(.white)
        .task {
            weather.start()
        }
    }

    private func header(look: WeatherAppearance) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(weather.place?.name ?? "天气 C+F")
                    .font(.title2.weight(.semibold))
                if let detail = weather.place?.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text(look.label)
                    .font(.headline)
            }
            Spacer()
            Button {
                weather.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .disabled(weather.isLoading)
        }
    }

    private func currentTemps(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(WeatherSnapshot.format(snapshot.celsius))°C")
                .font(.system(size: 64, weight: .thin, design: .rounded))
            Text("\(WeatherSnapshot.format(snapshot.fahrenheit))°F")
                .font(.system(size: 36, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func stats(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 10) {
            statBox(title: "体感", value: "\(WeatherSnapshot.format(snapshot.feelsLikeC))°C / \(WeatherSnapshot.format(snapshot.feelsLikeF))°F")
            statBox(title: "湿度", value: "\(snapshot.humidity)%")
            statBox(title: "风速", value: "\(WeatherSnapshot.format(snapshot.windKmh)) km/h")
        }
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func forecast(_ snapshot: WeatherSnapshot) -> some View {
        VStack(spacing: 8) {
            ForEach(snapshot.daily) { day in
                let look = WeatherAppearance.resolve(code: day.weatherCode, isDay: true)
                HStack {
                    Text(day.weekday)
                        .frame(width: 36, alignment: .leading)
                    Image(systemName: look.symbol)
                        .frame(width: 22)
                    Spacer()
                    Text("\(WeatherSnapshot.format(day.lowC))° / \(WeatherSnapshot.format(day.highC))°C")
                    Text("\(WeatherSnapshot.format(WeatherSnapshot.fahrenheit(from: day.lowC)))° / \(WeatherSnapshot.format(WeatherSnapshot.fahrenheit(from: day.highC)))°F")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .font(.subheadline)
            }
        }
        .padding(12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("搜索城市", text: $weather.query)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit { weather.search() }
                Button("搜索") { weather.search() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
            }

            Button {
                Task { await useCurrentLocation() }
            } label: {
                Label(locating || location.isLocating ? "正在定位…" : "使用当前位置", systemImage: "location.fill")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain)

            if !weather.searchResults.isEmpty {
                ForEach(weather.searchResults) { result in
                    Button {
                        weather.select(result.asSaved)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name).font(.subheadline.weight(.semibold))
                            if !result.detail.isEmpty {
                                Text(result.detail).font(.caption).foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            FlowCities(cities: PopularCity.all) { city in
                weather.select(city)
            }
        }
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("放到桌面 / 主屏幕")
                .font(.caption.weight(.semibold))
            #if os(macOS)
            Text("菜单栏选「放到桌面」，窗口会一直留在桌面上。也可以打开通知中心，把「天气 C+F」小组件拖到桌面。")
            #else
            Text("长按主屏幕空白处 → 左上角「编辑」→「添加小组件」→ 搜索「天气 C+F」。小组件上长按可以换城市。")
            #endif
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.78))
        .padding(.top, 4)
    }

    private func useCurrentLocation() async {
        locating = true
        defer { locating = false }
        do {
            let place = try await location.currentPlace()
            weather.applyCurrentLocation(place)
        } catch {
            weather.errorMessage = error.localizedDescription
        }
    }
}

private struct FlowCities: View {
    let cities: [SavedPlace]
    let onPick: (SavedPlace) -> Void

    var body: some View {
        FlexibleChips(cities: cities, onPick: onPick)
    }
}

private struct FlexibleChips: View {
    let cities: [SavedPlace]
    let onPick: (SavedPlace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row) { city in
                        Button(city.name) { onPick(city) }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                }
            }
        }
    }

    private var rows: [[SavedPlace]] {
        stride(from: 0, to: cities.count, by: 4).map { start in
            Array(cities[start..<min(start + 4, cities.count)])
        }
    }
}
