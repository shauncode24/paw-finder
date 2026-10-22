import SwiftUI

/// Profile › Applications received: everyone who applied for one of your pets.
struct ReceivedApplicationsView: View {
    @Environment(ApplicationsStore.self) private var store

    var body: some View {
        Group {
            if store.received.isEmpty {
                EmptyStateView(icon: "tray", title: "No applications yet",
                               message: "When someone applies to adopt one of your pets, it shows up here and you'll get a notification.")
            } else {
                List {
                    section("New", applications(with: [.submitted]))
                    section("In progress", applications(with: [.inReview, .interview, .approved]))
                    section("Closed", applications(with: [.declined, .adopted, .withdrawn]))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Applications received")
    }

    private func applications(with statuses: [ApplicationStatus]) -> [ReceivedApplication] {
        store.received.filter { statuses.contains($0.status) }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [ReceivedApplication]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { application in
                    NavigationLink(value: Route.receivedApplication(application.id)) {
                        row(application)
                    }
                    .listRowBackground(Color.pfSurface)
                }
            }
        }
    }

    private func row(_ application: ReceivedApplication) -> some View {
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 52, height: 52)
                .overlay { PetPhoto(url: PhotoURL.thumbnail(of: application.listingID), species: application.petSpecies) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(application.adopterName)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Text("for \(application.petName) · \(application.submittedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                StatusBadge(status: application.status)
                    .font(.pfCaption)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// One application, from the lister's side: the adopter's answers, the status
/// history, and the buttons that move it along. The adopter sees changes right away.
struct ReceivedApplicationDetailView: View {
    let applicationID: String

    @Environment(ApplicationsStore.self) private var store
    @Environment(ListingsService.self) private var listings
    @Environment(MessagesStore.self) private var messages
    @Environment(ListerProfileStore.self) private var listerStore
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router

    @State private var note = ""
    @State private var errorMessage: String?
    @State private var showAnswers = true

    var body: some View {
        Group {
            if let application = store.receivedApplication(applicationID) {
                content(application)
            } else {
                EmptyStateView(icon: "doc", title: "Application not found", message: "It may have been withdrawn or removed.")
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Application")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil },
                                                       set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ application: ReceivedApplication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header(application)
                statusCard(application)
                actions(application)

                section("Timeline") { ApplicationTimeline(events: application.events) }

                DisclosureGroup("\(application.adopterName)'s answers", isExpanded: $showAnswers) {
                    ApplicationAnswers(form: application.form)
                }
                .tint(Color.pfTextPrimary)
            }
            .padding(Spacing.lg)
        }
    }

    private func header(_ application: ReceivedApplication) -> some View {
        NavigationLink(value: Route.petID(application.listingID)) {
            HStack(spacing: Spacing.md) {
                Color.clear
                    .frame(width: 64, height: 64)
                    .overlay { PetPhoto(url: PhotoURL.thumbnail(of: application.listingID), species: application.petSpecies) }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(application.adopterName)
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)
                    Text("wants to adopt \(application.petName)")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                    Text("Applied \(application.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func statusCard(_ application: ReceivedApplication) -> some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                StatusBadge(status: application.status)
                Text(application.status.listerExplanation)
                    .foregroundStyle(Color.pfTextPrimary)
            }
        }
    }

    /// The next steps that make sense for the current status.
    @ViewBuilder
    private func actions(_ application: ReceivedApplication) -> some View {
        let steps = nextSteps(for: application.status)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !steps.isEmpty {
                TextField("Add a note for \(application.adopterName) (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(Spacing.md)
                    .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))

                ForEach(steps, id: \.self) { step in
                    PFButton(title: step.buttonTitle, style: step == steps.first ? .primary : .secondary) {
                        apply(step, to: application)
                    }
                }
            }
            if application.status == .adopted {
                NavigationLink(value: Route.journey(applicationID: application.id)) {
                    Label("See \(application.petName)'s journey", systemImage: "heart.text.square")
                        .font(.pfHeadline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Color.pfSurfaceElevated)
                        .background(Color.pfBrandPrimary, in: RoundedRectangle(cornerRadius: Radius.medium))
                }
            }
            PFButton(title: "Message \(application.adopterName)", style: .secondary) {
                openChat(with: application)
            }
        }
    }

    private func nextSteps(for status: ApplicationStatus) -> [ListerStep] {
        switch status {
        case .submitted: [.startReview, .decline]
        case .inReview: [.interview, .approve, .decline]
        case .interview: [.approve, .decline]
        case .approved: [.markAdopted]
        default: []
        }
    }

    private func apply(_ step: ListerStep, to application: ReceivedApplication) {
        store.updateStatus(application.id, to: step.status, note: note)
        note = ""
        // Keep the listing in step with the application.
        guard let listingStatus = step.listingStatus else { return }
        Task {
            do {
                try await listings.setStatus(listingStatus, for: application.listingID)
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }

    private func openChat(with application: ReceivedApplication) {
        guard let me = auth.user else {
            router.showSignIn = true
            return
        }
        let myName = listerStore.profile?.publicName ?? me.displayName ?? "Lister"
        Task {
            do {
                let id = try await messages.openConversation(
                    listingID: application.listingID, listingName: application.petName,
                    listingSpecies: application.petSpecies, adopterID: application.adopterID,
                    adopterName: application.adopterName, listerID: me.id, listerName: myName)
                router.push(.conversation(id))
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            content()
        }
    }
}

/// What a lister can do with an application.
enum ListerStep: Hashable {
    case startReview, interview, approve, decline, markAdopted

    var buttonTitle: String {
        switch self {
        case .startReview: "Start reviewing"
        case .interview: "Invite for a chat or meeting"
        case .approve: "Approve"
        case .decline: "Decline"
        case .markAdopted: "Mark as adopted"
        }
    }

    var status: ApplicationStatus {
        switch self {
        case .startReview: .inReview
        case .interview: .interview
        case .approve: .approved
        case .decline: .declined
        case .markAdopted: .adopted
        }
    }

    /// How the pet's listing should change (approved = pending, adopted = adopted).
    var listingStatus: ListingStatus? {
        switch self {
        case .approve: .pending
        case .markAdopted: .adopted
        default: nil
        }
    }
}

extension ApplicationStatus {
    /// What this status means, from the lister's side.
    var listerExplanation: String {
        switch self {
        case .draft: "Not submitted yet."
        case .submitted: "A new application. Read their answers, then start reviewing or decline."
        case .inReview: "You're reviewing this application. Chat with them, then invite them or decide."
        case .interview: "You've invited them to talk or meet. Approve or decline when you've decided."
        case .approved: "Approved. The listing is marked pending. Mark it adopted once they take the pet home."
        case .declined: "You declined this application."
        case .adopted: "This pet found a home. 🎉"
        case .withdrawn: "The adopter withdrew this application."
        }
    }
}

/// The adopter's answers, as plain text rows.
struct ApplicationAnswers: View {
    let form: ApplicationForm

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            row("Name", form.fullName)
            row("Email", form.email)
            row("Phone", form.phone)
            row("Address", form.address)
            row("Home", form.homeSummary)
            row("Household", form.householdSummary)
            row("Fenced yard", form.hasFencedYard ? "Yes" : "No")
            row("Landlord allows pets", landlordText)
            row("Experience", form.experience?.rawValue ?? "")
            row("Current pets", form.currentPets)
            row("Vet", [form.vetName, form.vetPhone].filter { !$0.isEmpty }.joined(separator: " · "))
            row("Alone per day", "Up to \(form.hoursAlonePerDay) hours")
            row("Why this pet", form.whyThisPet)
            row("Best times to meet", form.preferredMeetTimes)
            row("Home visit OK", form.agreesToHomeVisit ? "Yes" : "No")
        }
        .padding(.top, Spacing.sm)
    }

    private var landlordText: String {
        if form.ownsHome != false { return "Owns their home" }
        return form.landlordAllowsPets ? "Yes" : "No"
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.pfCaption).foregroundStyle(Color.pfTextSecondary)
            Text(value.isEmpty ? "—" : value).foregroundStyle(Color.pfTextPrimary)
        }
    }
}
