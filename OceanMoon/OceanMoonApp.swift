import SwiftUI
import SwiftData

@main
struct OceanMoonApp: App {
    var body: some Scene {
        WindowGroup {
            SessionListView()
        }
        .modelContainer(for: Session.self)
    }
}
