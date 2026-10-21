import SwiftUI

/// The Breeds tab (where photo identification will live once Phase 6 is
/// built): your best breed matches from the lifestyle answers, and every
/// breed guide.
struct BreedsHubView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var species: PetFilters.Species = .dog
    @State private var searchText = ""

    private var matches: [BreedMatcher.Match] { BreedMatcher.matches(for: profileStore.profile) }

    private var allBreeds: [BreedGuide] {
        CareContent.breedGuides
            .filter { $0.species == species }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                comingSoonCard

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Your best matches")
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)
                    if profileStore.profile.answeredCount == 0 {
                        questionnairePrompt
                    } else {
                        if !profileStore.profile.isQuestionnaireComplete { questionnairePrompt }
                        ForEach(matches.prefix(5)) { match in
                            NavigationLink(value: Route.breedGuide(match.guide.name)) {
                                MatchRow(match: match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("All breeds")
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)
                    Picker("Animal", selection: $species) {
                        Text("Dogs").tag(PetFilters.Species.dog)
                        Text("Cats").tag(PetFilters.Species.cat)
                    }
                    .pickerStyle(.segmented)
                    TextField("Search breeds", text: $searchText)
                        .padding(Spacing.md)
                        .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                    ForEach(allBreeds) { guide in
                        NavigationLink(value: Route.breedGuide(guide.name)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guide.name)
                                        .font(.pfHeadline)
                                        .foregroundStyle(Color.pfTextPrimary)
                                    Text("\(guide.size) · \(guide.energy) energy · \(guide.lifespan)")
                                        .font(.pfCaption)
                                        .foregroundStyle(Color.pfTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.pfBorder)
                    }
                    if allBreeds.isEmpty {
                        Text("No breeds match \"\(searchText)\".")
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
    }

    private var comingSoonCard: some View {
        PFCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "camera.viewfinder")
                    .font(.title)
                    .foregroundStyle(Color.pfBrandPrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Photo breed ID is coming soon")
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                    Text("Soon you'll be able to snap a dog or cat and see its likely breed, right on your phone. Until then, find the breeds that fit your life.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }
        }
    }

    private var questionnairePrompt: some View {
        NavigationLink(value: Route.lifestyle) {
            PFCard {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(profileStore.profile.answeredCount == 0
                             ? "Answer 5 quick questions"
                             : "Finish your lifestyle answers")
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                        Text("We'll rank breeds by how well they fit your home, schedule, and energy.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// One breed match: score ring, name, and the top reason.
private struct MatchRow: View {
    let match: BreedMatcher.Match

    var body: some View {
        HStack(spacing: Spacing.md) {
            MatchRing(score: match.score)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.guide.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                if let reason = match.pros.first ?? match.cons.first {
                    Text(reason)
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
        }
        .padding(Spacing.md)
        .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
        .accessibilityElement(children: .combine)
    }
}

/// A circular "87%" badge.
struct MatchRing: View {
    let score: Int
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle().stroke(Color.pfBorder, lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)%")
                .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pfTextPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(score) percent match")
    }

    private var color: Color {
        score >= 75 ? Color.pfSuccess : (score >= 50 ? Color.pfBrandPrimary : Color.pfTextSecondary)
    }
}
