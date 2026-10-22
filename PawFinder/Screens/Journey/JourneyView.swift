import FirebaseCore
import FirebaseFirestore
import PhotosUI
import SwiftUI

// MARK: - Live data

/// One journey, kept live: the journey itself, the photo updates, and which of
/// them the lister has featured. The updates are only read once the journey
/// exists (the security rules look it up).
@MainActor
@Observable
final class JourneyViewModel {
    let applicationID: String
    private(set) var journey: Journey?
    private(set) var updates: [JourneyUpdate] = []
    private(set) var featuredIDs: Set<String> = []
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var journeyListener: ListenerRegistration?
    @ObservationIgnored private var updatesListener: ListenerRegistration?
    @ObservationIgnored private var tailsListener: ListenerRegistration?

    init(applicationID: String) {
        self.applicationID = applicationID
    }

    func start() {
        guard journeyListener == nil else { return }
        guard FirebaseApp.app() != nil else {
            isLoaded = true
            errorMessage = "Not connected to Firebase yet. See docs/SETUP.md."
            return
        }
        journeyListener = Firestore.firestore().collection("journeys").document(applicationID)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { Log.network.error("Journey listener: \(error.localizedDescription)") }
                Task { @MainActor in self?.handleJourney(snapshot, failed: error != nil) }
            }
    }

    func stop() {
        journeyListener?.remove()
        updatesListener?.remove()
        tailsListener?.remove()
        journeyListener = nil
        updatesListener = nil
        tailsListener = nil
    }

    private func handleJourney(_ snapshot: DocumentSnapshot?, failed: Bool) {
        isLoaded = true
        if failed {
            errorMessage = "Couldn't load this journey. Check your connection and the Firestore rules."
            return
        }
        errorMessage = nil
        guard let snapshot, snapshot.exists, let data = snapshot.data(),
              let parsed = Journey(id: snapshot.documentID, data: data) else {
            journey = nil
            return
        }
        journey = parsed
        if updatesListener == nil { attachSubListeners() }
    }

    private func attachSubListeners() {
        let db = Firestore.firestore()
        updatesListener = db.collection("journeys").document(applicationID).collection("updates")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let snapshot else { return }
                    self.updates = snapshot.documents.compactMap {
                        JourneyUpdate(id: $0.documentID, data: $0.data(with: .estimate), isPending: $0.metadata.hasPendingWrites)
                    }
                }
            }
        tailsListener = db.collection("happyTails").whereField("applicationID", isEqualTo: applicationID)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let snapshot else { return }
                    self.featuredIDs = Set(snapshot.documents.map(\.documentID))
                }
            }
    }
}

// MARK: - The journey screen

/// The adopter's journey with a pet: check-ins at Day 1, Week 1, Month 1 and
/// Month 3, and a feed of photo updates. The lister sees the same feed and can
/// feature updates as "Happy tails" on their profile (if the adopter allows).
struct JourneyView: View {
    let applicationID: String

    @Environment(AuthManager.self) private var auth
    @Environment(ApplicationsStore.self) private var applications
    @State private var viewModel: JourneyViewModel
    @State private var showComposer = false
    @State private var errorMessage: String?
    private let progress = JourneyProgressStore.shared

    init(applicationID: String) {
        self.applicationID = applicationID
        _viewModel = State(initialValue: JourneyViewModel(applicationID: applicationID))
    }

    private var myID: String { auth.user?.id ?? "" }

    var body: some View {
        Group {
            if let journey = viewModel.journey {
                content(journey)
            } else if !viewModel.isLoaded {
                LoadingView(message: "Loading journey...")
            } else if let message = viewModel.errorMessage {
                EmptyStateView(icon: "exclamationmark.triangle", title: "Couldn't load the journey", message: message)
            } else {
                EmptyStateView(icon: "heart.text.square", title: "No journey yet",
                               message: "It starts when the adoption is marked complete.")
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.start()
            await startIfNeeded()
        }
        .onDisappear { viewModel.stop() }
        .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil },
                                                       set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showComposer) {
            if let journey = viewModel.journey { JourneyUpdateComposer(journey: journey) }
        }
    }

    /// For adoptions finished before journeys existed (or a lister's "Adopted"), the adopter creates it here.
    private func startIfNeeded() async {
        guard let uuid = UUID(uuidString: applicationID), let application = applications.application(uuid),
              application.status == .adopted, !myID.isEmpty else { return }
        await JourneyService.ensureJourney(for: application, adopterID: myID)
    }

    private func content(_ journey: Journey) -> some View {
        let isAdopter = journey.adopterID == myID
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header(journey)
                if isAdopter {
                    sharingCard(journey)
                    milestonesSection(journey)
                }
                updatesSection(journey, isAdopter: isAdopter)
            }
            .padding(Spacing.lg)
        }
        .task {
            if isAdopter {
                await NotificationManager.shared.scheduleJourneyReminders(
                    applicationID: applicationID, petName: journey.petName, adoptedAt: journey.adoptedAt)
            }
        }
    }

    // MARK: Header

    private func header(_ journey: Journey) -> some View {
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 72, height: 72)
                .overlay { PetPhoto(url: PhotoURL.thumbnail(of: journey.listingID), species: journey.petSpecies) }
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.pfBrandPrimary, lineWidth: 3))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(journey.petName)'s journey")
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)
                Text("Home since \(journey.adoptedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                Text("Day \(journey.dayNumber())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pfBrandPrimary)
            }
        }
    }

    private func sharingCard(_ journey: Journey) -> some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: Binding(
                    get: { journey.shareHappyTails },
                    set: { JourneyService.setSharing($0, for: journey, featuredIDs: viewModel.featuredIDs) }
                )) {
                    Text("Let the lister feature my updates")
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                }
                .tint(Color.pfBrandPrimary)
                Text("They can show an update with \(journey.petName)'s name on their profile as a \"Happy tail\". Your name is never shown. Turn this off any time and anything featured comes down.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
    }

    // MARK: Check-ins

    private func milestonesSection(_ journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Check-ins")
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            ForEach(JourneyMilestone.allCases) { milestone in
                MilestoneCard(milestone: milestone, journey: journey)
            }
        }
    }

    // MARK: Updates

    private func updatesSection(_ journey: Journey, isAdopter: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Updates")
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            if isAdopter {
                PFButton(title: "Share an update") { showComposer = true }
            }
            if viewModel.updates.isEmpty {
                Text(isAdopter
                     ? "Share a photo and a few words. \(journey.petName)'s lister would love to see how it's going."
                     : "No updates yet. When the adopter shares one, it will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            ForEach(viewModel.updates) { update in
                UpdateCard(update: update, journey: journey, isAdopter: isAdopter,
                           isFeatured: viewModel.featuredIDs.contains(update.id),
                           onError: { errorMessage = $0 },
                           onDelete: {
                               JourneyService.delete(update, from: journey, wasFeatured: viewModel.featuredIDs.contains(update.id))
                           })
            }
        }
    }
}

// MARK: - Pieces

private struct MilestoneCard: View {
    let milestone: JourneyMilestone
    let journey: Journey
    @Environment(Router.self) private var router
    private let progress = JourneyProgressStore.shared

    private var due: Date { milestone.dueDate(adoptedAt: journey.adoptedAt) }
    private var isDue: Bool { due <= .now }
    private var isComplete: Bool { progress.isComplete(milestone, for: journey.id) }

    var body: some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : milestone.icon)
                        .foregroundStyle(isComplete ? Color.pfSuccess : (isDue ? Color.pfBrandPrimary : Color.pfBorder))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(milestone.shortTitle): \(milestone.title)")
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                        Text(subtitle)
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                    Spacer()
                }
                if isDue {
                    ForEach(milestone.tasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var subtitle: String {
        if isComplete { return "All done" }
        if isDue { return "\(progress.doneCount(in: milestone, for: journey.id)) of \(milestone.tasks.count) done" }
        return "Opens \(due.formatted(date: .abbreviated, time: .omitted))"
    }

    private func taskRow(_ task: JourneyTask) -> some View {
        let isDone = progress.isDone(task, in: milestone, for: journey.id)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Button {
                progress.toggle(task, in: milestone, for: journey.id)
            } label: {
                Label {
                    Text(task.title)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? Color.pfTextSecondary : Color.pfTextPrimary)
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isDone ? Color.pfSuccess : Color.pfBorder)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isDone ? .isSelected : [])
            .sensoryFeedback(.selection, trigger: isDone)
            Spacer()
            if let articleID = task.articleID {
                Button {
                    router.push(.careArticle(articleID))
                } label: {
                    Image(systemName: "book")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.pfBrandPrimary)
                .accessibilityLabel("Read the guide")
            }
        }
    }
}

private struct UpdateCard: View {
    let update: JourneyUpdate
    let journey: Journey
    let isAdopter: Bool
    let isFeatured: Bool
    let onError: (String) -> Void
    let onDelete: () -> Void

    @State private var isBusy = false

    var body: some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let base64 = update.photoBase64 {
                    Base64Photo(id: update.id, base64: base64)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                }
                if !update.text.isEmpty {
                    Text(update.text).foregroundStyle(Color.pfTextPrimary)
                }
                HStack {
                    Text("Day \(journey.dayNumber(on: update.createdAt)) · \(update.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                    if update.isPending {
                        Text("· Sending…")
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                    Spacer()
                    if isFeatured {
                        Label("Happy tail", systemImage: "heart.fill")
                            .font(.pfCaption.weight(.semibold))
                            .foregroundStyle(Color.pfBrandPrimary)
                    }
                }
                if !isAdopter {
                    listerButton
                }
            }
        }
        .opacity(update.isPending ? 0.7 : 1)
        .contextMenu {
            if isAdopter {
                Button("Delete update", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    @ViewBuilder
    private var listerButton: some View {
        if !journey.shareHappyTails && !isFeatured {
            Text("The adopter hasn't allowed featuring updates.")
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
        } else {
            Button {
                toggleFeatured()
            } label: {
                Label(isFeatured ? "Remove from your profile" : "Show on your profile as a Happy tail",
                      systemImage: isFeatured ? "heart.slash" : "heart")
                    .font(.subheadline.weight(.semibold))
            }
            .disabled(isBusy || update.isPending)
        }
    }

    private func toggleFeatured() {
        if isFeatured {
            JourneyService.unfeature(updateID: update.id)
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await JourneyService.feature(update, in: journey)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Posting an update

struct JourneyUpdateComposer: View {
    let journey: Journey

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canPost: Bool {
        !isSaving && (photo != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("How is \(journey.petName) doing?")
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let photo, let image = UIImage(data: photo) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        } else {
                            Label("Add a photo", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder, style: StrokeStyle(lineWidth: 1, dash: [5])))
                        }
                    }

                    TextEditor(text: $text)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.sm)
                        .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                        .onChange(of: text) { _, value in
                            if value.count > 500 { text = String(value.prefix(500)) }
                        }
                    Text("\(text.count)/500. The lister can see this. You choose on the journey screen whether they may feature it.")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)

                    if let errorMessage {
                        Text(errorMessage).font(.subheadline).foregroundStyle(Color.pfError)
                    }
                    PFButton(title: "Post update", isLoading: isSaving) { Task { await post() } }
                        .disabled(!canPost)
                        .opacity(canPost || isSaving ? 1 : 0.5)
                }
                .padding(Spacing.lg)
            }
            .background(Color.pfBackground)
            .navigationTitle("New update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onChange(of: photoItem) { _, item in loadPhoto(item) }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                photo = ImageCompressor.chatPhoto(from: data)
            }
        }
    }

    private func post() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await JourneyService.post(text: text, photo: photo, to: journey)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Happy tails on a lister's profile

/// "Happy tails": updates adopters shared and the lister chose to feature.
/// Shows nothing if there are none (or if the viewer isn't signed in).
struct HappyTailsSection: View {
    let listerID: String
    @State private var tails: [HappyTail] = []

    var body: some View {
        Group {
            if !tails.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Happy tails 🐾")
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.md) {
                            ForEach(tails) { tail in
                                card(tail)
                            }
                        }
                    }
                }
            }
        }
        .task { tails = await JourneyService.happyTails(forLister: listerID) }
    }

    private func card(_ tail: HappyTail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let base64 = tail.photoBase64 {
                Base64Photo(id: "tail-\(tail.id)", base64: base64)
                    .frame(width: 220, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            }
            Text("\(tail.petName) found a home")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pfTextPrimary)
            if !tail.text.isEmpty {
                Text(tail.text)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(3)
            }
        }
        .frame(width: 220, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Photos stored as text

/// A photo kept in a Firestore document as base64 text, decoded once and cached.
struct Base64Photo: View {
    let id: String
    let base64: String

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        if let image = Self.image(id: id, base64: base64) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("Photo")
        } else {
            Color.pfBrandDeep
        }
    }

    private static func image(id: String, base64: String) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let data = Data(base64Encoded: base64), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }
}
