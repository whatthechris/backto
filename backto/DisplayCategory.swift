import Foundation

private let categoryBaseTypes: Set<String> = [
    "restaurant", "cafe", "bar", "bakery", "store", "museum", "park", "night_club"
]
private let categorySkipTypes: Set<String> = [
    "establishment", "point_of_interest", "food", "health", "premise"
]

func resolvedDisplayCategory(types: [String], primaryTypeName: String?) -> String {
    // Prefer a specific sub-type (e.g. syrian_restaurant > restaurant)
    if let specific = types.first(where: { !categorySkipTypes.contains($0) && !categoryBaseTypes.contains($0) }) {
        return specific.replacingOccurrences(of: "_", with: " ").capitalized
    }
    // Fall back to the localized primary type display name
    if let label = primaryTypeName, !label.isEmpty { return label }
    // Final fallback from the types array
    return (types.first(where: { !categorySkipTypes.contains($0) }) ?? types.first ?? "place")
        .replacingOccurrences(of: "_", with: " ").capitalized
}
