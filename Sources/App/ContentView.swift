import SwiftUI

struct ContentView: View {
    @ObservedObject var weather: WeatherController
    @StateObject private var location = LocationProvider()
    @State private var locating = false
    @State private var pickingCity = false

    var body: some View {
        ZStack {
            Color(red: 0.16, green: 0.18, blue: 0.15)
                .ignoresSafeArea()

            if pickingCity {
                cityPicker
            } else if let snapshot = weather.snapshot {
                WeatherCard(
                    placeName: weather.place?.name ?? "Weather C+F",
                    snapshot: snapshot,
                    layout: .large,
                    onPlaceTap: { pickingCity = true }
                )
                .padding(.horizontal, 22)
                #if os(macOS)
                .padding(.top, 36)
                .padding(.bottom, 22)
                #else
                .padding(.vertical, 8)
                #endif
            } else if weather.isLoading || location.isLocating {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color(red: 0.97, green: 0.96, blue: 0.90))
                    Text("Finding your location…")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.97, green: 0.96, blue: 0.90).opacity(0.8))
                }
            } else {
                Button("Use current location") {
                    Task { await weather.useCurrentLocation(location) }
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 0.97, green: 0.96, blue: 0.90))
            }

            if let message = weather.errorMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 10)
                }
            }
        }
        .task {
            weather.start()
            await weather.useCurrentLocation(location)
        }
    }

    private var cityPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose a city")
                    .font(.headline)
                Spacer()
                Button("Done") { pickingCity = false }
                    .buttonStyle(.plain)
            }

            HStack {
                TextField("Search city", text: $weather.query)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit { weather.search() }
                Button("Search") { weather.search() }
                    .buttonStyle(.plain)
            }

            Button {
                Task { await useCurrentLocation() }
            } label: {
                Label(locating || location.isLocating ? "Locating…" : "Use current location", systemImage: "location.fill")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain)

            Text("Weather follows your live location. Search only if you want another city.")
                .font(.caption)
                .opacity(0.7)

            if !weather.searchResults.isEmpty {
                ForEach(weather.searchResults.prefix(5)) { result in
                    Button {
                        weather.select(result.asSaved)
                        pickingCity = false
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name).font(.subheadline.weight(.semibold))
                            if !result.detail.isEmpty {
                                Text(result.detail).font(.caption).opacity(0.7)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            FlexibleChips(cities: PopularCity.all) { city in
                weather.select(city)
                pickingCity = false
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .foregroundStyle(Color(red: 0.97, green: 0.96, blue: 0.90))
    }

    private func useCurrentLocation() async {
        locating = true
        defer { locating = false }
        await weather.useCurrentLocation(location)
        if weather.place != nil {
            pickingCity = false
        }
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
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private var rows: [[SavedPlace]] {
        stride(from: 0, to: cities.count, by: 3).map { start in
            Array(cities[start..<min(start + 3, cities.count)])
        }
    }
}
