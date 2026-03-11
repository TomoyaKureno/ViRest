import SwiftUI
import SwiftData

@main
struct ViRestApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .modelContainer(container.modelContainer)
    }
}
