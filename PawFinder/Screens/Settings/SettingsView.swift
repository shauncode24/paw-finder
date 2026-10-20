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
                if notificationStatus == .notDetermined {
                    Button("Turn on notifications") {
                        Task {
                            await NotificationManager.shared.requestAuthorizationIfNeeded()
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
        .alert(confirmation ?? "", isPresented: Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
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
}
