import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import UIKit

/// Adoption applications.
///
/// - **Adopters:** drafts live on the phone (`Documents/applications.json`, attached
///   photos in `Documents/ApplicationFiles/`). When submitted, the application is
///   written to Firestore (`applications/{id}`) for the lister to read, and the
///   adopter's phone then follows its status live.
/// - **Listers:** `received` is a live list of applications for their pets. They
///   change the status (in review → interview → approved / declined → adopted) and
///   the adopter sees it immediately.
///
/// Attached photos (ID, lease…) stay on the adopter's phone on purpose: they're
/// sensitive and shouldn't sit in a shared database.
@MainActor
@Observable
final class ApplicationsStore {
    private(set) var applications: [AdoptionApplication] = []
    /// Applications for the signed-in user's own listings, newest first.
    private(set) var received: [ReceivedApplication] = []
    private(set) var userID: String?

    /// Applications that haven't been looked at yet.
    var newReceivedCount: Int { received.filter { $0.status == .submitted }.count }

    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("applications.json")
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var mineListener: ListenerRegistration?
    @ObservationIgnored private var receivedListener: ListenerRegistration?
    @ObservationIgnored private var receivedLoaded = false

    private var isConfigured: Bool { FirebaseApp.app() != nil }
    private var db: Firestore { Firestore.firestore() }

    init() {
        load()
    }

    func application(_ id: UUID) -> AdoptionApplication? {
        applications.first { $0.id == id }
    }

    func receivedApplication(_ id: String) -> ReceivedApplication? {
        received.first { $0.id == id }
    }

    /// The draft or active application for a pet, if any (one per pet).
    func openApplication(for petID: String) -> AdoptionApplication? {
        applications.first { $0.pet.id == petID && !$0.isClosed }
    }

    // MARK: - Live updates

    /// Call whenever the signed-in user changes (nil = signed out).
    func start(for uid: String?) {
        guard uid != userID else { return }
        mineListener?.remove()
        receivedListener?.remove()
        mineListener = nil
        receivedListener = nil
        received = []
        receivedLoaded = false
        userID = uid

        guard isConfigured, let uid else { return }

        // As an adopter: follow the status of what I applied for.
        mineListener = db.collection("applications").whereField("adopterID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in self?.handleMine(snapshot) }
            }

        // As a lister: applications for my pets.
        receivedListener = db.collection("applications").whereField("listerID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in self?.handleReceived(snapshot, uid: uid) }
            }
    }

    private func handleMine(_ snapshot: QuerySnapshot?) {
        guard let snapshot else { return }
        for document in snapshot.documents where !document.metadata.hasPendingWrites {
            merge(remote: document.data(with: .estimate), id: document.documentID)
        }
    }

    /// Copies the lister's decisions onto my local copy, and notifies me of new ones.
    private func merge(remote data: [String: Any], id: String) {
        guard let uuid = UUID(uuidString: id), let index = index(of: uuid) else { return }
        let previousStatus = applications[index].status
        let remoteEvents = ApplicationJSON.events(from: data["events"])
        let knownIDs = Set(applications[index].events.map(\.id))
        let newEvents = remoteEvents.filter { !knownIDs.contains($0.id) }
        guard !newEvents.isEmpty || (data["status"] as? String) != applications[index].status.rawValue else { return }

        if let status = ApplicationStatus(rawValue: (data["status"] as? String) ?? "") {
            applications[index].status = status
            if status == .approved, applications[index].checklist.isEmpty {
                applications[index].checklist = ChecklistItem.afterApproval
            }
        }
        if !remoteEvents.isEmpty { applications[index].events = remoteEvents }
        applications[index].updatedAt = .now
        save()
        // The lister marked it adopted: start the journey on this phone.
        if applications[index].status == .adopted, previousStatus != .adopted {
            startJourney(for: applications[index])
        }

        // Tell the adopter about anything the lister did (not their own submit/withdraw).
        let petName = applications[index].pet.name
        for event in newEvents where event.status != .submitted && event.status != .withdrawn {
            Task {
                await NotificationManager.shared.notifyApplicationUpdate(applicationID: uuid, petName: petName,
                                                                         status: event.status, note: event.note)
            }
        }
    }

    private func handleReceived(_ snapshot: QuerySnapshot?, uid: String) {
        guard let snapshot, userID == uid else { return }
        if receivedLoaded {
            for change in snapshot.documentChanges where change.type == .added && !change.document.metadata.hasPendingWrites {
                if let application = ReceivedApplication(id: change.document.documentID,
                                                         data: change.document.data(with: .estimate)) {
                    Task {
                        await NotificationManager.shared.notifyNewApplication(
                            applicationID: application.id, petName: application.petName,
                            applicantName: application.adopterName)
                    }
                }
            }
        }
        received = snapshot.documents
            .compactMap { ReceivedApplication(id: $0.documentID, data: $0.data(with: .estimate)) }
            .sorted { $0.submittedAt > $1.submittedAt }
        receivedLoaded = true
    }

    // MARK: - Drafts (adopter, on the phone)

    /// Resumes this pet's draft/application, or starts a new draft
    /// pre-filled from the profile.
    func startOrResume(pet: Pet, shelterName: String?, profile: AdopterProfile, email: String?) -> UUID {
        if let existing = openApplication(for: pet.id) { return existing.id }

        var form = ApplicationForm()
        form.fullName = profile.displayName
        form.email = email ?? ""
        form.homeType = profile.homeType
        form.kids = profile.kids
        form.experience = profile.experience
        form.hasFencedYard = profile.homeType == .houseWithYard || profile.homeType == .farm
        if profile.schedule == .awayAllDay { form.hoursAlonePerDay = 8 }
        if profile.schedule == .mostlyHome { form.hoursAlonePerDay = 2 }

        let application = AdoptionApplication(pet: pet, shelterName: shelterName ?? pet.listedBy, form: form)
        applications.insert(application, at: 0)
        save()
        return application.id
    }

    /// Autosave: called as the user types. Writes to disk after a short pause.
    func updateForm(_ id: UUID, _ form: ApplicationForm) {
        guard let index = index(of: id), applications[index].form != form else { return }
        applications[index].form = form
        applications[index].updatedAt = .now
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    /// Erase every application kept on this phone, and attached photos (Settings › Erase all data).
    /// Applications already sent to a lister stay with them.
    func removeAll() {
        try? FileManager.default.removeItem(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ApplicationFiles", isDirectory: true))
        applications = []
        save()
    }

    func deleteDraft(_ id: UUID) {
        guard let application = application(id), application.status == .draft else { return }
        try? FileManager.default.removeItem(at: filesFolder(for: id))
        applications.removeAll { $0.id == id }
        save()
    }

    // MARK: - Attachments (stay on the phone)

    func addAttachment(to id: UUID, kind: ApplicationAttachment.Kind, imageData: Data) {
        guard let index = index(of: id), let image = UIImage(data: imageData) else { return }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: filesFolder(for: id), withIntermediateDirectories: true)
            let jpeg = image.jpegData(compressionQuality: 0.7) ?? imageData
            try jpeg.write(to: filesFolder(for: id).appendingPathComponent(fileName), options: .atomic)
            applications[index].attachments.append(ApplicationAttachment(kind: kind, fileName: fileName))
            save()
        } catch {
            Log.storage.error("Couldn't save attachment: \(error.localizedDescription)")
        }
    }

    func removeAttachment(_ attachment: ApplicationAttachment, from id: UUID) {
        guard let index = index(of: id) else { return }
        try? FileManager.default.removeItem(at: fileURL(for: attachment, in: id))
        applications[index].attachments.removeAll { $0.id == attachment.id }
        save()
    }

    func fileURL(for attachment: ApplicationAttachment, in applicationID: UUID) -> URL {
        filesFolder(for: applicationID).appendingPathComponent(attachment.fileName)
    }

    // MARK: - Submit / withdraw / adopt (adopter)

    /// Sends the application to the lister.
    func submit(_ id: UUID, adopterName: String) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        guard let uid = userID else { throw APIError.notSignedIn }
        guard let index = index(of: id), applications[index].status == .draft else { return }
        let application = applications[index]
        guard application.pet.shelterID != uid else {
            throw BackendMessage(text: "This is your own listing, so you can't apply for it.")
        }

        let now = Date.now
        let event = ApplicationStatusEvent(status: .submitted, date: now)
        let data: [String: Any] = [
            "adopterID": uid,
            "adopterName": adopterName,
            "listerID": application.pet.shelterID,
            "listingID": application.pet.id,
            "petName": application.pet.name,
            "petSpecies": application.pet.species,
            "status": ApplicationStatus.submitted.rawValue,
            "formJSON": ApplicationJSON.text(application.form),
            "events": [ApplicationJSON.text(event)],
            "submittedAt": Timestamp(date: now),
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        let reference = db.collection("applications").document(id.uuidString)
        do {
            try await withNetworkTimeout { try await reference.setData(data) }
        } catch {
            throw backendError(error)
        }

        applications[index].status = .submitted
        applications[index].submittedAt = now
        applications[index].events = [event]
        save()
        Task { await NotificationManager.shared.askPermission(for: .applications) }
    }

    func withdraw(_ id: UUID) {
        guard let index = index(of: id), applications[index].isActive else { return }
        let event = ApplicationStatusEvent(status: .withdrawn, date: .now)
        applications[index].status = .withdrawn
        applications[index].events.append(event)
        save()
        pushStatus(of: id, status: .withdrawn, event: event)
    }

    /// "We brought them home!"
    func markAdopted(_ id: UUID) {
        guard let index = index(of: id), applications[index].status == .approved else { return }
        let event = ApplicationStatusEvent(status: .adopted, date: .now,
                                           note: "Welcome home, \(applications[index].pet.name)!")
        applications[index].status = .adopted
        applications[index].events.append(event)
        save()
        pushStatus(of: id, status: .adopted, event: event)
        startJourney(for: applications[index])
    }

    /// Creates the adoption journey and schedules its check-in reminders.
    private func startJourney(for application: AdoptionApplication) {
        guard let uid = userID else { return }
        Task {
            await NotificationManager.shared.askPermission(for: .journey)
            await JourneyService.ensureJourney(for: application, adopterID: uid)
            await NotificationManager.shared.scheduleJourneyReminders(
                applicationID: application.id.uuidString, petName: application.pet.name,
                adoptedAt: JourneyService.adoptedDate(of: application))
        }
    }

    func toggleChecklistItem(_ itemID: UUID, in id: UUID) {
        guard let index = index(of: id),
              let item = applications[index].checklist.firstIndex(where: { $0.id == itemID }) else { return }
        applications[index].checklist[item].isDone.toggle()
        save()
    }

    // MARK: - Reviewing (lister)

    /// The lister moves an application along. The adopter sees it right away.
    func updateStatus(_ applicationID: String, to status: ApplicationStatus, note: String?) {
        guard isConfigured else { return }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = ApplicationStatusEvent(status: status, date: .now, note: (cleanNote?.isEmpty ?? true) ? nil : cleanNote)
        db.collection("applications").document(applicationID).updateData([
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
            "events": FieldValue.arrayUnion([ApplicationJSON.text(event)]),
        ], completion: nil)
    }

    /// Writes an adopter-side status change (withdrawn / adopted) to the shared copy.
    private func pushStatus(of id: UUID, status: ApplicationStatus, event: ApplicationStatusEvent) {
        guard isConfigured else { return }
        db.collection("applications").document(id.uuidString).updateData([
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
            "events": FieldValue.arrayUnion([ApplicationJSON.text(event)]),
        ], completion: nil)
    }

    /// Run by iOS's background refresh: one quick look for decisions made while the app was closed.
    func backgroundCheck() async {
        guard isConfigured, let uid = Auth.auth().currentUser?.uid else { return }
        let snapshot = try? await db.collection("applications").whereField("adopterID", isEqualTo: uid).getDocuments()
        for document in snapshot?.documents ?? [] {
            merge(remote: document.data(with: .estimate), id: document.documentID)
        }
    }

    // MARK: - Storage

    private func index(of id: UUID) -> Int? {
        applications.firstIndex { $0.id == id }
    }

    private func filesFolder(for id: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ApplicationFiles/\(id.uuidString)", isDirectory: true)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([AdoptionApplication].self, from: data) else { return }
        applications = saved
    }

    private func save() {
        pendingSave?.cancel()
        do {
            try JSONEncoder().encode(applications).write(to: fileURL, options: .atomic)
        } catch {
            Log.storage.error("Couldn't save applications: \(error.localizedDescription)")
        }
    }
}
