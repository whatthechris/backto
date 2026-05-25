import SwiftUI
import SwiftData
import WidgetKit

struct SavedPlacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.savedAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @State private var groups: [PlaceDateGroup] = []

    var body: some View {
        NavigationStack {
            Group {
                if savedPlaces.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Saved Places").font(.headline)
                        Text("Tap the bookmark on any nearby place to save it here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(groups) { group in
                            Section(group.sectionTitle) {
                                ForEach(group.places) { place in
                                    SavedPlaceRow(place: place)
                                }
                                .onDelete { offsets in
                                    for i in offsets { modelContext.delete(group.places[i]) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                if !savedPlaces.isEmpty { EditButton() }
            }
        }
        .onChange(of: savedPlaces, initial: true) { _, newPlaces in
            groups = PlaceDateGroup.makeGroups(from: newPlaces)
            syncWidget(from: newPlaces)
        }
    }
}

// MARK: - Date group

struct PlaceDateGroup: Identifiable {
    let day: Date
    let places: [SavedPlace]
    var id: Date { day }

    static func makeGroups(from places: [SavedPlace]) -> [PlaceDateGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: places) { calendar.startOfDay(for: $0.savedAt) }
        return byDay.sorted { $0.key > $1.key }.map { PlaceDateGroup(day: $0.key, places: $0.value) }
    }

    var sectionTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: day, to: .now).day, days < 7 {
            return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        }
        return day.formatted(.dateTime.day().month(.wide).year())
    }
}

// MARK: - Row

private struct SavedPlaceRow: View {
    let place: SavedPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlaceThumbnail(url: place.photoURL)
                .overlay(alignment: .topTrailing) {
                    let categories = PlaceCategory.allMatching(types: place.types)
                    VStack(alignment: .trailing, spacing: 4) {
                        CategoryBadge(label: place.displayCategory,
                                      color: categories.first?.color ?? .accentColor)
                        ForEach(categories.dropFirst(), id: \.id) { category in
                            CategoryBadge(label: category.rawValue, color: category.color)
                        }
                    }
                    .padding(8)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).font(.body).fontWeight(.medium)
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Link(destination: place.mapsURL) {
                Label("Open in Maps", systemImage: "map")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}

#Preview{
    SavedPlacesView()
}
