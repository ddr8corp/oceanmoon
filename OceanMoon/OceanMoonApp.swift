import SwiftUI
import SwiftData

@main
struct OceanMoonApp: App {
    var body: some Scene {
        WindowGroup {
            SessionListView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: Session.self)
    }
}
