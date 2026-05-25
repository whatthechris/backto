import SwiftUI
import SwiftData
import CoreLocation
import WidgetKit

struct NearbyPlacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedPlaces: [SavedPlace]

    @State private var locationManager = LocationManager()
    @State private var places: [NearbyPlace] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCategory: PlaceCategory = .all
    @State private var fetchTask: Task<Void, Never>?
    @State private var hasFetched = false
    @AppStorage("searchRadius") private var searchRadius: Double = 50

    private var savedIDs: Set<String> { Set(savedPlaces.map(\.placeID)) }

    private var availableCategories: [PlaceCategory] {
        PlaceCategory.allCases.filter { cat in
            cat == .all || places.contains { cat.matches(types: $0.types) }
        }
    }

    private var filteredPlaces: [NearbyPlace] {
        places.filter { selectedCategory.matches(types: $0.types) }
    }

    var body: some View {
        NavigationStack {
            locationBody
                .navigationTitle("Nearby")
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { fetchPlaces() } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading || locationManager.location == nil)
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            ForEach([25.0, 50.0, 100.0], id: \.self) { radius in
                                Button {
                                    searchRadius = radius
                                } label: {
                                    Label(radiusLabel(radius), systemImage: searchRadius == radius ? "checkmark" : "circle")
                                }
                            }
                        } label: {
                            Label(radiusLabel(searchRadius), systemImage: "location.circle")
                                .labelStyle(.titleAndIcon)
                        }
                        .disabled(locationManager.location == nil)
                    }
                }
        }
        .task {
            locationManager.requestPermission()
            if locationManager.location != nil, !hasFetched { loadFromCacheOrFetch() }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard newLocation != nil, !hasFetched else { return }
            loadFromCacheOrFetch()
        }
        .onChange(of: searchRadius) { fetchPlaces() }
        .onChange(of: places) { _, newPlaces in
            if selectedCategory != .all,
               !newPlaces.contains(where: { selectedCategory.matches(types: $0.types) }) {
                selectedCategory = .all
            }
        }
    }

    // MARK: - Location state

    @ViewBuilder
    private var locationBody: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            permissionPrompt(
                icon: "location.circle",
                title: "Location Access Needed",
                message: "backto uses your location to find places within 50 metres.",
                action: { locationManager.requestPermission() },
                actionLabel: "Allow Location Access"
            )
        case .denied, .restricted:
            permissionPrompt(
                icon: "location.slash",
                title: "Location Disabled",
                message: "Enable location access for backto in Settings.",
                action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                actionLabel: "Open Settings"
            )
        default:
            placesContent
        }
    }

    private func permissionPrompt(icon: String, title: String, message: String, action: @escaping () -> Void, actionLabel: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(actionLabel, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Places content

    @ViewBuilder
    private var placesContent: some View {
        VStack(spacing: 0) {
            filterChips.padding(.vertical, 10)
            Divider()
            if isLoading && places.isEmpty {
                centeredMessage { ProgressView(); Text("Searching nearby…").foregroundStyle(.secondary) }
            } else if let error = errorMessage, places.isEmpty {
                centeredMessage {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.orange)
                    Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    Button("Try Again") { fetchPlaces() }.buttonStyle(.borderedProminent)
                }
            } else if filteredPlaces.isEmpty {
                centeredMessage {
                    Image(systemName: "mappin.slash").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text(places.isEmpty
                         ? "No places found within \(radiusLabel(searchRadius))"
                         : "No \(selectedCategory.rawValue.lowercased()) found nearby")
                        .foregroundStyle(.secondary)
                }
            } else {
                ArchCarousel(places: filteredPlaces, savedIDs: savedIDs, onSave: save, onUnsave: unsave, loops: selectedCategory == .all)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories) { category in
                    FilterChip(label: category.rawValue, color: category.color, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func centeredMessage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Spacer()
        VStack(spacing: 12) { content() }
        Spacer()
    }

    // MARK: - Fetch

    private func loadFromCacheOrFetch() {
        guard let location = locationManager.location else { return }
        if let data = UserDefaults.standard.data(forKey: NearbySearchCache.key),
           let cache = try? JSONDecoder().decode(NearbySearchCache.self, from: data),
           cache.isValid(for: location, radius: searchRadius) {
            places = cache.places
            hasFetched = true
            return
        }
        fetchPlaces()
    }

    private func fetchPlaces(continuation: CheckedContinuation<Void, Never>? = nil) {
        hasFetched = true
        fetchTask?.cancel()
        fetchTask = Task {
            guard let location = locationManager.location else {
                continuation?.resume(); return
            }
            isLoading = true
            errorMessage = nil
            do {
                let result = try await PlacesService.searchNearby(location: location, radius: searchRadius)
                guard !Task.isCancelled else { continuation?.resume(); return }
                places = result
                NearbySearchCache.save(places: result, location: location, radius: searchRadius)
            } catch {
                guard !Task.isCancelled else { continuation?.resume(); return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
            continuation?.resume()
        }
    }

    // MARK: - Save / Unsave

    private func save(_ place: NearbyPlace) {
        guard !savedIDs.contains(place.id) else { return }
        let newPlace = SavedPlace(
            placeID: place.id,
            name: place.name,
            address: place.address,
            types: place.types,
            photoName: place.photoName,
            primaryTypeName: place.primaryTypeName
        )
        modelContext.insert(newPlace)
        syncWidget(from: [newPlace] + savedPlaces)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func unsave(_ place: NearbyPlace) {
        guard let saved = savedPlaces.first(where: { $0.placeID == place.id }) else { return }
        modelContext.delete(saved)
        syncWidget(from: savedPlaces.filter { $0.placeID != place.id })
    }

    private func radiusLabel(_ radius: Double) -> String {
        radius >= 1000 ? "\(Int(radius / 1000)) km" : "\(Int(radius)) m"
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Place row

private struct PlaceRow: View {
    let place: NearbyPlace
    let isSaved: Bool
    let onSave: () -> Void
    let onUnsave: () -> Void

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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(place.name).font(.body).fontWeight(.medium)
                    if !place.address.isEmpty {
                        Text(place.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            Button(action: isSaved ? onUnsave : onSave) {
                Label(isSaved ? "Saved" : "Save for later",
                      systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor.opacity(isSaved ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isSaved)
        }
        .padding(.vertical, 4)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}

// MARK: - Category badge

struct CategoryBadge: View {
    let label: String
    var color: Color = .accentColor

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(color.darkened(by: 0.6))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(1), in: Capsule())
    }
}

// MARK: - Search cache

private struct NearbySearchCache: Codable {
    static let key = "nearbySearchCache"

    let places: [NearbyPlace]
    let latitude: Double
    let longitude: Double
    let radius: Double

    static func save(places: [NearbyPlace], location: CLLocation, radius: Double) {
        let cache = NearbySearchCache(
            places: places,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: radius
        )
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func isValid(for location: CLLocation, radius: Double) -> Bool {
        let cached = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: cached) <= 50 && self.radius == radius
    }
}

// MARK: - Arch Carousel

private struct ArchCarousel: View {
    let places: [NearbyPlace]
    let savedIDs: Set<String>
    let onSave: (NearbyPlace) -> Void
    let onUnsave: (NearbyPlace) -> Void
    let loops: Bool

    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 440
    private var repeatCount: Int { loops ? 100 : 1 }

    private var totalCount: Int { places.count * repeatCount }
    private var startIndex: Int { (repeatCount / 2) * places.count }

    @State private var scrollID: Int?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        let place = places[index % places.count]
                        PlaceArchCard(
                            place: place,
                            isSaved: savedIDs.contains(place.id),
                            isCenter: index == scrollID,
                            onSave: { onSave(place) },
                            onUnsave: { onUnsave(place) }
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.05)
                                .rotationEffect(.degrees(phase.value * 4))
                                .offset(y: abs(phase.value) * 30)
                                .opacity(1 - abs(phase.value) * 0.5)
                        }
                        .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 36)
            }
            .contentMargins(.horizontal, (geo.size.width - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID, anchor: .center)
            .onAppear { scrollID = startIndex }
            .onChange(of: loops) { scrollID = startIndex }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Arch Card

private struct PlaceArchCard: View {
    let place: NearbyPlace
    let isSaved: Bool
    let isCenter: Bool
    let onSave: () -> Void
    let onUnsave: () -> Void

    @State private var pullOffset: CGFloat = 0
    @State private var didTrigger = false
    private let threshold: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: place.photoURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Color(.systemGray5)
                        .overlay { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary) }
                }
            }
            .frame(width: 260, height: 300)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                CategoryBadge(
                    label: place.displayCategory,
                    color: PlaceCategory.allMatching(types: place.types).first?.color ?? .accentColor
                )
                Text(place.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(place.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: isSaved ? onUnsave : onSave) {
                    Label(
                        isSaved ? "Saved" : "Save for later",
                        systemImage: isSaved ? "bookmark.fill" : "bookmark"
                    )
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(isSaved ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isSaved)
            }
            .padding(14)
            .frame(width: 260, height: 140, alignment: .topLeading)
        }
        .frame(width: 260, height: 440)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        .overlay(alignment: .top) {
            if pullOffset > 0 {
                let progress = min(pullOffset / threshold, 1)
                Image(systemName: didTrigger || isSaved ? "bookmark.fill" : "bookmark")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.accentColor.opacity(progress), in: Circle())
                    .scaleEffect(0.6 + 0.4 * progress)
                    .offset(y: -18)
                    .animation(.easeOut(duration: 0.1), value: didTrigger)
            }
        }
        .offset(y: pullOffset * 0.25)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: pullOffset)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard isCenter, !isSaved, value.translation.height > 0 else { return }
                    pullOffset = min(value.translation.height, threshold * 1.5)
                    if !didTrigger && pullOffset >= threshold {
                        didTrigger = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSave()
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        pullOffset = 0
                    }
                    didTrigger = false
                }
        )
    }
}

#Preview{
    NearbyPlacesView()
}
