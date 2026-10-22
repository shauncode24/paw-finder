import PhotosUI
import SwiftUI

/// The adoption application, one step at a time. Every change is saved as a
/// draft automatically, so the user can leave and come back.
struct ApplicationFormView: View {
    let applicationID: UUID

    enum Step: Int, CaseIterable {
        case aboutYou, home, pets, plans, documents, review

        var title: String {
            switch self {
            case .aboutYou: "About you"
            case .home: "Your home"
            case .pets: "Pets & experience"
            case .plans: "Your plans"
            case .documents: "Documents"
            case .review: "Review & submit"
            }
        }
    }

    @Environment(ApplicationsStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var form = ApplicationForm()
    @State private var step: Step = .aboutYou
    @State private var showErrors = false
    @State private var submitted = false
    @State private var confirmDelete = false

    private var application: AdoptionApplication? { store.application(applicationID) }

    var body: some View {
        Group {
            if let application {
                if submitted {
                    submittedView(application)
                } else {
                    formBody(application)
                }
            } else {
                EmptyStateView(icon: "doc", title: "Application not found", message: "It may have been deleted.")
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Apply for \(application?.pet.name ?? "pet")")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let application { form = application.form }
        }
        .onChange(of: form) { _, newForm in
            store.updateForm(applicationID, newForm)
        }
        .alert("Couldn't send your application", isPresented: Binding(get: { submitError != nil },
                                                                    set: { if !$0 { submitError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(submitError ?? "")
        }
    }

    // MARK: - Form

    private func formBody(_ application: AdoptionApplication) -> some View {
        VStack(spacing: 0) {
            progressHeader
            stepContent(application)
        }
        .safeAreaInset(edge: .bottom) { navigationBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete draft", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .confirmationDialog("Delete this draft?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete draft", role: .destructive) {
                store.deleteDraft(applicationID)
                dismiss()
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count): \(step.title)")
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Spacer()
                Text("Saved as you type")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .tint(Color.pfBrandPrimary)
        }
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private func stepContent(_ application: AdoptionApplication) -> some View {
        Form {
            switch step {
            case .aboutYou: aboutYou
            case .home: home
            case .pets: pets
            case .plans: plans(petName: application.pet.name)
            case .documents: documents(application)
            case .review: review(application)
            }

            if showErrors, !errors(for: step).isEmpty {
                Section {
                    ForEach(errors(for: step), id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.pfError)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var navigationBar: some View {
        HStack(spacing: Spacing.md) {
            if step != .aboutYou {
                PFButton(title: "Back", style: .secondary) { move(by: -1) }
            }
            if step == .review {
                PFButton(title: "Submit application", isLoading: isSubmitting) { submit() }
            } else {
                PFButton(title: "Next") { next() }
            }
        }
        .padding(Spacing.lg)
        .background(Color.pfBackground)
    }

    // MARK: - Steps

    @ViewBuilder
    private var aboutYou: some View {
        Section {
            TextField("Full name", text: $form.fullName)
                .textContentType(.name)
            TextField("Email", text: $form.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Phone", text: $form.phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            TextField("Home address", text: $form.address, axis: .vertical)
                .textContentType(.fullStreetAddress)
        } footer: {
            Text("The lister sees these when you submit, and uses them to contact you.")
        }
        Section {
            Toggle("I'm 18 or older", isOn: $form.isAdult)
        }
    }

    @ViewBuilder
    private var home: some View {
        Section("Home") {
            Picker("Type of home", selection: $form.homeType) {
                Text("Choose").tag(AdopterProfile.HomeType?.none)
                ForEach(AdopterProfile.HomeType.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }
            Picker("Own or rent?", selection: $form.ownsHome) {
                Text("Own").tag(Bool?.some(true))
                Text("Rent").tag(Bool?.some(false))
            }
            .pickerStyle(.segmented)
            if form.ownsHome == false {
                Toggle("My landlord allows pets", isOn: $form.landlordAllowsPets)
            }
            Toggle("Fenced yard", isOn: $form.hasFencedYard)
        }
        Section("Who lives there") {
            Stepper("Adults: \(form.adultsInHome)", value: $form.adultsInHome, in: 1...10)
            Picker("Kids", selection: $form.kids) {
                Text("Choose").tag(AdopterProfile.KidsAtHome?.none)
                ForEach(AdopterProfile.KidsAtHome.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }
        }
    }

    @ViewBuilder
    private var pets: some View {
        Section("Experience") {
            Picker("Pet experience", selection: $form.experience) {
                Text("Choose").tag(AdopterProfile.Experience?.none)
                ForEach(AdopterProfile.Experience.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }
        }
        Section("Current pets") {
            TextField("e.g. one 5-year-old cat, spayed", text: $form.currentPets, axis: .vertical)
                .lineLimit(2...4)
        }
        Section {
            TextField("Vet's name or clinic", text: $form.vetName)
            TextField("Vet's phone", text: $form.vetPhone)
                .keyboardType(.phonePad)
        } header: {
            Text("Vet reference (optional)")
        } footer: {
            Text("If you've had pets before, listers often call your vet.")
        }
    }

    @ViewBuilder
    private func plans(petName: String) -> some View {
        Section("Daily routine") {
            Stepper("Alone up to \(form.hoursAlonePerDay) hours a day", value: $form.hoursAlonePerDay, in: 0...12)
        }
        Section("Why \(petName)?") {
            TextField("What made you want to adopt \(petName)?", text: $form.whyThisPet, axis: .vertical)
                .lineLimit(3...8)
        }
        Section {
            TextField("e.g. weekday evenings, Saturday mornings", text: $form.preferredMeetTimes, axis: .vertical)
        } header: {
            Text("Best times to meet (optional)")
        }
    }

    @ViewBuilder
    private func documents(_ application: AdoptionApplication) -> some View {
        Section {
            ForEach(ApplicationAttachment.Kind.allCases, id: \.self) { kind in
                AttachmentRow(applicationID: applicationID, kind: kind,
                              attachments: application.attachments.filter { $0.kind == kind })
            }
        } footer: {
            Text("Optional, but some listers ask for these. For your privacy, these photos stay on this phone and are not uploaded.")
        }
    }

    @ViewBuilder
    private func review(_ application: AdoptionApplication) -> some View {
        Section("You") {
            summaryRow("Name", form.fullName)
            summaryRow("Contact", [form.email, form.phone].filter { !$0.isEmpty }.joined(separator: " · "))
            summaryRow("Address", form.address)
            editButton(.aboutYou)
        }
        Section("Home") {
            summaryRow("Home", form.homeSummary)
            summaryRow("Household", form.householdSummary)
            editButton(.home)
        }
        Section("Pets & plans") {
            summaryRow("Experience", form.experience?.rawValue ?? "")
            summaryRow("Alone", "Up to \(form.hoursAlonePerDay) hours a day")
            summaryRow("Documents", application.attachments.isEmpty ? "None" : "\(application.attachments.count) attached")
            editButton(.plans)
        }
        Section {
            Toggle("I agree to a home visit if the lister asks", isOn: $form.agreesToHomeVisit)
            Toggle("Everything I've written is true", isOn: $form.confirmsAccurate)
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value.isEmpty ? "Not answered" : value)
    }

    private func editButton(_ target: Step) -> some View {
        Button("Edit") { withAnimation { step = target } }
            .font(.subheadline)
    }

    // MARK: - Validation & navigation

    private func errors(for step: Step) -> [String] {
        var errors: [String] = []
        switch step {
        case .aboutYou:
            if form.fullName.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Enter your full name.") }
            if !form.email.contains("@") || !form.email.contains(".") { errors.append("Enter a valid email.") }
            if form.phone.filter(\.isNumber).count < 7 { errors.append("Enter a phone number.") }
            if form.address.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Enter your address.") }
            if !form.isAdult { errors.append("You must be 18 or older to adopt.") }
        case .home:
            if form.homeType == nil { errors.append("Choose your type of home.") }
            if form.ownsHome == nil { errors.append("Tell us if you own or rent.") }
        case .pets:
            if form.experience == nil { errors.append("Choose your pet experience.") }
        case .plans:
            if form.whyThisPet.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
                errors.append("Tell the lister a little more about why (at least a sentence).")
            }
        case .documents:
            break
        case .review:
            if !form.agreesToHomeVisit || !form.confirmsAccurate { errors.append("Please agree to both statements.") }
            // Catch anything skipped by jumping around with "Edit".
            for earlier in Step.allCases where earlier != .review && !self.errors(for: earlier).isEmpty {
                errors.append("Finish the \"\(earlier.title)\" step.")
            }
        }
        return errors
    }

    private func next() {
        guard errors(for: step).isEmpty else {
            withAnimation { showErrors = true }
            return
        }
        move(by: 1)
    }

    private func move(by offset: Int) {
        guard let target = Step(rawValue: step.rawValue + offset) else { return }
        showErrors = false
        withAnimation { step = target }
    }

    private func submit() {
        guard errors(for: .review).isEmpty else {
            withAnimation { showErrors = true }
            return
        }
        // Applications go to a real person, so an account is needed. The draft is kept.
        guard auth.user != nil else {
            router.showSignIn = true
            return
        }
        store.updateForm(applicationID, form)
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await store.submit(applicationID, adopterName: form.fullName)
                withAnimation { submitted = true }
            } catch {
                submitError = error.localizedDescription
            }
        }
    }

    // MARK: - Confirmation

    private func submittedView(_ application: AdoptionApplication) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.pfSuccess)
                .symbolEffect(.bounce, value: submitted)
                .accessibilityHidden(true)
            Text("Application sent!")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.pfTextPrimary)
            Text("\(application.shelterName ?? "The lister") will review your application for \(application.pet.name). We'll notify you when anything changes. You can also message them from the tracker.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pfTextSecondary)
            Spacer()
            PFButton(title: "Track your application") {
                router.replaceTop(with: .applicationDetail(applicationID))
            }
            PFButton(title: "Done", style: .secondary) { dismiss() }
        }
        .padding(Spacing.xl)
        .sensoryFeedback(.success, trigger: submitted)
    }
}

/// One document type in the Documents step: thumbnails plus an "Add" button.
private struct AttachmentRow: View {
    let applicationID: UUID
    let kind: ApplicationAttachment.Kind
    let attachments: [ApplicationAttachment]

    @Environment(ApplicationsStore.self) private var store
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(kind.rawValue)
                Spacer()
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Add", systemImage: "plus.circle.fill")
                }
            }
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(attachments) { attachment in
                            AttachmentThumbnail(url: store.fileURL(for: attachment, in: applicationID))
                                .contextMenu {
                                    Button("Remove", systemImage: "trash", role: .destructive) {
                                        store.removeAttachment(attachment, from: applicationID)
                                    }
                                }
                        }
                    }
                }
                Text("Long-press a photo to remove it.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.addAttachment(to: applicationID, kind: kind, imageData: data)
                }
                pickedItem = nil
            }
        }
    }
}

/// A small square preview of an attached photo.
struct AttachmentThumbnail: View {
    let url: URL
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc").foregroundStyle(Color.pfTextSecondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.pfBrandDeep)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
        .accessibilityLabel("Attached photo")
    }
}
