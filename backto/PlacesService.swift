import Foundation
import CoreLocation

struct NearbyPlace: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let address: String
    let types: [String]
    let photoName: String?
    let primaryTypeName: String?
    let latitude: Double?
    let longitude: Double?

    func distance(from location: CLLocation) -> CLLocationDistance {
        guard let lat = latitude, let lon = longitude else { return .infinity }
        return location.distance(from: CLLocation(latitude: lat, longitude: lon))
    }

    var photoURL: URL? {
        photoName.flatMap { PlacesService.photoURL(name: $0, maxWidthPx: 1200) }
    }

    var displayCategory: String {
        resolvedDisplayCategory(types: types, primaryTypeName: primaryTypeName)
    }
}

enum PlacesService {
    static func searchNearby(location: CLLocation, radius: Double = 50) async throws -> [NearbyPlace] {
        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:searchNearby")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.googlePlacesAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "places.id,places.displayName,places.primaryTypeDisplayName,places.formattedAddress,places.types,places.photos,places.location",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        request.httpBody = try JSONEncoder().encode(
            NearbySearchRequest(location: location, radius: radius)
        )

        print("[PlacesService] Fetching nearby places (radius: \(radius)m)")
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(decoding: data, as: UTF8.self)
            throw PlacesError.apiError(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(NearbySearchResponse.self, from: data)
        let places = (decoded.places ?? []).map { p in
            NearbyPlace(
                id: p.id,
                name: p.displayName.text,
                address: p.formattedAddress ?? "",
                types: p.types ?? [],
                photoName: p.photos?.first?.name,
                primaryTypeName: p.primaryTypeDisplayName?.text,
                latitude: p.location?.latitude,
                longitude: p.location?.longitude
            )
        }
        return places
            .filter { $0.photoName != nil }
            .sorted { $0.distance(from: location) < $1.distance(from: location) }
    }

    static func photoURL(name: String, maxWidthPx: Int = 800) -> URL? {
        URL(string: "https://places.googleapis.com/v1/\(name)/media?maxWidthPx=\(maxWidthPx)&key=\(Config.googlePlacesAPIKey)")
    }
}

enum PlacesError: LocalizedError {
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body): "Places API error \(code): \(body)"
        }
    }
}

// MARK: - Request / Response models

private struct NearbySearchRequest: Encodable {
    let maxResultCount = 20
    let includedTypes: [String] = PlaceCategory.apiIncludedTypes
    let locationRestriction: LocationRestriction

    init(location: CLLocation, radius: Double) {
        locationRestriction = LocationRestriction(
            circle: Circle(
                center: LatLng(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ),
                radius: radius
            )
        )
    }

    struct LocationRestriction: Encodable {
        let circle: Circle
    }

    struct Circle: Encodable {
        let center: LatLng
        let radius: Double
    }

    struct LatLng: Encodable {
        let latitude: Double
        let longitude: Double
    }
}

private struct NearbySearchResponse: Decodable {
    let places: [PlaceResult]?
}

private struct PlaceResult: Decodable {
    let id: String
    let displayName: DisplayName
    let primaryTypeDisplayName: LocalizedText?
    let formattedAddress: String?
    let types: [String]?
    let photos: [PhotoReference]?
    let location: PlaceLocation?
}

private struct PlaceLocation: Decodable {
    let latitude: Double
    let longitude: Double
}

private struct PhotoReference: Decodable {
    let name: String
}

private struct DisplayName: Decodable {
    let text: String
}

private struct LocalizedText: Decodable {
    let text: String
}
