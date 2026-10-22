import SwiftUI

/// Profile › Foster volunteer profile: say what you can foster, and listers
/// nearby can find you. Only your first name, city and what you can take are
/// shown, and only to listers. Your address is never asked for.
struct FosterProfileView: View {
    @Environment(FosterStore.self) private var fosters
    @Environment(AuthManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ListerProfileStore.self) private var listerStore
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var draft = FosterProfile(uid: "")
    @State private var didPrefill = false
    @State private var isSaving = false
    @State private var showProblems = false
    @State private var confirmRemove = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if auth.user == nil {
                EmptyStateView(icon: "house.and.flag", title: "Sign in to foster",
                               message: "Listers contact foster volunteers through their account, so you need one.",
                               buttonTitle: "Sign in") { router.showSignIn = true }
            } else {
                form
            }
        }
        .background(Color.pfBackground)
        .navigationTitle(fosters.isFoster ? "Foster profile" : "Become a foster")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: fosters.profileLoaded) { prefill() }
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil },
                                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Remove your foster profile?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task {
                    await fosters.removeProfile()
                    dismiss()
                }
            }
        } message: {
            Text("Listers won't see you any more. Offers you already sent stay as they are.")
        }
    }

    private var form: some View {
        Form {
            if !fosters.isFoster {
                Section {
                    Text("Fostering means giving a pet a safe home for a few days or weeks until they're adopted. Tell listers what you can take and they can ask you for help. It's the same account you use to adopt.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Available to foster now", isOn: $draft.isAvailable)
                TextField("Your name", text: $draft.displayName)
                    .textContentType(.name)
            } footer: {
                Text("Listers see your first name and last initial. Switch availability off to pause without losing your profile.")
            }

            Section("What you can take") {
                ForEach(PetFilters.Species.allCases, id: \.self) { species in
                    Toggle(species.rawValue, isOn: binding(for: species))
                }
                ForEach(PetFilters.Size.allCases, id: \.self) { size in
                    Toggle("\(size.rawValue) animals", isOn: binding(for: size))
                }
                Stepper("Up to \(draft.capacity) at a time", value: $draft.capacity, in: 1...10)
                Picker("For how long", selection: $draft.duration) {
                    ForEach(FosterDuration.allCases) { Text($0.rawValue).tag($0) }
                }
            }

            Section("Your home") {
                Picker("Home", selection: $draft.homeType) {
                    Text("Prefer not to say").tag(AdopterProfile.HomeType?.none)
                    ForEach(AdopterProfile.HomeType.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                Picker("Experience", selection: $draft.experience) {
                    Text("Prefer not to say").tag(AdopterProfile.Experience?.none)
                    ForEach(AdopterProfile.Experience.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                Toggle("I have other pets", isOn: $draft.hasOtherPets)
                if draft.hasOtherPets {
                    TextField("Which ones? (optional)", text: $draft.otherPetsNote)
                }
                TextField("A few words about you (optional)", text: $draft.bio, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                TextField("City", text: $draft.city)
                TextField("State or region", text: $draft.state)
                TextField("Postcode / ZIP", text: $draft.postcode)
            } header: {
                Text("Where you are")
            } footer: {
                Text("Only your city is shown, to listers. We never ask for or show your street address.")
            }

            if showProblems, !draft.problems.isEmpty {
                Section {
                    ForEach(draft.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.circle").foregroundStyle(Color.pfError)
                    }
                }
            }

            Section {
                PFButton(title: fosters.isFoster ? "Save changes" : "Become a foster volunteer", isLoading: isSaving) {
                    Task { await save() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if fosters.isFoster {
                Section {
                    Button("Remove my foster profile", role: .destructive) { confirmRemove = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private func binding(for species: PetFilters.Species) -> Binding<Bool> {
        Binding(get: { draft.species.contains(species) },
                set: { if $0 { draft.species.insert(species) } else { draft.species.remove(species) } })
    }

    private func binding(for size: PetFilters.Size) -> Binding<Bool> {
        Binding(get: { draft.sizes.contains(size) },
                set: { if $0 { draft.sizes.insert(size) } else { draft.sizes.remove(size) } })
    }

    /// Start from the saved foster profile, or from what we already know about the person.
    private func prefill() {
        guard !didPrefill, fosters.profileLoaded else { return }
        didPrefill = true
        if let saved = fosters.profile {
            draft = saved
            return
        }
        draft = FosterProfile(uid: auth.user?.id ?? "")
        let name = profileStore.profile.displayName
        draft.displayName = name.isEmpty ? (auth.user?.displayName ?? "") : name
        if let lister = listerStore.profile {
            draft.city = lister.city
            draft.state = lister.state
            draft.postcode = lister.postcode
        }
    }

    private func save() async {
        showProblems = true
        guard draft.problems.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await fosters.saveProfile(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
