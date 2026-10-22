import SwiftUI

// MARK: - Stars

/// Read-only stars for an average such as 4.6 (whole and half stars).
struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: icon(for: index))
                    .font(.system(size: size))
                    .foregroundStyle(Color.pfBrandPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%.1f out of 5 stars", rating))
    }

    private func icon(for index: Int) -> String {
        let position = Double(index)
        if rating >= position { return "star.fill" }
        if rating >= position - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

/// "★★★★☆ 4.8 (12 reviews)", or "No reviews yet". Used on pet pages and lister profiles.
struct RatingSummaryView: View {
    let summary: RatingSummary

    var body: some View {
        if let average = summary.average, let label = summary.label {
            HStack(spacing: Spacing.xs) {
                StarRatingView(rating: average)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("No reviews yet")
                .font(.subheadline)
                .foregroundStyle(Color.pfTextSecondary)
        }
    }
}

// MARK: - Writing a review

/// The sheet an adopter uses to rate a lister after an adoption. If they've
/// already reviewed, it opens with their review so they can change it (for a week).
struct ReviewComposerSheet: View {
    let applicationID: String
    let listerID: String
    let listerName: String
    let petName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore

    @State private var existing: Review?
    @State private var rating = 0
    @State private var text = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var thanks = false

    private var isLocked: Bool { existing != nil && existing?.isEditable == false }
    private var canSave: Bool { rating > 0 && !isSaving && !isLocked }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if thanks {
                    thankYou
                } else {
                    form
                }
            }
            .background(Color.pfBackground)
            .navigationTitle(existing == nil ? "Rate \(listerName)" : "Your review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(thanks ? "Done" : "Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("How was adopting \(petName) from \(listerName)?")
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)

                HStack(spacing: Spacing.sm) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            rating = star
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 34))
                                .foregroundStyle(Color.pfBrandPrimary)
                                .frame(width: 48, height: 48)
                        }
                        .disabled(isLocked)
                        .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        .accessibilityAddTraits(star == rating ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: rating)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Tell others about it (optional)")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.sm)
                        .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                        .disabled(isLocked)
                        .onChange(of: text) { _, value in
                            if value.count > Review.maxTextLength { text = String(value.prefix(Review.maxTextLength)) }
                        }
                    Text("\(text.count)/\(Review.maxTextLength)")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }

                Text(isLocked
                     ? "Reviews can be changed for 7 days after you post them, so this one is now final."
                     : "Your first name and last initial are shown with your review, and anyone can read it. Be honest and kind.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.pfError)
                }

                if !isLocked {
                    PFButton(title: existing == nil ? "Post review" : "Save changes", isLoading: isSaving) {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .opacity(canSave || isSaving ? 1 : 0.5)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var thankYou: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.pfBrandPrimary)
            Text("Thank you!")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.pfTextPrimary)
            Text("Your review helps other adopters choose with confidence.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pfTextSecondary)
        }
        .padding(Spacing.xl)
    }

    private func load() async {
        existing = await ReviewsService.review(forApplication: applicationID)
        if let existing {
            rating = existing.rating
            text = existing.text
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let profileName = profileStore.profile.displayName
        let name = profileName.isEmpty ? (auth.user?.displayName ?? "") : profileName
        do {
            try await ReviewsService.submit(applicationID: applicationID, listerID: listerID, petName: petName,
                                            rating: rating, text: text, reviewerName: name, replacing: existing)
            thanks = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Reading reviews

/// A lister's reviews, newest first. Anyone can read; each review can be reported.
struct ListerReviewsView: View {
    let listerID: String
    let listerName: String

    @Environment(AuthManager.self) private var auth
    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reporting: Review?
    @State private var replying: Review?

    private var summary: RatingSummary {
        RatingSummary(sum: reviews.map(\.rating).reduce(0, +), count: reviews.count)
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading reviews...")
            } else if let errorMessage {
                ErrorView(message: errorMessage) { Task { await load() } }
            } else if reviews.isEmpty {
                EmptyStateView(icon: "star", title: "No reviews yet",
                               message: "After an adoption, the adopter can leave a review of \(listerName).")
            } else {
                list
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $replying, onDismiss: { Task { await load() } }) { review in
            ReviewReplySheet(review: review)
        }
        .confirmationDialog("Report this review", isPresented: Binding(get: { reporting != nil },
                                                                       set: { if !$0 { reporting = nil } }),
                            titleVisibility: .visible) {
            ForEach(["Not a real adoption", "Rude or abusive", "Spam", "Something else"], id: \.self) { reason in
                Button(reason) {
                    if let reporting { ReviewsService.report(reporting, reason: reason) }
                    reporting = nil
                }
            }
        } message: {
            Text("Thanks for helping keep PawFinder fair. Reports are saved for review.")
        }
    }

    private var list: some View {
        List {
            Section {
                VStack(spacing: Spacing.xs) {
                    Text(summary.averageText ?? "–")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pfTextPrimary)
                    StarRatingView(rating: summary.average ?? 0, size: 18)
                    Text("\(summary.count) \(summary.count == 1 ? "review" : "reviews") of \(listerName)")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(reviews) { review in
                    row(review)
                        .listRowBackground(Color.pfSurface)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                StarRatingView(rating: Double(review.rating))
                Spacer()
                Menu {
                    Button("Report review", systemImage: "flag") { reporting = review }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More")
            }
            if !review.text.isEmpty {
                Text(review.text)
                    .foregroundStyle(Color.pfTextPrimary)
            }
            if let reply = review.reply {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reply from \(listerName)")
                        .font(.pfCaption.weight(.semibold))
                        .foregroundStyle(Color.pfTextSecondary)
                    Text(reply).foregroundStyle(Color.pfTextPrimary)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
            if review.listerID == auth.user?.id {
                Button(review.reply == nil ? "Reply" : "Edit your reply") { replying = review }
                    .font(.subheadline.weight(.semibold))
            }
            let about = review.petName.isEmpty ? "" : " · adopted \(review.petName)"
            Text("\(review.shortName)\(about) · \(review.createdAt.formatted(date: .abbreviated, time: .omitted))\(review.wasEdited ? " · edited" : "")")
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            reviews = try await ReviewsService.reviews(for: listerID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// The rating line on a lister's card or page. Opens the reviews when there are any.
struct RatingLink: View {
    let shelter: Shelter

    var body: some View {
        if shelter.rating.count > 0 {
            NavigationLink(value: Route.listerReviews(id: shelter.id, name: shelter.name)) {
                HStack(spacing: Spacing.xs) {
                    RatingSummaryView(summary: shelter.rating)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }
            .buttonStyle(.plain)
        } else {
            RatingSummaryView(summary: shelter.rating)
        }
    }
}

/// The lister's public reply to a review.
struct ReviewReplySheet: View {
    let review: Review
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StarRatingView(rating: Double(review.rating), size: 18)
                    if !review.text.isEmpty {
                        Text(review.text).foregroundStyle(Color.pfTextPrimary)
                    }
                    Text("Your reply is public and shown under the review. Keep it kind and brief. You can't change the review itself, but you can report it.")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(Spacing.sm)
                        .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                        .onChange(of: text) { _, value in
                            if value.count > Review.maxTextLength { text = String(value.prefix(Review.maxTextLength)) }
                        }
                    if let errorMessage {
                        Text(errorMessage).font(.subheadline).foregroundStyle(Color.pfError)
                    }
                    PFButton(title: review.reply == nil ? "Post reply" : "Save reply", isLoading: isSaving) {
                        Task { await save() }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.pfBackground)
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { text = review.reply ?? "" }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await ReviewsService.reply(to: review, text: text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
