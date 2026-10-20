import SwiftUI

/// Swipe mode: drag right to like, left to pass, up to super-like.
/// Buttons do the same (and work with VoiceOver). Undo brings the last card back.
struct SwipeView: View {
    @State private var viewModel: SwipeViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var lastAction: SwipeViewModel.Action?
    @State private var actionCount = 0

    @Environment(FavoritesStore.self) private var favorites
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let threshold: CGFloat = 120

    init(repository: PetRepository, filters: PetFilters) {
        _viewModel = State(initialValue: SwipeViewModel(repository: repository, filters: filters))
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                if viewModel.queue.isEmpty {
                    emptyState
                } else {
                    // Top 3 cards; the ones underneath load their photos early.
                    ForEach(Array(viewModel.queue.prefix(3).enumerated().reversed()), id: \.element.id) { index, pet in
                        card(pet, isTop: index == 0, depth: index)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            controls
        }
        .padding(Spacing.lg)
        .background(Color.pfBackground)
        .navigationTitle("Swipe")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(trigger: actionCount) { _, _ in
            switch lastAction {
            case .like?: .impact(weight: .medium)
            case .superLike?: .success
            case .pass?: .impact(weight: .light)
            case nil: nil
            }
        }
        .task(id: viewModel.queue.count) {
            await viewModel.loadMoreIfNeeded(skipping: favorites)
        }
    }

    // MARK: - Cards

    private func card(_ pet: Pet, isTop: Bool, depth: Int) -> some View {
        SwipeCard(pet: pet, dragOffset: isTop ? dragOffset : .zero, threshold: threshold)
            .scaleEffect(1 - CGFloat(depth) * 0.04)
            .offset(y: CGFloat(depth) * 12)
            .offset(isTop ? dragOffset : .zero)
            .rotationEffect(.degrees(isTop && !reduceMotion ? Double(dragOffset.width / 20) : 0))
            .allowsHitTesting(isTop)
            .gesture(isTop ? drag : nil)
            .onTapGesture { router.push(.petDetail(pet)) }
            .accessibilityElement(children: .combine)
            .accessibilityHint(isTop ? "Use the buttons below to like or pass. Double tap for details." : "")
            .accessibilityHidden(!isTop)
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if value.translation.width > threshold {
                    perform(.like)
                } else if value.translation.width < -threshold {
                    perform(.pass)
                } else if value.translation.height < -threshold {
                    perform(.superLike)
                } else {
                    withAnimation(.spring) { dragOffset = .zero }
                }
            }
    }

    /// Flies the top card off screen, then records the swipe.
    private func perform(_ action: SwipeViewModel.Action) {
        guard !viewModel.queue.isEmpty else { return }
        let exit: CGSize = switch action {
        case .like: CGSize(width: 600, height: dragOffset.height)
        case .pass: CGSize(width: -600, height: dragOffset.height)
        case .superLike: CGSize(width: 0, height: -900)
        }
        lastAction = action
        actionCount += 1
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { dragOffset = exit }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 200))
            viewModel.swipe(action, favorites: favorites)
            dragOffset = .zero
        }
    }

    // MARK: - Controls & states

    private var controls: some View {
        HStack(spacing: Spacing.lg) {
            circleButton("arrow.uturn.backward", size: 48, color: .pfTextSecondary, label: "Undo") {
                withAnimation { viewModel.undo(favorites: favorites) }
            }
            .disabled(!viewModel.canUndo)

            circleButton("xmark", size: 64, color: .pfError, label: "Pass") { perform(.pass) }
            circleButton("star.fill", size: 52, color: .pfBrandLight, label: "Super like: favorite and add to Top picks") {
                perform(.superLike)
            }
            circleButton("heart.fill", size: 64, color: .pfSuccess, label: "Like: add to favorites") { perform(.like) }
        }
        .disabled(viewModel.queue.isEmpty)
    }

    private func circleButton(_ icon: String, size: CGFloat, color: Color, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color.pfSurfaceElevated, in: Circle())
                .overlay(Circle().stroke(Color.pfBorder))
                .shadow(color: Color.pfTextPrimary.opacity(0.1), radius: 4, y: 2)
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isLoading {
            LoadingView(message: "Finding pets...")
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) { Task { await viewModel.loadMoreIfNeeded(skipping: favorites) } }
        } else {
            EmptyStateView(icon: "checkmark.circle", title: "You've seen them all",
                           message: "Try different filters in Discover, or see the pets you passed on again.",
                           buttonTitle: "Show passed pets again") {
                Task {
                    await viewModel.resetPassed()
                    await viewModel.loadMoreIfNeeded(skipping: favorites)
                }
            }
        }
    }
}

/// One card: big photo with the name and details on top.
private struct SwipeCard: View {
    let pet: Pet
    let dragOffset: CGSize
    let threshold: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .overlay { PetPhoto(url: pet.photoURLs.first ?? pet.thumbnailURL, species: pet.species) }
                .clipped()

            // Dark fade so white text is readable on any photo.
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(pet.name)
                    .font(.largeTitle.bold())
                Text(pet.breed)
                    .font(.pfHeadline)
                Text([pet.summary, pet.location].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding(Spacing.lg)

            stamp("LIKE", color: .pfSuccess, opacity: dragOffset.width / threshold, alignment: .topLeading)
            stamp("NOPE", color: .pfError, opacity: -dragOffset.width / threshold, alignment: .topTrailing)
            stamp("SUPER", color: .pfBrandLight, opacity: -dragOffset.height / threshold, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
        .shadow(color: Color.pfTextPrimary.opacity(0.15), radius: 8, y: 4)
    }

    private func stamp(_ text: String, color: Color, opacity: CGFloat, alignment: Alignment) -> some View {
        Text(text)
            .font(.largeTitle.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.md)
            .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(alignment == .topTrailing ? 15 : -15))
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .opacity(Double(max(0, min(opacity, 1))))
            .accessibilityHidden(true)
    }
}
