import UIKit
import WidgetKit

func syncWidget(from places: [SavedPlace]) {
    let top5 = places
        .sorted { $0.savedAt > $1.savedAt }
        .prefix(5)
        .map { SharedPlace(id: $0.placeID, name: $0.name, category: $0.displayCategory, savedAt: $0.savedAt, photoURL: $0.photoURL?.absoluteString) }
    let top5Array = Array(top5)
    SharedPlaceStore.write(top5Array)
    evictStaleWidgetImages(keeping: top5Array)
    cacheWidgetImages(for: top5Array) {
        WidgetCenter.shared.reloadTimelines(ofKind: "backtoWidget")
    }
}

private func evictStaleWidgetImages(keeping places: [SharedPlace]) {
    guard let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.cwdigital.backto") else { return }
    let activeIDs = Set(places.map { $0.id })
    let files = (try? FileManager.default.contentsOfDirectory(at: container, includingPropertiesForKeys: nil)) ?? []
    for file in files where file.lastPathComponent.hasPrefix("widget_img_") {
        let id = String(file.deletingPathExtension().lastPathComponent.dropFirst("widget_img_".count))
        if !activeIDs.contains(id) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

private func cacheWidgetImages(for places: [SharedPlace], completion: @escaping () -> Void) {
    let group = DispatchGroup()
    for place in places {
        guard let urlString = place.photoURL,
              let networkURL = URL(string: urlString),
              let destURL = SharedPlaceStore.cachedImageURL(for: place.id) else { continue }
        if FileManager.default.fileExists(atPath: destURL.path) { continue }
        group.enter()
        URLSession.shared.dataTask(with: networkURL) { data, _, _ in
            if let data,
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.8) {
                try? jpeg.write(to: destURL)
            }
            group.leave()
        }.resume()
    }
    group.notify(queue: .main) { completion() }
}
