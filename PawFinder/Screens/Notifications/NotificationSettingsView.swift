import SwiftUI
import UserNotifications

/// Settings › Notifications: which kinds to get, and quiet hours.
struct NotificationSettingsView: View {
    @State private var preferences = NotificationPreferences.current
    @State private var systemStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                switch systemStatus {
                case .authorized, .provisional, .ephemeral:
                    Label("Notifications are on", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.pfSuccess)
                    Button("Send a test notification") {
                        Task { await NotificationManager.shared.sendTestNotification() }
                    }
                case .denied:
                    Label("Notifications are off for PawFinder", systemImage: "bell.slash")
                        .foregroundStyle(Color.pfTextSecondary)
                    Button("Turn on in iPhone Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                default:
                    Button("Turn on notifications") {
                        Task {
                            await NotificationManager.shared.requestSystemPermission()
                            await refreshStatus()
                        }
                    }
                }
            }

            Section {
                ForEach(NotificationPreferences.Category.allCases, id: \.self) { category in
                    Toggle(isOn: binding(for: category)) {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            } header: {
                Text("Notify me about")
            }
            .disabled(systemStatus == .denied)

            Section {
                Toggle("Quiet hours", isOn: $preferences.quietHoursOn)
                if preferences.quietHoursOn {
                    DatePicker("From", selection: timeBinding(\.quietStart), displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: timeBinding(\.quietEnd), displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("Notifications that come in during quiet hours are held until they end.")
            }
            .disabled(systemStatus == .denied)
        }
        .tint(Color.pfBrandPrimary)
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle("Notifications")
        .task { await refreshStatus() }
        .onChange(of: preferences) { _, newValue in newValue.save() }
    }

    private func refreshStatus() async {
        systemStatus = await NotificationManager.shared.authorizationStatus()
    }

    private func binding(for category: NotificationPreferences.Category) -> Binding<Bool> {
        Binding(
            get: { preferences.isOn(category) },
            set: { isOn in
                if isOn { preferences.disabled.remove(category) } else { preferences.disabled.insert(category) }
            }
        )
    }

    /// Shows minutes-after-midnight as a time in a DatePicker.
    private func timeBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(preferences[keyPath: keyPath] * 60))
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                preferences[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
