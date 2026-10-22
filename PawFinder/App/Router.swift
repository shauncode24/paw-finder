import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case discover, map, identify, favorites, profile

    var title: String {
        switch self {
        case .discover: "Discover"
        case .map: "Map"
        case .identify: "Breeds"   // photo identification (Phase 6) will live here too
        case .favorites: "Favorites"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .discover: "magnifyingglass"
        case .map: "map"
        case .identify: "pawprint.circle"
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
    case editProfile
    case lifestyle
    case account
    case applications
    case applicationForm(UUID)
    case applicationDetail(UUID)
    case messages
    case conversation(String)       // conversation ID: "<listingID>_<adopterID>"
    // Listing pets (the lister side)
    case listerSetup
    case myListings
    case newListing
    case editListing(String)
    case receivedApplications
    case receivedApplication(String)
    case savedSearches
    case notificationSettings
    case swipe(PetFilters)
    case compare([Pet])
    case careHub
    case careArticle(String)
    case breedGuide(String)
    case careChecklist(String)
    case meetupMap(Meetup)          // route, travel time and Look Around for an agreed meeting place
    case nearbyPlaces               // vets, pet stores, dog parks near you
    case listerReviews(id: String, name: String)   // a lister's reviews
    case journey(applicationID: String)            // after adoption: check-ins and photo updates
    case fosterProfile                             // become / edit a foster volunteer profile
    case fosterOffers                              // offers sent and received
    case fosterDirectory                           // listers: volunteers nearby
    case help
    case about
    case privacyPolicy
    case terms
    case settings
    case designSystem
}

/// Keeps track of the selected tab and each tab's navigation stack.
@Observable
final class Router {
    var selectedTab: AppTab = .discover
    var paths: [AppTab: [Route]] = [:]
    /// A saved search for Discover to run (set by links and the saved searches list).
    var pendingSavedSearchID: UUID?
    /// Filters for Discover to apply (from Siri, breed guides, links).
    var pendingFilters: PetFilters?
    /// Set to true to show the sign-in sheet (for actions that need an account).
    var showSignIn = false

    func push(_ route: Route) {
        paths[selectedTab, default: []].append(route)
    }

    func popToRoot() {
        paths[selectedTab] = []
    }

    /// Switches to Discover and runs a search.
    func showInDiscover(_ filters: PetFilters) {
        selectedTab = .discover
        paths[.discover] = []
        pendingFilters = filters
    }

    /// Swaps the top screen for another (e.g. the form for the tracker after submitting).
    func replaceTop(with route: Route) {
        var path = paths[selectedTab] ?? []
        if !path.isEmpty { path.removeLast() }
        path.append(route)
        paths[selectedTab] = path
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
    ///     pawfinder://application/<uuid>  an adoption application
    ///     pawfinder://conversation/<id>   a chat
    ///     pawfinder://received/<id>       an application you received (as a lister)
    ///     pawfinder://journey/<id>        an adoption journey (the application's ID)
    ///     pawfinder://foster              foster offers
    ///     pawfinder://search/<uuid>  run a saved search in Discover
    ///     pawfinder://discover?species=dog&q=luna   Discover with filters
    ///     pawfinder://messages       the chats list
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
        case "application":
            guard let argument, let id = UUID(uuidString: argument) else { return false }
            open(.applicationDetail(id), in: .profile)
        case "conversation":
            guard let argument else { return false }
            open(.conversation(argument), in: .profile)
        case "received":
            guard let argument else { return false }
            open(.receivedApplication(argument), in: .profile)
        case "journey":
            guard let argument else { return false }
            open(.journey(applicationID: argument), in: .profile)
        case "foster":
            open(.fosterOffers, in: .profile)
        case "search":
            guard let argument, let id = UUID(uuidString: argument) else { return false }
            selectedTab = .discover
            paths[.discover] = []
            pendingSavedSearchID = id
        case "messages":
            open(.messages, in: .profile)
        case "discover":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
            if value("species") != nil || value("q") != nil {
                var filters = PetFilters()
                filters.species = value("species").flatMap { PetFilters.Species(rawValue: $0.capitalized) }
                filters.name = value("q") ?? ""
                showInDiscover(filters)
            } else {
                selectedTab = .discover
                paths[.discover] = []
            }
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
