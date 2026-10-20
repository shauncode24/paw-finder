import SwiftUI

/// Side-by-side comparison of 2–3 favorites. Rows where the pets differ are
/// highlighted; "Only differences" hides the rest.
struct CompareView: View {
    let pets: [Pet]
    @State private var onlyDifferences = false

    private struct Row: Identifiable {
        let id: String
        let values: [String]
        var differs: Bool { Set(values).count > 1 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                header
                Toggle("Only show differences", isOn: $onlyDifferences)
                    .tint(Color.pfBrandPrimary)
                    .padding(.horizontal, Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(rows.filter { !onlyDifferences || $0.differs }) { row in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(row.id)
                                .font(.pfCaption.weight(.semibold))
                                .foregroundStyle(Color.pfTextSecondary)
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                                    Text(value)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.pfTextPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(Spacing.md)
                        .background(row.differs ? Color.pfBrandDeep : Color.clear)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(row.differs ? "Different" : "Same")
                        Divider().overlay(Color.pfBorder)
                    }
                }
                .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.large))
                .clipShape(RoundedRectangle(cornerRadius: Radius.large))
                .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.pfBorder))
                .padding(.horizontal, Spacing.lg)

                Text("Highlighted rows are where they differ.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.pfBackground)
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ForEach(pets) { pet in
                NavigationLink(value: Route.petDetail(pet)) {
                    VStack(spacing: Spacing.xs) {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        Text(pet.name)
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var rows: [Row] {
        func yesNo(_ value: Bool?) -> String {
            switch value {
            case true?: "Yes"
            case false?: "No"
            case nil: "Unknown"
            }
        }
        func row(_ title: String, _ value: (Pet) -> String) -> Row {
            Row(id: title, values: pets.map { value($0).isEmpty ? "—" : value($0) })
        }
        return [
            row("Species") { $0.species },
            row("Breed") { $0.breed },
            row("Age") { $0.age },
            row("Gender") { $0.gender },
            row("Size") { $0.size },
            row("Coat") { $0.coat ?? "" },
            row("Good with kids") { yesNo($0.goodWithKids) },
            row("Good with dogs") { yesNo($0.goodWithDogs) },
            row("Good with cats") { yesNo($0.goodWithCats) },
            row("House-trained") { yesNo($0.houseTrained) },
            row("Special needs") { yesNo($0.specialNeeds) },
            row("Location") { $0.location },
            row("Listed") { $0.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "" },
        ]
    }
}

/// Pick 2–3 favorites to compare.
struct ComparePickerSheet: View {
    let favorites: [FavoritePet]
    let onCompare: ([Pet]) -> Void
    @State private var selected: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(favorites) { favorite in
                let isSelected = selected.contains(favorite.id)
                Button {
                    if isSelected {
                        selected.removeAll { $0 == favorite.id }
                    } else if selected.count < 3 {
                        selected.append(favorite.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.pfBrandPrimary : Color.pfBorder)
                        Text(favorite.pet.name).foregroundStyle(Color.pfTextPrimary)
                        Text(favorite.pet.breed).font(.subheadline).foregroundStyle(Color.pfTextSecondary)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .listRowBackground(Color.pfSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.pfBackground)
            .navigationTitle("Pick 2 or 3 pets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Compare") {
                        let pets = selected.compactMap { id in favorites.first { $0.id == id }?.pet }
                        dismiss()
                        onCompare(pets)
                    }
                    .disabled(selected.count < 2)
                }
            }
        }
    }
}
