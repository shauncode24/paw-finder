import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case discover, map, identify, favorites, profile

    var title: String {
        switch self {
        case .discover: "Discover"
        case .map: "Map"
        case .identify: "Identify"
        case .favorites: "Favorites"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .discover: "magnifyingglass"
        case .map: "map"
        case .identify: "camera.viewfinder"
        case .favorites: "heart"
        case .profile: "person.crop.circle"
        }
    }
}

/// Every screen you can push onto a tab. Add cases as new screens are built.
enum Route: Hashable {
    case petDetail(id: String)
    case shelter(id: String)
    case designSystem
}

/// Keeps track of the selected tab and each tab's navigation stack.
@Observable
final class Router {
    var selectedTab: AppTab = .discover
    var paths: [AppTab: [Route]] = [:]

    func push(_ route: Route) {
        paths[selectedTab, default: []].append(route)
    }

    func popToRoot() {
        paths[selectedTab] = []
    }
}
