import SwiftUI

/// Tracks one application: status, timeline, checklist (once approved),
/// documents, and your answers.
struct ApplicationDetailView: View {
    let applicationID: UUID

    @Environment(ApplicationsStore.self) private var store
    @Environment(MessagesStore.self) private var messages
    @Environment(Router.self) private var router
    @State private var confirmWithdraw = false
    @State private var showAnswers = false

    var body: some View {
        Group {
            if let application = store.application(applicationID) {
                content(application)
            } else {
                EmptyStateView(icon: "doc", title: "Application not found", message: "It may have been deleted.")
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Application")
        .navigationBarTitleDisplayMode(.inline)
        // Check for simulated shelter replies while this screen is open.
        .task {
            while !Task.isCancelled {
                store.refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func content(_ application: AdoptionApplication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                petHeader(application)
                statusCard(application)

                if application.status == .approved || application.status == .adopted {
                    checklist(application)
                }

                section("Timeline") { ApplicationTimeline(application: application) }

                if !application.attachments.isEmpty {
                    section("Documents") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(application.attachments) { attachment in
                                    VStack(spacing: Spacing.xs) {
                                        AttachmentThumbnail(url: store.fileURL(for: attachment, in: applicationID))
                                        Text(attachment.kind.rawValue)
                                            .font(.pfCaption)
                                            .foregroundStyle(Color.pfTextSecondary)
                                            .lineLimit(1)
                                            .frame(width: 72)
                                    }
                                }
                            }
                        }
                    }
                }

                DisclosureGroup("Your answers", isExpanded: $showAnswers) {
                    answers(application.form)
                }
                .tint(Color.pfTextPrimary)

                actions(application)
            }
            .padding(Spacing.lg)
        }
        .confirmationDialog("Withdraw this application?", isPresented: $confirmWithdraw, titleVisibility: .visible) {
            Button("Withdraw", role: .destructive) { store.withdraw(applicationID) }
        } message: {
            Text("The shelter will stop reviewing it. You can apply again later.")
        }
    }

    // MARK: - Sections

    private func petHeader(_ application: AdoptionApplication) -> some View {
        NavigationLink(value: Route.petDetail(application.pet)) {
            HStack(spacing: Spacing.md) {
                Color.clear
                    .frame(width: 64, height: 64)
                    .overlay { PetPhoto(url: application.pet.thumbnailURL, species: application.pet.species) }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(application.pet.name)
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)
                    Text(application.shelterName ?? application.pet.location)
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                    if let submitted = application.submittedAt {
                        Text("Submitted \(submitted.formatted(date: .abbreviated, time: .shortened))")
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func statusCard(_ application: AdoptionApplication) -> some View {
        let latestNote = application.events.last?.note
        return PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                StatusBadge(status: application.status)
                Text(latestNote ?? application.status.explanation)
                    .foregroundStyle(Color.pfTextPrimary)
                if let next = application.scheduledEvents.first {
                    Text("Next update expected \(next.date.formatted(.relative(presentation: .named))).")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }
        }
    }

    private func checklist(_ application: AdoptionApplication) -> some View {
        let done = application.checklist.filter(\.isDone).count
        return section("Bring \(application.pet.name) home") {
            PFCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ProgressView(value: Double(done), total: Double(max(application.checklist.count, 1)))
                        .tint(Color.pfSuccess)
                    Text("\(done) of \(application.checklist.count) done")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                    ForEach(application.checklist) { item in
                        Button {
                            store.toggleChecklistItem(item.id, in: applicationID)
                        } label: {
                            Label {
                                Text(item.title)
                                    .strikethrough(item.isDone)
                                    .foregroundStyle(item.isDone ? Color.pfTextSecondary : Color.pfTextPrimary)
                                    .multilineTextAlignment(.leading)
                            } icon: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? Color.pfSuccess : Color.pfBorder)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(item.isDone ? .isSelected : [])
                        .sensoryFeedback(.selection, trigger: item.isDone)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ application: AdoptionApplication) -> some View {
        VStack(spacing: Spacing.sm) {
            if application.status == .approved {
                PFButton(title: "We brought \(application.pet.name) home!") {
                    store.markAdopted(applicationID)
                }
            }
            if !application.isClosed {
                PFButton(title: "Message the shelter", style: .secondary) {
                    let id = messages.startConversation(shelterID: application.pet.shelterID,
                                                        shelterName: application.shelterName ?? "Shelter",
                                                        pet: application.pet)
                    router.push(.conversation(id))
                }
            }
            if application.isActive {
                Button("Withdraw application", role: .destructive) { confirmWithdraw = true }
                    .font(.subheadline)
            }
            #if DEBUG
            if !application.scheduledEvents.isEmpty {
                Button("Demo: simulate the shelter's next reply now") {
                    store.simulateNextReply(applicationID)
                }
                .font(.pfCaption)
            }
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    private func answers(_ form: ApplicationForm) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            answer("Name", form.fullName)
            answer("Email", form.email)
            answer("Phone", form.phone)
            answer("Address", form.address)
            answer("Home", [form.homeType?.rawValue, form.ownsHome.map { $0 ? "Own" : "Rent" }]
                .compactMap { $0 }.joined(separator: " · "))
            answer("Adults at home", "\(form.adultsInHome)")
            answer("Kids", form.kids?.rawValue ?? "")
            answer("Fenced yard", form.hasFencedYard ? "Yes" : "No")
            answer("Experience", form.experience?.rawValue ?? "")
            answer("Current pets", form.currentPets)
            answer("Vet", [form.vetName, form.vetPhone].filter { !$0.isEmpty }.joined(separator: " · "))
            answer("Alone per day", "Up to \(form.hoursAlonePerDay) hours")
            answer("Why this pet", form.whyThisPet)
            answer("Meet-and-greet times", form.preferredMeetTimes)
        }
        .padding(.top, Spacing.sm)
    }

    private func answer(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.pfCaption).foregroundStyle(Color.pfTextSecondary)
            Text(value.isEmpty ? "—" : value).foregroundStyle(Color.pfTextPrimary)
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

/// Coloured pill with the status name.
struct StatusBadge: View {
    let status: ApplicationStatus

    var body: some View {
        Label(status.rawValue, systemImage: status.icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .approved, .adopted: .pfSuccess
        case .declined: .pfError
        case .withdrawn, .draft: .pfTextSecondary
        default: .pfBrandPrimary
        }
    }
}

/// Submitted → In review → Interview → Decision → Adopted, with dates for
/// the steps that happened and grey dots for the ones still to come.
struct ApplicationTimeline: View {
    let application: AdoptionApplication

    private struct Row: Identifiable {
        let id: String
        let title: String
        let icon: String
        let date: Date?
        let note: String?
        let isDone: Bool
        let isBad: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top, spacing: Spacing.md) {
                    VStack(spacing: 0) {
                        Image(systemName: row.isDone ? row.icon : "circle")
                            .font(.subheadline)
                            .foregroundStyle(row.isBad ? Color.pfError : (row.isDone ? Color.pfBrandPrimary : Color.pfBorder))
                            .frame(width: 28, height: 28)
                        if index < rows.count - 1 {
                            Rectangle()
                                .fill(row.isDone ? Color.pfBrandLight : Color.pfBorder)
                                .frame(width: 2)
                                .frame(minHeight: 24)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.pfHeadline)
                            .foregroundStyle(row.isDone ? Color.pfTextPrimary : Color.pfTextSecondary)
                        if let date = row.date {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.pfCaption)
                                .foregroundStyle(Color.pfTextSecondary)
                        }
                        if let note = row.note {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                    .padding(.bottom, Spacing.md)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var rows: [Row] {
        func event(_ status: ApplicationStatus) -> ApplicationStatusEvent? {
            application.events.last { $0.status == status }
        }
        func row(_ status: ApplicationStatus, title: String? = nil, isBad: Bool = false) -> Row {
            let happened = event(status)
            return Row(id: status.rawValue, title: title ?? status.rawValue, icon: status.icon,
                       date: happened?.date, note: happened?.note, isDone: happened != nil, isBad: isBad)
        }

        var rows = [row(.submitted), row(.inReview), row(.interview)]
        if event(.declined) != nil {
            rows.append(row(.declined, isBad: true))
        } else {
            rows.append(row(.approved))
            rows.append(row(.adopted, title: "Adopted"))
        }
        if event(.withdrawn) != nil {
            // Drop the steps that will never happen now.
            rows = rows.filter(\.isDone) + [row(.withdrawn, isBad: true)]
        }
        return rows
    }
}
