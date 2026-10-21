import SwiftUI

/// Remembers which Care Hub checklist items are ticked (UserDefaults).
@MainActor
@Observable
final class CareChecklistStore {
    private(set) var done: Set<String>
    private let key = "careChecklistDone"

    init() {
        done = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func isDone(_ item: String, in checklist: CareChecklist) -> Bool {
        done.contains(Self.key(item, checklist))
    }

    func toggle(_ item: String, in checklist: CareChecklist) {
        done.formSymmetricDifference([Self.key(item, checklist)])
        UserDefaults.standard.set(Array(done), forKey: key)
    }

    func reset() {
        done = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    func progress(_ checklist: CareChecklist) -> Int {
        checklist.items.filter { isDone($0, in: checklist) }.count
    }

    private static func key(_ item: String, _ checklist: CareChecklist) -> String { "\(checklist.id)|\(item)" }
}

/// Profile › Care Hub: checklists, guides, and breed guides.
struct CareHubView: View {
    @Environment(CareChecklistStore.self) private var checklists

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                section("Checklists") {
                    ForEach(CareContent.checklists) { checklist in
                        NavigationLink(value: Route.careChecklist(checklist.id)) {
                            PFCard {
                                HStack {
                                    Label(checklist.title, systemImage: checklist.icon)
                                        .font(.pfHeadline)
                                        .foregroundStyle(Color.pfTextPrimary)
                                    Spacer()
                                    Text("\(checklists.progress(checklist))/\(checklist.items.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.pfTextSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                section("Guides") {
                    ForEach(CareContent.articles) { article in
                        NavigationLink(value: Route.careArticle(article.id)) {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: article.icon)
                                    .font(.title3)
                                    .foregroundStyle(Color.pfBrandPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(article.title)
                                        .font(.pfHeadline)
                                        .foregroundStyle(Color.pfTextPrimary)
                                    Text("\(article.summary) · \(article.minutes) min read")
                                        .font(.pfCaption)
                                        .foregroundStyle(Color.pfTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                section("Breed guides") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.sm)], spacing: Spacing.sm) {
                        ForEach(CareContent.breedGuides) { guide in
                            NavigationLink(value: Route.breedGuide(guide.name)) {
                                PFCard {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Image(systemName: guide.species == .cat ? "cat.fill" : "dog.fill")
                                            .foregroundStyle(Color.pfBrandPrimary)
                                        Text(guide.name)
                                            .font(.pfHeadline)
                                            .foregroundStyle(Color.pfTextPrimary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Text("\(guide.size) · \(guide.energy) energy")
                                            .font(.pfCaption)
                                            .foregroundStyle(Color.pfTextSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .navigationTitle("Care Hub")
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

/// One guide, rendered from Markdown.
struct CareArticleView: View {
    let article: CareArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Image(systemName: article.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.pfBrandPrimary)
                    .accessibilityHidden(true)
                Text(article.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.pfTextPrimary)
                Text("\(article.minutes) min read")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                ForEach(Array(article.body.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                    Text(Self.markdown(paragraph))
                        .foregroundStyle(Color.pfTextPrimary)
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Bullet lines become "•"; the rest is inline Markdown (bold, italic).
    private static func markdown(_ paragraph: String) -> AttributedString {
        let text = paragraph
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasPrefix("- ") ? "•  " + $0.dropFirst(2) : String($0) }
            .joined(separator: "\n")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// One breed's facts, with a shortcut to adoptable pets of that breed.
struct BreedGuideView: View {
    let guide: BreedGuide
    @Environment(Router.self) private var router
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(guide.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.pfTextPrimary)
                FlowLayout {
                    PFChip(title: guide.species.rawValue, isSelected: true)
                    PFChip(title: guide.size)
                    PFChip(title: "\(guide.energy) energy")
                    PFChip(title: guide.lifespan)
                }
                if profileStore.profile.answeredCount > 0 {
                    lifestyleMatch
                }
                fact("Temperament", guide.temperament)
                fact("Care", guide.care)
                fact("A good fit for", guide.goodFor)
                Text("Every pet is an individual. Mixed breeds and shelter pets often differ from the breed average.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                PFButton(title: "Find adoptable \(guide.name)s") {
                    var filters = PetFilters()
                    filters.species = guide.species
                    filters.breed = guide.name
                    router.showInDiscover(filters)
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "87% match" plus the reasons, from the lifestyle answers.
    private var lifestyleMatch: some View {
        let match = BreedMatcher.match(guide, profileStore.profile)
        return PFCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                MatchRing(score: match.score, size: 56)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Match with your lifestyle")
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                    ForEach(match.pros, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.pfSuccess)
                    }
                    ForEach(match.cons, id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }
        }
    }

    private func fact(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.pfHeadline).foregroundStyle(Color.pfTextPrimary)
            Text(text).foregroundStyle(Color.pfTextPrimary)
        }
    }
}

/// A checklist with tick boxes that stay ticked.
struct CareChecklistView: View {
    let checklist: CareChecklist
    @Environment(CareChecklistStore.self) private var store

    var body: some View {
        List {
            Section {
                ProgressView(value: Double(store.progress(checklist)), total: Double(checklist.items.count))
                    .tint(Color.pfSuccess)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(checklist.items, id: \.self) { item in
                    let done = store.isDone(item, in: checklist)
                    Button {
                        store.toggle(item, in: checklist)
                    } label: {
                        Label {
                            Text(item)
                                .strikethrough(done)
                                .foregroundStyle(done ? Color.pfTextSecondary : Color.pfTextPrimary)
                        } icon: {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done ? Color.pfSuccess : Color.pfBorder)
                        }
                    }
                    .accessibilityAddTraits(done ? .isSelected : [])
                    .sensoryFeedback(.selection, trigger: done)
                    .listRowBackground(Color.pfSurface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle(checklist.title)
    }
}
