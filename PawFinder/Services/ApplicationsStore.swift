import UIKit

/// Adoption applications, saved on the device (Documents/applications.json,
/// with attached photos in Documents/ApplicationFiles/).
///
/// There's no shelter on the other end, so a **simulated shelter** answers:
/// when you submit, it plans replies a few minutes apart (in review →
/// interview → decision). `refresh()` applies the ones whose time has come,
/// and local notifications fire at the same times.
@MainActor
@Observable
final class ApplicationsStore {
    private(set) var applications: [AdoptionApplication] = []

    /// How long the simulated shelter takes for each step (fast, for demos).
    static let simulatedReplyDelays: [TimeInterval] = [60, 3 * 60, 6 * 60]

    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("applications.json")
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    init() {
        load()
        refresh()
    }

    func application(_ id: UUID) -> AdoptionApplication? {
        applications.first { $0.id == id }
    }

    /// The draft or active application for a pet, if any (one per pet).
    func openApplication(for petID: String) -> AdoptionApplication? {
        applications.first { $0.pet.id == petID && !$0.isClosed }
    }

    // MARK: - Drafts

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

        let application = AdoptionApplication(pet: pet, shelterName: shelterName, form: form)
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

    /// Erase every application and attachment (Settings › Erase all data).
    func removeAll() {
        for application in applications { NotificationManager.shared.cancelApplicationUpdates(application.id) }
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

    // MARK: - Attachments

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

    // MARK: - Submit / withdraw / adopt

    func submit(_ id: UUID) {
        guard let index = index(of: id), applications[index].status == .draft else { return }
        let now = Date.now
        applications[index].status = .submitted
        applications[index].submittedAt = now
        applications[index].events = [ApplicationStatusEvent(status: .submitted, date: now)]
        applications[index].scheduledEvents = Self.simulatedReplies(for: applications[index], submittedAt: now)
        save()
        let application = applications[index]
        Task {
            await NotificationManager.shared.askPermission(for: .applications)
            await NotificationManager.shared.scheduleApplicationUpdates(application)
        }
    }

    /// After the user turns notifications on, schedule the ones we couldn't before.
    func rescheduleNotifications() async {
        for application in applications where application.isActive && !application.scheduledEvents.isEmpty {
            await NotificationManager.shared.scheduleApplicationUpdates(application)
        }
    }

    func withdraw(_ id: UUID) {
        guard let index = index(of: id), applications[index].isActive else { return }
        applications[index].status = .withdrawn
        applications[index].events.append(ApplicationStatusEvent(status: .withdrawn, date: .now))
        applications[index].scheduledEvents = []
        save()
        NotificationManager.shared.cancelApplicationUpdates(id)
    }

    /// "We brought them home!"
    func markAdopted(_ id: UUID) {
        guard let index = index(of: id), applications[index].status == .approved else { return }
        applications[index].status = .adopted
        applications[index].events.append(ApplicationStatusEvent(status: .adopted, date: .now,
                                                                  note: "Welcome home, \(applications[index].pet.name)!"))
        save()
    }

    func toggleChecklistItem(_ itemID: UUID, in id: UUID) {
        guard let index = index(of: id),
              let item = applications[index].checklist.firstIndex(where: { $0.id == itemID }) else { return }
        applications[index].checklist[item].isDone.toggle()
        save()
    }

    // MARK: - Simulated shelter

    /// Applies any simulated shelter replies whose time has passed.
    /// Called on launch, when the app comes back to the foreground, and while
    /// an application is on screen.
    func refresh(now: Date = .now) {
        var changed = false
        for index in applications.indices where applications[index].isActive {
            while let next = applications[index].scheduledEvents.first, next.date <= now {
                applications[index].scheduledEvents.removeFirst()
                apply(next, at: index)
                changed = true
            }
        }
        if changed { save() }
    }

    /// Debug helper: make the shelter's next reply happen right now.
    func simulateNextReply(_ id: UUID) {
        guard let index = index(of: id), !applications[index].scheduledEvents.isEmpty else { return }
        let next = applications[index].scheduledEvents.removeFirst()
        apply(ApplicationStatusEvent(status: next.status, date: .now, note: next.note), at: index)
        save()
        NotificationManager.shared.cancelApplicationUpdate(id, status: next.status)
    }

    private func apply(_ event: ApplicationStatusEvent, at index: Int) {
        applications[index].status = event.status
        applications[index].events.append(event)
        if event.status == .approved, applications[index].checklist.isEmpty {
            applications[index].checklist = ChecklistItem.afterApproval
        }
    }

    /// The shelter's planned replies. It approves unless something in the
    /// answers is a clear blocker (like renting without the landlord's OK).
    private static func simulatedReplies(for application: AdoptionApplication, submittedAt: Date) -> [ApplicationStatusEvent] {
        let form = application.form
        let shelter = application.shelterName ?? "The shelter"
        let dates = simulatedReplyDelays.map { submittedAt.addingTimeInterval($0) }

        var declineReason: String?
        if form.ownsHome == false, !form.landlordAllowsPets {
            declineReason = "Your landlord needs to allow pets before we can place \(application.pet.name) with you."
        } else if form.hoursAlonePerDay >= 10 {
            declineReason = "\(application.pet.name) needs more company than a 10+ hour day alone allows."
        }

        var replies = [
            ApplicationStatusEvent(status: .inReview, date: dates[0],
                                   note: "\(shelter) received your application and is reviewing it."),
        ]
        if let declineReason {
            replies.append(ApplicationStatusEvent(status: .declined, date: dates[1], note: declineReason))
        } else {
            let contact = form.phone.isEmpty ? form.email : form.phone
            replies.append(ApplicationStatusEvent(
                status: .interview, date: dates[1],
                note: "\(shelter) would like to chat and arrange a meet-and-greet. They'll contact you at \(contact)."
            ))
            replies.append(ApplicationStatusEvent(
                status: .approved, date: dates[2],
                note: "Great news: you're approved to adopt \(application.pet.name)!"
            ))
        }
        return replies
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
