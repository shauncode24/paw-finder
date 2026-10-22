import SwiftUI

/// The filter sheet. Edits a copy of the filters; nothing changes until "Show results".
struct FilterSheet: View {
    @State private var draft: PetFilters
    @State private var isLocating = false
    @State private var locationError: String?
    let onApply: (PetFilters) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var locationService

    private let distances = [10, 25, 50, 100, 250]

    init(filters: PetFilters, onApply: @escaping (PetFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    section("Species") {
                        chips(PetFilters.Species.allCases, isSelected: { draft.species == $0 }) { species in
                            draft.species = draft.species == species ? nil : species
                            draft.breed = nil   // breed belongs to the old species
                        }
                    }

                    if let breed = draft.breed {
                        section("Breed") {
                            PFChip(title: "\(breed)  ✕", isSelected: true) { draft.breed = nil }
                        }
                    }

                    section("Age") {
                        chips(PetFilters.Age.allCases, isSelected: { draft.ages.contains($0) }) { age in
                            draft.ages.formSymmetricDifference([age])
                        }
                    }

                    section("Size") {
                        chips(PetFilters.Size.allCases, isSelected: { draft.sizes.contains($0) }) { size in
                            draft.sizes.formSymmetricDifference([size])
                        }
                    }

                    section("Coat") {
                        chips(PetFilters.Coat.allCases, isSelected: { draft.coats.contains($0) }) { coat in
                            draft.coats.formSymmetricDifference([coat])
                        }
                    }

                    section("Gender") {
                        chips(PetFilters.Gender.allCases, isSelected: { draft.gender == $0 }) { gender in
                            draft.gender = draft.gender == gender ? nil : gender
                        }
                    }

                    section("Good with") {
                        VStack(spacing: Spacing.sm) {
                            Toggle("Kids", isOn: $draft.goodWithKids)
                            Toggle("Dogs", isOn: $draft.goodWithDogs)
                            Toggle("Cats", isOn: $draft.goodWithCats)
                            Toggle("House-trained", isOn: $draft.houseTrained)
                            Toggle("Special needs", isOn: $draft.specialNeeds)
                            Toggle("Needs a foster", isOn: Binding(
                                get: { draft.needsFoster == true },
                                set: { draft.needsFoster = $0 ? true : nil }
                            ))
                        }
                        .tint(Color.pfBrandPrimary)
                    }

                    section("Location") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            TextField("Postcode or city", text: locationText)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(Spacing.md)
                                .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                            Button {
                                Task { await useCurrentLocation() }
                            } label: {
                                if isLocating {
                                    ProgressView()
                                } else {
                                    Label("Use my current location", systemImage: "location.fill")
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .disabled(isLocating)
                            if let locationError {
                                Text(locationError)
                                    .font(.pfCaption)
                                    .foregroundStyle(Color.pfError)
                            }
                            Picker("Distance", selection: $draft.distance) {
                                ForEach(distances, id: \.self) { Text("\($0) mi").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .disabled(draft.location.isEmpty)
                        }
                    }

                    section("Time listed") {
                        Picker("Time listed", selection: $draft.listed) {
                            ForEach(PetFilters.Listed.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }

                    section("Sort by") {
                        Picker("Sort by", selection: $draft.sort) {
                            ForEach(PetFilters.Sort.allCases, id: \.self) { sort in
                                Text(sort.rawValue).tag(sort)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.pfBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Reset") {
                        var cleared = PetFilters()
                        cleared.name = draft.name
                        draft = cleared
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PFButton(title: "Show results") {
                    onApply(draft)
                    dismiss()
                }
                .padding(Spacing.lg)
                .background(Color.pfBackground)
            }
        }
    }

    /// Shows "Current location" when GPS was used; typing replaces it with a ZIP/city.
    private var locationText: Binding<String> {
        Binding(
            get: { draft.locationLabel },
            set: { newValue in
                draft.location = newValue
                draft.locationName = nil
            }
        )
    }

    private func useCurrentLocation() async {
        isLocating = true
        locationError = nil
        defer { isLocating = false }
        do {
            let location = try await locationService.requestLocation()
            draft.location = location.coordinateText
            draft.locationName = "Current location"
        } catch {
            locationError = error.localizedDescription
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.pfHeadline)
                .foregroundStyle(Color.pfTextPrimary)
            content()
        }
    }

    /// A horizontally scrolling row of chips for an enum's cases.
    private func chips<Option: RawRepresentable & Hashable>(
        _ options: [Option],
        isSelected: @escaping (Option) -> Bool,
        toggle: @escaping (Option) -> Void
    ) -> some View where Option.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    PFChip(title: option.rawValue, isSelected: isSelected(option)) { toggle(option) }
                }
            }
        }
    }
}

#Preview {
    FilterSheet(filters: PetFilters()) { _ in }
        .environment(LocationService())
}
