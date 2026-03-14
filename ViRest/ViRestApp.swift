import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import UIKit

@main
struct ViRestApp: App {
    @StateObject private var container = AppContainer()

    init() {
        FirebaseApp.configure()

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: FirebaseApp.app()?.options.clientID ?? ""
        )

        Self.configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .modelContainer(container.modelContainer)
    }

    private static func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.slateGray)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.slateGray)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
