import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main
struct ViRestApp: App {
    @StateObject private var container = AppContainer()

    init() {
        FirebaseApp.configure()

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: FirebaseApp.app()?.options.clientID ?? ""
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .modelContainer(container.modelContainer)
    }
}
