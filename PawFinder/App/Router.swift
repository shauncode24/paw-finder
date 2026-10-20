import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
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
    case petDetail(Pet)
    case petID(String)        // from a link: loads the pet first
    case shelter(id: String)
    case followedShelters
    case settings
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

    /// Switches to a tab and shows one screen on it.
    func open(_ route: Route, in tab: AppTab) {
        selectedTab = tab
        paths[tab] = [route]
    }

    /// Handles deep links (from Safari, notifications, Spotlight):
    ///
    ///     pawfinder://pet/12345      a pet
    ///     pawfinder://shelter/NJ333  a shelter profile
    ///     pawfinder://favorites      a tab (discover, map, identify, favorites, profile)
    ///     pawfinder://settings       the Settings screen
    ///
    /// - Returns: false if the link wasn't recognized.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "pawfinder", let host = url.host()?.lowercased() else { return false }
        let argument = url.pathComponents.first { $0 != "/" }

        switch host {
        case "pet":
            guard let argument else { return false }
            open(.petID(argument), in: .discover)
        case "shelter":
            guard let argument else { return false }
            open(.shelter(id: argument), in: .map)
        case "settings":
            open(.settings, in: .profile)
        default:
            guard let tab = AppTab(rawValue: host) else {
                Log.app.notice("Unknown deep link: \(url.absoluteString)")
                return false
            }
            selectedTab = tab
            paths[tab] = []
        }
        return true
    }
}
