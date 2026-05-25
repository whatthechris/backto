import AppIntents

struct OpenBacktoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open backto"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
