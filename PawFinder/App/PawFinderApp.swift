import SwiftUI

@main
struct PawFinderApp: App {
    @State private var router = Router()
    private let petRepository = PetRepositoryFactory.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(\.petRepository, petRepository)
                .tint(.pfBrandPrimary)
        }
    }
}
