import SwiftUI

@main
struct PawFinderApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .tint(.pfBrandPrimary)
        }
    }
}
