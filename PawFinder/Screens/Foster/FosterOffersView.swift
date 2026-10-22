import SwiftUI

/// Profile › Foster offers. Listers see offers for their pets and accept or decline;
/// volunteers see the offers they sent and can withdraw them. Both can open a chat.
struct FosterOffersView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case received = "Received"
        case sent = "Sent"
        var id: String { rawValue }
    }

    @Environment(FosterStore.self) private var fosters
    @Environment(ListingsService.self) private var listings
    @Environment(MessagesStore.self) private var messages
    @Environment(ListerProfileStore.self) private var listerStore
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router

    @State private var tab: Tab = .received
    @State private var didChooseTab = false
    @State private var errorMessage: String?
    @State private var busyID: String?

    private var shown: [FosterOffer] { tab == .received ? fosters.received : fosters.sent }

    var body: some View {
        Group {
            if auth.user == nil {
                EmptyStateView(icon: "house.and.flag", title: "Sign in to see offers",
                               message: "Foster offers go through your account.",
                               buttonTitle: "Sign in") { router.showSignIn = true }
            } else {
                content
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Foster offers")
        .task(id: fosters.offersLoaded) { chooseStartingTab() }
        .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil },
                                                       set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Picker("Which offers", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.lg)

            if !fosters.offersLoaded {
                LoadingView(message: "Loading offers...")
            } else if shown.isEmpty {
                EmptyStateView(
                    icon: "house.and.flag",
                    title: tab == .received ? "No offers yet" : "You haven't offered to foster",
                    message: tab == .received
                        ? "When a pet of yours is marked \"Needs a foster\", volunteers can offer to help. You can also invite volunteers from the directory."
                        : "Pets that need a foster show a badge in Discover. Open one and tap \"Offer to foster\".")
            } else {
                List {
                    ForEach(shown) { offer in
                        row(offer)
                            .listRowBackground(Color.pfSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Rows

    private func row(_ offer: FosterOffer) -> some View {
        let isReceived = offer.listerID == auth.user?.id
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Color.clear
                    .frame(width: 52, height: 52)
                    .overlay { PetPhoto(url: PhotoURL.thumbnail(of: offer.listingID), species: offer.listingSpecies) }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isReceived ? "\(offer.fosterName) offers to foster \(offer.listingName)"
                                    : "Your offer to foster \(offer.listingName)")
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                    Text("\(offer.duration.rawValue) · \(offer.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }
            if !offer.message.isEmpty {
                Text(offer.message).foregroundStyle(Color.pfTextPrimary)
            }
            Label(offer.status.label, systemImage: offer.status.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(offer.status == .accepted ? Color.pfSuccess : Color.pfTextSecondary)

            actions(offer, isReceived: isReceived)
        }
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private func actions(_ offer: FosterOffer, isReceived: Bool) -> some View {
        let alreadyPlaced = listings.myListings.first { $0.id == offer.listingID }?.isInFosterCare == true
        HStack(spacing: Spacing.md) {
            if isReceived, offer.status == .pending {
                if alreadyPlaced {
                    Text("\(offer.listingName) already has a foster.")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                } else {
                    Button("Accept") { respond(offer, accept: true) }
                        .buttonStyle(.borderedProminent)
                }
                Button("Decline") { respond(offer, accept: false) }
                    .buttonStyle(.bordered)
            }
            if !isReceived, offer.status == .pending {
                Button("Withdraw", role: .destructive) { fosters.withdraw(offer) }
                    .buttonStyle(.bordered)
            }
            Button {
                openChat(offer, isReceived: isReceived)
            } label: {
                Label("Message", systemImage: "bubble.left")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .tint(Color.pfBrandPrimary)
        .font(.subheadline)
        .disabled(busyID == offer.id)
    }

    // MARK: - Actions

    /// Lister with offers → "Received"; volunteer → "Sent".
    private func chooseStartingTab() {
        guard fosters.offersLoaded, !didChooseTab else { return }
        didChooseTab = true
        if fosters.received.isEmpty, !fosters.sent.isEmpty { tab = .sent }
    }

    private func respond(_ offer: FosterOffer, accept: Bool) {
        busyID = offer.id
        Task {
            defer { busyID = nil }
            do {
                try await fosters.respond(to: offer, accept: accept)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Chat is about the pet. The volunteer takes the "other person" role in the chat.
    private func openChat(_ offer: FosterOffer, isReceived: Bool) {
        guard let me = auth.user else { return }
        Task {
            do {
                let id: String
                if isReceived {
                    id = try await messages.openConversation(
                        listingID: offer.listingID, listingName: offer.listingName, listingSpecies: offer.listingSpecies,
                        adopterID: offer.fosterID, adopterName: offer.fosterName,
                        listerID: me.id, listerName: listerStore.profile?.publicName ?? offer.listerName)
                } else {
                    id = try await messages.openConversation(
                        listingID: offer.listingID, listingName: offer.listingName, listingSpecies: offer.listingSpecies,
                        adopterID: me.id, adopterName: offer.fosterName,
                        listerID: offer.listerID, listerName: offer.listerName)
                }
                router.push(.conversation(id))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// The sheet a volunteer uses to offer to foster a pet.
struct FosterOfferSheet: View {
    let pet: Pet
    let listerName: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(FosterStore.self) private var fosters
    @State private var message = ""
    @State private var duration: FosterDuration = .weeks
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if sent { sentView } else { form }
            }
            .background(Color.pfBackground)
            .navigationTitle("Offer to foster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(sent ? "Done" : "Cancel") { dismiss() } }
            }
            .onAppear {
                if let wanted = FosterDuration(rawValue: pet.fosterDuration ?? "") { duration = wanted }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Foster \(pet.name)")
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)
                if let reason = pet.fosterReason {
                    Text("\(listerName ?? "The lister") says: \(reason)")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                Picker("How long can you foster?", selection: $duration) {
                    ForEach(FosterDuration.allCases) { Text($0.rawValue).tag($0) }
                }
                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)
                    .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                    .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                    .onChange(of: message) { _, value in
                        if value.count > 500 { message = String(value.prefix(500)) }
                    }
                Text("Say a little about your home and why you'd be a good fit (optional). The lister also sees your foster profile.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                if let errorMessage {
                    Text(errorMessage).font(.subheadline).foregroundStyle(Color.pfError)
                }
                PFButton(title: "Send offer", isLoading: isSending) { Task { await send() } }
            }
            .padding(Spacing.lg)
        }
    }

    private var sentView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.pfBrandPrimary)
            Text("Offer sent")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.pfTextPrimary)
            Text("\(listerName ?? "The lister") will see it and can accept or decline. You'll be notified.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pfTextSecondary)
        }
        .padding(Spacing.xl)
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await fosters.sendOffer(for: pet, listerName: listerName, message: message, duration: duration)
            sent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
