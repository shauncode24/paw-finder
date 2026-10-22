import PhotosUI
import SwiftUI

/// Set up (or edit) your lister profile: who adopters will see behind your
/// listings. The first time you save it, your account can list pets.
/// It's the same sign-in as the adopter side; there's no separate account.
struct ListerSetupView: View {
    /// After the first save, go straight to "new listing".
    var continueToNewListing = false

    @Environment(ListerProfileStore.self) private var listerStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(AuthManager.self) private var auth
    @Environment(NetworkMonitor.self) private var network
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ListerProfile(uid: "")
    @State private var avatarChange = AvatarChange.keep
    @State private var avatarPreview: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didPrefill = false
    @State private var prefilledFromSaved = false
    @State private var showProblems = false

    private var isFirstTime: Bool { !listerStore.isLister }

    var body: some View {
        Form {
            if isFirstTime {
                Section {
                    Text("Listing a pet takes a minute to set up. Adopters will see this on your pets' pages. You can change it any time.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                .listRowBackground(Color.clear)
            }

            Section("Who's listing?") {
                Picker("Listing as", selection: $draft.isOrganization) {
                    Text("Just me").tag(false)
                    Text("A rescue or shelter").tag(true)
                }
                .pickerStyle(.segmented)

                TextField(draft.isOrganization ? "Your name (contact person)" : "Your name", text: $draft.displayName)
                    .textContentType(.name)
                if draft.isOrganization {
                    TextField("Rescue or shelter name", text: $draft.organization)
                }
                avatarRow
            }

            Section {
                TextField("About you or your rescue (optional)", text: $draft.bio, axis: .vertical)
                    .lineLimit(3...8)
                TextField("Adoption requirements (optional), e.g. home visit, 18+", text: $draft.adoptionPolicy, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("About")
            }

            Section {
                TextField("City", text: $draft.city)
                    .textContentType(.addressCity)
                TextField("State or region", text: $draft.state)
                    .textContentType(.addressState)
                TextField("Postcode / ZIP", text: $draft.postcode)
                    .textContentType(.postalCode)
            } header: {
                Text("Where are you?")
            } footer: {
                Text("This is only used to show your pets to people nearby. We don't show a street address.")
            }

            Section {
                TextField("Contact email", text: $draft.contactEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Contact phone", text: $draft.contactPhone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Website", text: $draft.website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Contact (optional)")
            } footer: {
                Text("Shown on your profile. Adopters can always message you inside PawFinder instead.")
            }

            if showProblems, !problems.isEmpty {
                Section {
                    ForEach(problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.pfError)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle(isFirstTime ? "Become a lister" : "Lister profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isFirstTime ? "Continue" : "Save") { save() }
                    .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving { ProgressView().controlSize(.large) }
        }
        .onAppear { prefill() }
        .onChange(of: listerStore.profile) { prefill() }
        .onChange(of: photoItem) { _, item in loadAvatar(item) }
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil },
                                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Pieces

    private var avatarRow: some View {
        HStack(spacing: Spacing.md) {
            Group {
                if let avatarPreview {
                    Image(uiImage: avatarPreview).resizable().scaledToFill()
                } else if draft.hasAvatar, !removesAvatar {
                    PetPhoto(url: PhotoURL.avatar(of: draft.uid))
                } else {
                    Image(systemName: draft.isOrganization ? "house.fill" : "person.fill")
                        .foregroundStyle(Color.pfBrandLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.pfBrandDeep)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .accessibilityHidden(true)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Text(hasAvatar ? "Change photo" : "Add a photo or logo")
            }
            if hasAvatar {
                Button("Remove", role: .destructive) {
                    avatarPreview = nil
                    avatarChange = .remove
                }
                .font(.subheadline)
            }
        }
    }

    private var removesAvatar: Bool {
        if case .remove = avatarChange { return true }
        return false
    }

    private var hasAvatar: Bool {
        avatarPreview != nil || (draft.hasAvatar && !removesAvatar)
    }

    // MARK: - Logic

    private var problems: [String] {
        var found: [String] = []
        if draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty { found.append("Enter your name.") }
        if draft.isOrganization, draft.organization.trimmingCharacters(in: .whitespaces).isEmpty {
            found.append("Enter your rescue or shelter's name.")
        }
        let hasPlace = !draft.city.trimmingCharacters(in: .whitespaces).isEmpty
            || !draft.postcode.trimmingCharacters(in: .whitespaces).isEmpty
        if !hasPlace { found.append("Add your city or postcode.") }
        return found
    }

    /// Fills the form from the saved profile, or from what we already know about the user.
    private func prefill() {
        // The saved profile arrives a moment after the screen opens; use it once it does.
        if let saved = listerStore.profile, !prefilledFromSaved {
            draft = saved
            prefilledFromSaved = true
            didPrefill = true
            return
        }
        guard !didPrefill else { return }
        var fresh = ListerProfile(uid: auth.user?.id ?? "")
        let known = profileStore.profile.displayName
        fresh.displayName = known.isEmpty ? (auth.user?.displayName ?? "") : known
        fresh.contactEmail = auth.user?.email ?? ""
        draft = fresh
        didPrefill = true
    }

    private func loadAvatar(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let small = ImageCompressor.avatar(from: data) {
                avatarChange = .set(small)
                avatarPreview = UIImage(data: small)
            }
            photoItem = nil
        }
    }

    private func save() {
        guard problems.isEmpty else {
            showProblems = true
            return
        }
        guard network.isOnline else {
            errorMessage = "You're offline. Connect to the internet to save your profile."
            return
        }
        isSaving = true
        let goToNewListing = continueToNewListing || isFirstTime
        let profile = draft
        let change = avatarChange
        let store = listerStore
        Task {
            defer { isSaving = false }
            do {
                try await withNetworkTimeout {
                    try await store.save(profile, avatar: change)
                }
                if goToNewListing {
                    router.replaceTop(with: .newListing)
                } else {
                    dismiss()
                }
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }
}
