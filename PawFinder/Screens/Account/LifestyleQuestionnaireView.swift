import SwiftUI

/// The lifestyle questions. Used in onboarding and from Profile.
/// Answers are kept in a draft and saved when the user taps Save/Continue.
struct LifestyleQuestionnaireView: View {
    /// Title of the main button ("Save" or "Continue").
    var saveTitle = "Save"
    /// Called after saving (and when skipping, during onboarding).
    var onFinish: () -> Void = {}
    var showsSkip = false
    /// Go back after saving (when opened from Profile, not during onboarding).
    var popsOnSave = false

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AdopterProfile()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("A few questions so we can suggest pets that fit your life. You can change these any time.")
                    .foregroundStyle(Color.pfTextSecondary)

                question("Where do you live?") {
                    singleChoice(AdopterProfile.HomeType.allCases, selection: $draft.homeType)
                }
                question("Kids at home?") {
                    singleChoice(AdopterProfile.KidsAtHome.allCases, selection: $draft.kids)
                }
                question("Other pets at home?") {
                    FlowLayout {
                        ForEach(AdopterProfile.OtherPet.allCases, id: \.self) { pet in
                            PFChip(title: pet.rawValue, isSelected: draft.otherPets.contains(pet)) {
                                draft.otherPets.formSymmetricDifference([pet])
                            }
                        }
                    }
                }
                question("Pet experience") {
                    singleChoice(AdopterProfile.Experience.allCases, selection: $draft.experience)
                }
                question("Your typical day") {
                    singleChoice(AdopterProfile.Schedule.allCases, selection: $draft.schedule)
                }
                question("How active are you?") {
                    singleChoice(AdopterProfile.ActivityLevel.allCases, selection: $draft.activity)
                }
                question("Looking for (optional)") {
                    FlowLayout {
                        ForEach(PetFilters.Species.allCases, id: \.self) { species in
                            PFChip(title: species.rawValue, isSelected: draft.preferredSpecies.contains(species)) {
                                draft.preferredSpecies.formSymmetricDifference([species])
                            }
                        }
                    }
                    FlowLayout {
                        ForEach(PetFilters.Size.allCases, id: \.self) { size in
                            PFChip(title: size.rawValue, isSelected: draft.preferredSizes.contains(size)) {
                                draft.preferredSizes.formSymmetricDifference([size])
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.sm) {
                PFButton(title: saveTitle) {
                    let answers = draft
                    profileStore.update { profile in
                        let name = profile.displayName
                        profile = answers
                        profile.displayName = name   // the questionnaire doesn't edit the name
                    }
                    onFinish()
                    if popsOnSave { dismiss() }
                }
                if showsSkip {
                    Button("Skip for now", action: onFinish)
                        .font(.subheadline)
                }
            }
            .padding(Spacing.lg)
            .background(Color.pfBackground)
        }
        .onAppear { draft = profileStore.profile }
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.pfHeadline)
                .foregroundStyle(Color.pfTextPrimary)
            content()
        }
    }

    /// Chips where one (or none) can be picked. Tapping the picked one clears it.
    private func singleChoice<Option: RawRepresentable & Hashable>(
        _ options: [Option], selection: Binding<Option?>
    ) -> some View where Option.RawValue == String {
        FlowLayout {
            ForEach(options, id: \.self) { option in
                PFChip(title: option.rawValue, isSelected: selection.wrappedValue == option) {
                    selection.wrappedValue = selection.wrappedValue == option ? nil : option
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LifestyleQuestionnaireView()
            .navigationTitle("Your lifestyle")
    }
    .environment(ProfileStore())
}
