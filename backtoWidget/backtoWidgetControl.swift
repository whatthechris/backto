import AppIntents
import SwiftUI
import WidgetKit

struct OpenBacktoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open backto"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct BacktoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "cwdigital.backto.openApp") {
            ControlWidgetButton(action: OpenBacktoIntent()) {
                Label("backto", systemImage: "bookmark.fill")
            }
        }
        .displayName("BackTo")
        .description("Open backto to find and save nearby places.")
    }
}
