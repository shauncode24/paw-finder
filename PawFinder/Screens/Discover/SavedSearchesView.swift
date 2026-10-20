import SwiftUI

/// Discover › Saved searches. Tap one to run it; toggle alerts; swipe to delete.
struct SavedSearchesView: View {
    @Environment(SavedSearchesStore.self) private var store
    @Environment(Router.self) private var router
    @State private var renaming: SavedSearch?
    @State private var newName = ""

    var body: some View {
        Group {
            if store.searches.isEmpty {
                EmptyStateView(icon: "bookmark", title: "No saved searches",
                               message: "Set up a search or filters in Discover, then tap the bookmark to save it. We'll tell you when new pets match.")
            } else {
                List {
                    Section {
                        ForEach(store.searches) { search in
                            row(search)
                                .listRowBackground(Color.pfSurface)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { store.searches[$0].id }
                            ids.forEach(store.delete)
                        }
                    } footer: {
                        Text("With alerts on, we check now and then for newly listed pets and send a notification.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Saved searches")
        .alert("Rename search", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let renaming { store.rename(renaming.id, to: newName) }
            }
        }
    }

    private func row(_ search: SavedSearch) -> some View {
        HStack(spacing: Spacing.md) {
            Button {
                // Run it in Discover.
                router.pendingSavedSearchID = search.id
                router.popToRoot()
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(search.name)
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                        if search.newMatchCount > 0 {
                            Text("\(search.newMatchCount) new")
                                .font(.pfCaption.weight(.bold))
                                .foregroundStyle(Color.pfSurfaceElevated)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 2)
                                .background(Color.pfBrandPrimary, in: Capsule())
                        }
                    }
                    Text("\(search.filters.activeCount) filter\(search.filters.activeCount == 1 ? "" : "s") · saved \(search.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Toggle("Alerts", isOn: Binding(
                get: { search.alertsOn },
                set: { isOn in
                    store.setAlerts(isOn, for: search.id)
                    if isOn { Task { await NotificationManager.shared.askPermission(for: .savedSearches) } }
                }
            ))
            .labelsHidden()
            .tint(Color.pfBrandPrimary)
            .accessibilityLabel("Alerts for \(search.name)")
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                newName = search.name
                renaming = search
            }
        }
    }
}
