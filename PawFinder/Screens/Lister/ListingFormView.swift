import PhotosUI
import SwiftUI

/// Create or edit an adoption listing: photos, the pet's details, health,
/// how they get on with kids and other pets, the fee, and where to find them.
/// Publishing makes it appear in everyone's Discover within a moment.
struct ListingFormView: View {
    /// nil = a new listing; otherwise the listing being edited.
    var editingID: String?

    @Environment(ListingsService.self) private var listings
    @Environment(ListerProfileStore.self) private var listerStore
    @Environment(NetworkMonitor.self) private var network
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ListingDraft()
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var isSaving = false
    @State private var showProblems = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var publishedMessage: String?

    private var isEditing: Bool { editingID != nil }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Opening your listing...")
            } else {
                form
            }
        }
        .background(Color.pfBackground)
        .navigationTitle(isEditing ? "Edit listing" : "New listing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Publish") { save() }
                    .disabled(isSaving || isLoading)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("Saving...")
                    .padding(Spacing.xl)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
        .task { await prepare() }
        .onChange(of: pickedPhotos) { _, items in addPhotos(items) }
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil },
                                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(publishedMessage ?? "", isPresented: Binding(get: { publishedMessage != nil },
                                                           set: { if !$0 { publishedMessage = nil } })) {
            Button("Done") { dismiss() }
        }
        .confirmationDialog("Delete this listing?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete listing", role: .destructive) { deleteListing() }
        } message: {
            Text("It will disappear for everyone. Chats and applications about it stay in your inbox. This can't be undone.")
        }
    }

    // MARK: - The form

    private var form: some View {
        Form {
            photosSection
            basicsSection
            aboutSection
            homeSection
            healthSection
            adoptionSection
            locationSection
            if isEditing { statusSection }

            if showProblems, !draft.problems.isEmpty {
                Section {
                    ForEach(draft.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.pfError)
                    }
                }
            }
            if isEditing {
                Section {
                    Button("Delete listing", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var photosSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(draft.photos.enumerated()), id: \.offset) { index, bytes in
                        PhotoThumb(bytes: bytes, isCover: index == 0) {
                            draft.photos.remove(at: index)
                        } makeCover: {
                            let moved = draft.photos.remove(at: index)
                            draft.photos.insert(moved, at: 0)
                        }
                    }
                    if draft.photos.count < ListingDraft.maxPhotos {
                        PhotosPicker(selection: $pickedPhotos,
                                     maxSelectionCount: ListingDraft.maxPhotos - draft.photos.count,
                                     matching: .images) {
                            VStack(spacing: Spacing.xs) {
                                Image(systemName: "plus.circle.fill").font(.title2)
                                Text("Add").font(.pfCaption)
                            }
                            .foregroundStyle(Color.pfBrandPrimary)
                            .frame(width: 88, height: 88)
                            .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        } header: {
            Text("Photos")
        } footer: {
            Text("Up to \(ListingDraft.maxPhotos). The first photo is the cover. Clear, well-lit photos get the most interest. Long-press a photo for options.")
        }
    }

    private var basicsSection: some View {
        Section("The basics") {
            TextField("Name", text: $draft.name)
            Picker("Species", selection: $draft.species) {
                ForEach(PetFilters.Species.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            TextField("Breed", text: $draft.breed)
                .autocorrectionDisabled()
            ForEach(breedSuggestions, id: \.self) { suggestion in
                Button(suggestion) { draft.breed = suggestion }
                    .font(.subheadline)
            }
            Toggle("Mixed breed", isOn: $draft.isMixed)
            if draft.isMixed {
                TextField("Other breed in the mix (optional)", text: $draft.secondaryBreed)
            }
        }
    }

    private var aboutSection: some View {
        Section("About them") {
            Picker("Age group", selection: $draft.age) {
                ForEach(PetFilters.Age.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField("Exact age (optional), e.g. 2 years 3 months", text: $draft.ageDetail)
            Picker("Gender", selection: $draft.gender) {
                ForEach(PetFilters.Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Size", selection: $draft.size) {
                ForEach(PetFilters.Size.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Coat", selection: $draft.coat) {
                Text("Not sure").tag(PetFilters.Coat?.none)
                ForEach(PetFilters.Coat.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }
            TextField("Colors (optional), e.g. black and white", text: $draft.colors)
            TextField("Weight (optional), e.g. 12 kg", text: $draft.weight)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Temperament").font(.subheadline).foregroundStyle(Color.pfTextSecondary)
                FlowLayout {
                    ForEach(ListingDraft.temperamentOptions, id: \.self) { tag in
                        PFChip(title: tag, isSelected: draft.temperament.contains(tag)) {
                            draft.temperament.formSymmetricDifference([tag])
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var homeSection: some View {
        Section("Getting along") {
            TriStateRow(title: "Good with kids", selection: $draft.goodWithKids)
            TriStateRow(title: "Good with dogs", selection: $draft.goodWithDogs)
            TriStateRow(title: "Good with cats", selection: $draft.goodWithCats)
            Toggle("House or litter trained", isOn: $draft.houseTrained)
        }
    }

    private var healthSection: some View {
        Section {
            Toggle("Vaccinated", isOn: $draft.vaccinated)
            Toggle("Spayed or neutered", isOn: $draft.spayedNeutered)
            Toggle("Microchipped", isOn: $draft.microchipped)
            Toggle("Has special needs", isOn: $draft.specialNeeds)
            if draft.specialNeeds {
                TextField("Describe the special needs", text: $draft.specialNeedsNotes, axis: .vertical)
                    .lineLimit(2...5)
            }
            TextField("Other health notes (optional)", text: $draft.healthNotes, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("Health")
        } footer: {
            Text("Be honest and specific. Adopters appreciate knowing about medical history up front.")
        }
    }

    private var adoptionSection: some View {
        Section {
            TextField("Adoption fee (leave empty if free)", text: $draft.adoptionFee)
                .keyboardType(.decimalPad)
            TextField("Tell their story: personality, habits, what they need…", text: $draft.description, axis: .vertical)
                .lineLimit(5...12)
            TextField("Video link (optional)", text: $draft.videoLink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Adoption")
        } footer: {
            Text("Never ask adopters to send money before meeting the pet in person.")
        }
    }

    private var locationSection: some View {
        Section {
            TextField("City", text: $draft.city)
            TextField("State or region", text: $draft.state)
            TextField("Postcode / ZIP", text: $draft.postcode)
            TextField("Contact email (optional)", text: $draft.contactEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Contact phone (optional)", text: $draft.contactPhone)
                .keyboardType(.phonePad)
        } header: {
            Text("Where and how to reach you")
        } footer: {
            Text("Adopters can always message you in PawFinder. Add an email or phone only if you want them shown on this listing.")
        }
    }

    private var statusSection: some View {
        Section {
            Picker("Status", selection: $draft.status) {
                ForEach(ListingStatus.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } header: {
            Text("Status")
        } footer: {
            Text("\"Adoption pending\" keeps the listing visible with a note. \"Adopted\" removes it from Discover.")
        }
    }

    // MARK: - Logic

    /// Breed names that match what's been typed (and aren't already the whole answer).
    private var breedSuggestions: [String] {
        BreedCatalog.suggestions(for: draft.species, matching: draft.breed)
            .filter { $0.caseInsensitiveCompare(draft.breed.trimmingCharacters(in: .whitespaces)) != .orderedSame }
    }

    /// Loads the listing being edited, or fills in what we already know for a new one.
    private func prepare() async {
        guard !didLoad else { return }
        didLoad = true

        if let editingID {
            isLoading = true
            do {
                draft = try await listings.loadDraft(id: editingID)
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
            isLoading = false
        } else if let profile = listerStore.profile {
            draft.city = profile.city
            draft.state = profile.state
            draft.postcode = profile.postcode
            draft.contactEmail = profile.contactEmail
            draft.contactPhone = profile.contactPhone
        }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                guard draft.photos.count < ListingDraft.maxPhotos else { break }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let small = ImageCompressor.fullSize(from: data) {
                    draft.photos.append(small)
                }
            }
            pickedPhotos = []
        }
    }

    private func save() {
        guard draft.problems.isEmpty else {
            withAnimation { showProblems = true }
            return
        }
        guard network.isOnline else {
            errorMessage = "You're offline. Connect to the internet to publish."
            return
        }
        guard let owner = listerStore.profile else {
            errorMessage = "Set up your lister profile first."
            return
        }

        isSaving = true
        let current = draft
        let service = listings
        let wasEditing = isEditing
        Task {
            defer { isSaving = false }
            do {
                try await service.publish(current, owner: owner)
                publishedMessage = wasEditing ? "Your changes are saved." : "Your listing is live! Adopters can see it now."
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }

    private func deleteListing() {
        guard let id = draft.id else { return }
        let count = draft.originalPhotoCount
        let service = listings
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await service.delete(listingID: id, photoCount: count)
                dismiss()
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }
}

// MARK: - Pieces

private struct TriStateRow: View {
    let title: String
    @Binding var selection: TriState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.subheadline)
            Picker(title, selection: $selection) {
                ForEach(TriState.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 2)
    }
}

/// A photo in the form, with a "Cover" badge on the first and a remove button.
private struct PhotoThumb: View {
    let bytes: Data
    let isCover: Bool
    let remove: () -> Void
    let makeCover: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: bytes) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.pfBrandDeep
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(alignment: .bottomLeading) {
                if isCover {
                    Text("Cover")
                        .font(.pfCaption.weight(.bold))
                        .foregroundStyle(Color.pfSurfaceElevated)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.pfBrandPrimary, in: Capsule())
                        .padding(Spacing.xs)
                }
            }

            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Remove photo")
        }
        .contextMenu {
            if !isCover {
                Button("Make cover photo", systemImage: "star", action: makeCover)
            }
            Button("Remove", systemImage: "trash", role: .destructive, action: remove)
        }
    }
}
