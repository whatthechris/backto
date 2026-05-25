import WidgetKit
import SwiftUI
import UIKit

// MARK: - Entry

struct PlacesEntry: TimelineEntry {
    let date: Date
    let places: [SharedPlace]
    let images: [String: UIImage]
    let displayIndex: Int
}

// MARK: - Provider

struct PlacesProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlacesEntry {
        PlacesEntry(date: .now, places: samplePlaces, images: [:], displayIndex: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlacesEntry) -> Void) {
        Task { completion(await makeEntry(displayIndex: 0)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlacesEntry>) -> Void) {
        Task {
            guard context.family == .systemSmall else {
                let entry = await makeEntry(displayIndex: 0)
                completion(Timeline(entries: [entry], policy: .never))
                return
            }
            let places = SharedPlaceStore.read()
            let top = Array(places.prefix(3))
            guard !top.isEmpty else {
                let empty = PlacesEntry(date: .now, places: [], images: [:], displayIndex: 0)
                completion(Timeline(entries: [empty], policy: .atEnd))
                return
            }
            let images = await fetchImages(for: top)
            let interval: TimeInterval = 10
            let cycles = Int((30 * 60) / (interval * Double(top.count)))  // ~30 min of looping
            let entries = (0..<cycles).flatMap { cycle in
                top.indices.map { i in
                    PlacesEntry(
                        date: Date().addingTimeInterval(Double(cycle * top.count + i) * interval),
                        places: top,
                        images: images,
                        displayIndex: i
                    )
                }
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private func makeEntry(displayIndex: Int) async -> PlacesEntry {
        let places = SharedPlaceStore.read()
        let images = await fetchImages(for: places)
        return PlacesEntry(date: .now, places: places, images: images, displayIndex: displayIndex)
    }

    private func fetchImages(for places: [SharedPlace]) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for place in places {
                guard let urlString = place.photoURL,
                      let networkURL = URL(string: urlString) else { continue }
                let id = place.id
                group.addTask {
                    if let cacheURL = SharedPlaceStore.cachedImageURL(for: id),
                       let data = try? Data(contentsOf: cacheURL),
                       let image = UIImage(data: data) {
                        return (id, image)
                    }
                    guard let (data, _) = try? await URLSession.shared.data(from: networkURL),
                          let image = UIImage(data: data) else { return (id, nil) }
                    if let cacheURL = SharedPlaceStore.cachedImageURL(for: id),
                       let jpeg = image.jpegData(compressionQuality: 0.8) {
                        try? jpeg.write(to: cacheURL)
                    }
                    return (id, image)
                }
            }
            var result: [String: UIImage] = [:]
            for await (id, image) in group {
                if let image { result[id] = image }
            }
            return result
        }
    }
}

private let samplePlaces: [SharedPlace] = [
    SharedPlace(id: "1", name: "Le Cafe",        category: "Cafe",      savedAt: .now, photoURL: nil),
    SharedPlace(id: "2", name: "City Museum",    category: "Museum",    savedAt: .now, photoURL: nil),
    SharedPlace(id: "3", name: "Corner Bakery",  category: "Bakery",    savedAt: .now, photoURL: nil),
    SharedPlace(id: "4", name: "Riverside Park", category: "Park",      savedAt: .now, photoURL: nil),
    SharedPlace(id: "5", name: "The Book Nook",  category: "Bookstore", savedAt: .now, photoURL: nil),
]

// MARK: - Root view

struct backtoWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PlacesEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "location.fill").font(.title2)
            }
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "backto://nearby"))

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "location.fill").font(.callout)
                Text("Find nearby places").font(.caption)
                Spacer(minLength: 0)
            }
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "backto://nearby"))

        case .systemSmall:
            SmallWidgetView(entry: entry)

        case .systemMedium:
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader()
                if entry.places.isEmpty {
                    EmptyPlacesLabel()
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(entry.places.prefix(3)) { place in
                            MediumPlaceCard(place: place, image: entry.images[place.id])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "backto://saved"))

        case .systemLarge:
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader()
                if entry.places.isEmpty {
                    EmptyPlacesLabel()
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(entry.places.prefix(4)) { place in
                            MediumPlaceCard(place: place, image: entry.images[place.id])
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "backto://saved"))

        default:
            EmptyView()
        }
    }
}

// MARK: - Small widget

private struct SmallWidgetView: View {
    let entry: PlacesEntry
    @Environment(\.widgetContentMargins) private var margins

    private var place: SharedPlace? {
        guard entry.displayIndex < entry.places.count else { return nil }
        return entry.places[entry.displayIndex]
    }

    var body: some View {
        Group {
            if let place {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(1)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .padding(EdgeInsets(
                        top: -margins.top, leading: -margins.leading,
                        bottom: -margins.bottom, trailing: -margins.trailing
                    ))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(place.category)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) {
                    PlacePhotoView(image: entry.images[place.id])
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetHeader()
                    EmptyPlacesLabel()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .containerBackground(.fill.tertiary, for: .widget)
            }
        }
        .widgetURL(URL(string: "backto://saved"))
    }
}

// MARK: - Shared subviews

private struct WidgetHeader: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bookmark.fill").foregroundStyle(Color.accentColor)
            Text("Come BackTo these places")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct EmptyPlacesLabel: View {
    var body: some View {
        Spacer()
        Text("No saved places yet.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        Spacer()
    }
}

private struct PlacePhotoView: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color.secondary.opacity(0.15)
                .overlay {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
        }
    }
}

private struct MediumPlaceCard: View {
    let place: SharedPlace
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PlacePhotoView(image: image)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(place.name)
                .font(.caption.bold())
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text(place.category)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }
}

// MARK: - Widget

struct backtoWidget: Widget {
    let kind = "backtoWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlacesProvider()) { entry in
            backtoWidgetView(entry: entry)
        }
        .configurationDisplayName("backto")
        .description("Recently saved places.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}
