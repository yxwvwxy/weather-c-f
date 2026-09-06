import SwiftUI

@main
struct WeatherCFiOSApp: App {
    @ObservedObject private var weather = WeatherController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(weather: weather)
        }
    }
}
