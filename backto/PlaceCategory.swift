import Foundation
import SwiftUI
import UIKit

extension Color {
    func darkened(by amount: Double = 0.5) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(UIColor(hue: h, saturation: s, brightness: b * CGFloat(1 - amount), alpha: a))
    }
}

enum PlaceCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case restaurants = "Restaurants"
    case cafes = "Cafes"
    case bakeries = "Bakeries"
    case bars = "Bars"
    case shops = "Shops"
    case museumsAndGalleries = "Museums & Galleries"

    var id: String { rawValue }

    static func matching(types: [String]) -> PlaceCategory {
        PlaceCategory.allCases.first { $0 != .all && $0.matches(types: types) } ?? .all
    }

    static func allMatching(types: [String]) -> [PlaceCategory] {
        PlaceCategory.allCases.filter { $0 != .all && $0.matches(types: types) }
    }

    var color: Color {
        switch self {
        case .all:                return .accentColor
        case .restaurants:        return .orange
        case .cafes:              return .brown
        case .bakeries:           return Color(red: 0.85, green: 0.55, blue: 0.25)
        case .bars:               return .purple
        case .shops:              return .teal
        case .museumsAndGalleries: return .indigo
        }
    }

    func matches(types: [String]) -> Bool {
        let set = Set(types)
        switch self {
        case .all:
            return true
        case .restaurants:
            return !set.isDisjoint(with: [
                "restaurant", "fast_food_restaurant", "meal_takeaway", "meal_delivery", "ramen_restaurant"
            ])
        case .cafes:
            return !set.isDisjoint(with: ["cafe", "coffee_shop"])
        case .bakeries:
            return !set.isDisjoint(with: ["bakery"])
        case .bars:
            return !set.isDisjoint(with: [
                "bar", "night_club", "pub"
            ])
        case .shops:
            return !set.isDisjoint(with: [
                "store", "shopping_mall", "supermarket", "convenience_store",
                "clothing_store", "book_store", "shoe_store", "jewelry_store",
                "home_goods_store", "electronics_store", "florist", "gift_shop",
                "grocery_store", "department_store", "hardware_store",
                "pet_store", "furniture_store", "bicycle_store", "general_store"
            ])
        case .museumsAndGalleries:
            return !set.isDisjoint(with: ["museum", "art_gallery"])
        }
    }

    static let apiIncludedTypes: [String] = [
        // Restaurants
        "restaurant", "fast_food_restaurant", "meal_takeaway", "meal_delivery","ramen_restaurant",
        // Cafes
        "cafe", "coffee_shop",
        // Bakeries
        "bakery",
        // Bars
        "bar", "night_club", "pub",
        // Shops
        "store", "shopping_mall", "supermarket", "convenience_store",
        "clothing_store", "book_store", "shoe_store", "jewelry_store",
        "home_goods_store", "electronics_store", "florist", "gift_shop",
        "grocery_store", "department_store", "hardware_store",
        "pet_store", "furniture_store", "bicycle_store", "general_store",
        // Museums & Galleries
        "museum", "art_gallery",
    ]
}
