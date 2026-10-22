import SwiftUI

/// Lets the user flag a listing as wrong or inappropriate. Reports are saved in
/// Firestore (`reports`) for a moderator to read (see docs/Listers-and-Messaging.md).
struct ReportListingSheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(ListingsService.self) private var listings

    @State private var reason: Reason = .alreadyAdopted
    @State private var details = ""
    @State private var submitted = false

    enum Reason: String, CaseIterable {
        case alreadyAdopted = "Pet is already adopted"
        case wrongInfo = "Information is wrong"
        case inappropriate = "Inappropriate photos or text"
        case scam = "Looks like a scam"
        case other = "Something else"
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    EmptyStateView(icon: "checkmark.circle", title: "Thanks for letting us know",
                                   message: "We'll take a look at \(pet.name)'s listing.",
                                   buttonTitle: "Done") { dismiss() }
                } else {
                    form
                }
            }
            .background(Color.pfBackground)
            .navigationTitle("Report listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section("What's wrong?") {
                Picker("Reason", selection: $reason) {
                    ForEach(Reason.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("More details (optional)") {
                TextField("Anything else we should know?", text: $details, axis: .vertical)
                    .lineLimit(3...6)
            }
            Section {
                PFButton(title: "Send report") { submit() }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func submit() {
        let service = listings
        let petID = pet.id
        let chosenReason = reason.rawValue
        let extra = details
        // Fire and forget: the report is queued even if the phone is offline.
        Task { await service.report(listingID: petID, reason: chosenReason, details: extra) }
        withAnimation { submitted = true }
    }
}

#Preview {
    ReportListingSheet(pet: MockPetRepository.samplePets[0])
        .environment(ListingsService())
}
