import AppIntents
import Foundation
import WidgetKit

struct CityEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "城市"
    static var defaultQuery = CityQuery()

    var id: String
    var name: String
    var detail: String
    var latitude: Double
    var longitude: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: detail)
        )
    }

    var place: SavedPlace {
        SavedPlace(name: name, detail: detail, latitude: latitude, longitude: longitude)
    }

    init(id: String, name: String, detail: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.detail = detail
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ place: SavedPlace) {
        self.init(id: place.id, name: place.name, detail: place.detail, latitude: place.latitude, longitude: place.longitude)
    }

    static let presets: [CityEntity] = PopularCity.all.map { CityEntity($0) }
}

struct CityQuery: EntityStringQuery {
    func entities(for identifiers: [CityEntity.ID]) async throws -> [CityEntity] {
        identifiers.compactMap { id in
            if let saved = WeatherStore.place, saved.id == id {
                return CityEntity(saved)
            }
            return CityEntity.presets.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [CityEntity] {
        var items = CityEntity.presets
        if let saved = WeatherStore.place {
            let current = CityEntity(saved)
            items.removeAll { $0.id == current.id }
            items.insert(current, at: 0)
        }
        return items
    }

    func entities(matching string: String) async throws -> [CityEntity] {
        let found = (try? await WeatherService.searchCities(string)) ?? []
        return found.map { CityEntity($0.asSaved) }
    }
}

struct WeatherWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "天气 C+F"
    static var description = IntentDescription("同时显示摄氏度和华氏度。")

    @Parameter(title: "城市")
    var city: CityEntity?

    func resolvedPlace() -> SavedPlace? {
        city?.place ?? WeatherStore.place
    }
}
