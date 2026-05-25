import Foundation

struct SharedPlace: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let savedAt: Date
    let photoURL: String?
}

enum SharedPlaceStore {
    private static let key = "recentPlaces"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.cwdigital.backto") ?? .standard
    }

    static func write(_ places: [SharedPlace]) {
        guard let data = try? JSONEncoder().encode(places) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> [SharedPlace] {
        guard let data = defaults.data(forKey: key),
              let places = try? JSONDecoder().decode([SharedPlace].self, from: data) else { return [] }
        return places
    }

    static func cachedImageURL(for placeID: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.cwdigital.backto")?
            .appendingPathComponent("widget_img_\(placeID).jpg")
    }
}
