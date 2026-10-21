import SwiftUI
import UserNotifications

/// Light / dark / system appearance. Saved with @AppStorage("appearance").
enum AppearanceSetting: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Appearance, permissions, and clearing saved data.
struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system
    @Environment(RecentlyViewedStore.self) private var recentlyViewed
    @Environment(LocationService.self) private var locationService
    @Environment(\.openURL) private var openURL

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmation: String?
    @State private var confirmErase = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @Environment(FavoritesStore.self) private var favorites
    @Environment(ApplicationsStore.self) private var applications
    @Environment(MessagesStore.self) private var messages
    @Environment(SavedSearchesStore.self) private var savedSearches
    @Environment(FollowedSheltersStore.self) private var followed
    @Environment(ProfileStore.self) private var profileStore
    @Environment(CareChecklistStore.self) private var careChecklists

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceSetting.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack {
                    Label("Notifications", systemImage: "bell")
                    Spacer()
                    Text(notificationText).foregroundStyle(Color.pfTextSecondary)
                }
                NavigationLink(value: Route.notificationSettings) {
                    Text("Notification preferences & quiet hours")
                }
                if notificationStatus == .notDetermined {
                    Button("Turn on notifications") {
                        Task {
                            await NotificationManager.shared.requestSystemPermission()
                            await refreshNotificationStatus()
                        }
                    }
                }
                HStack {
                    Label("Location", systemImage: "location")
                    Spacer()
                    Text(locationText).foregroundStyle(Color.pfTextSecondary)
                }
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Notifications tell you when a favorite gets adopted. Location finds pets near you.")
            }

            Section("Data") {
                Button("Clear recently viewed", role: .destructive) {
                    recentlyViewed.clear()
                    confirmation = "Recently viewed cleared."
                }
                Button("Clear saved search results and photos", role: .destructive) {
                    PetCache.clear()
                    URLCache.shared.removeAllCachedResponses()
                    confirmation = "Cache cleared."
                }
            }

            Section("Help & info") {
                NavigationLink(value: Route.help) { Label("Help & FAQ", systemImage: "questionmark.circle") }
                if let url = SupportInfo.feedbackURL {
                    Link(destination: url) { Label("Send feedback", systemImage: "envelope") }
                }
                NavigationLink(value: Route.privacyPolicy) { Label("Privacy Policy", systemImage: "hand.raised") }
                NavigationLink(value: Route.terms) { Label("Terms of Use", systemImage: "doc.plaintext") }
                NavigationLink(value: Route.about) { Label("About PawFinder", systemImage: "info.circle") }
                Button {
                    hasCompletedOnboarding = false
                } label: {
                    Label("Show the welcome tour again", systemImage: "sparkles")
                }
            }

            Section {
                Button("Erase all data on this phone", role: .destructive) { confirmErase = true }
            } footer: {
                Text("Removes favorites, collections, applications, messages, saved searches, followed shelters, your profile, and cached pets from this phone. Your account (if any) isn't deleted.")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Pet data", value: Secrets.hasPetfinderKeys ? "Petfinder" : "Sample data (no API keys)")
                if let url = URL(string: "https://www.petfinder.com") {
                    Link("Pet listings powered by Petfinder", destination: url)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle("Settings")
        .task { await refreshNotificationStatus() }
        .confirmationDialog("Erase all PawFinder data on this phone?", isPresented: $confirmErase,
                            titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { eraseAll() }
        } message: {
            Text("This can't be undone.")
        }
        .alert(confirmation ?? "", isPresented: Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
    }

    private func eraseAll() {
        favorites.removeAll()
        applications.removeAll()
        messages.removeAll()
        savedSearches.removeAll()
        followed.removeAll()
        recentlyViewed.clear()
        careChecklists.reset()
        profileStore.deleteData(for: profileStore.ownerID)
        PetCache.clear()
        URLCache.shared.removeAllCachedResponses()
        UserDefaults.standard.removeObject(forKey: "swipePassedPetIDs")
        UserDefaults.standard.removeObject(forKey: "listingReports")
        UserDefaults.standard.removeObject(forKey: "messageReports")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        NotificationManager.shared.updateBadge(0)
        confirmation = "All PawFinder data on this phone was erased."
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await NotificationManager.shared.authorizationStatus()
    }

    private var notificationText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "On"
        case .denied: "Off"
        default: "Not set"
        }
    }

    private var locationText: String {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: "On"
        case .denied, .restricted: "Off"
        default: "Not set"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(RecentlyViewedStore())
        .environment(LocationService())
        .environment(FavoritesStore(fileName: "preview-favorites.json"))
        .environment(ApplicationsStore())
        .environment(MessagesStore())
        .environment(SavedSearchesStore())
        .environment(FollowedSheltersStore())
        .environment(ProfileStore())
        .environment(CareChecklistStore())
}
