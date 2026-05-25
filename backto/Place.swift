import SwiftData
import Foundation

@Model
final class SavedPlace {
    var placeID: String
    var name: String
    var address: String
    var types: [String]
    var photoName: String?
    var primaryTypeName: String?
    var savedAt: Date

    init(placeID: String, name: String, address: String, types: [String], photoName: String? = nil, primaryTypeName: String? = nil) {
        self.placeID = placeID
        self.name = name
        self.address = address
        self.types = types
        self.photoName = photoName
        self.primaryTypeName = primaryTypeName
        self.savedAt = Date()
    }

    var photoURL: URL? {
        photoName.flatMap { PlacesService.photoURL(name: $0, maxWidthPx: 800) }
    }

    var mapsURL: URL {
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: name),
            URLQueryItem(name: "query_place_id", value: placeID)
        ]
        return components.url!
    }

    var displayCategory: String {
        resolvedDisplayCategory(types: types, primaryTypeName: primaryTypeName)
    }
}
