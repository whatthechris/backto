import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isLaunching = true

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Nearby", systemImage: "location.fill", value: 0) {
                NearbyPlacesView()
            }
            Tab("Saved", systemImage: "bookmark.fill", value: 1) {
                SavedPlacesView()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "backto" else { return }
            switch url.host {
            case "nearby": selectedTab = 0
            case "saved":  selectedTab = 1
            default: break
            }
        }
        .overlay {
            if isLaunching {
                LaunchScreenView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.4)) {
                isLaunching = false
            }
        }
    }
}
