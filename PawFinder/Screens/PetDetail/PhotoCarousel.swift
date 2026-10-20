import SwiftUI

/// Swipeable photos at the top of the detail screen. Tap to view full screen.
struct PhotoCarousel: View {
    let photoURLs: [URL]
    let species: String
    @State private var selection = 0
    @State private var showFullScreen = false

    var body: some View {
        Group {
            if photoURLs.isEmpty {
                PetPhoto(url: nil, species: species)
            } else {
                TabView(selection: $selection) {
                    ForEach(photoURLs.indices, id: \.self) { index in
                        PetPhoto(url: photoURLs[index], species: species)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photoURLs.count > 1 ? .always : .never))
                .onTapGesture { showFullScreen = true }
                .accessibilityLabel("Photo \(selection + 1) of \(photoURLs.count)")
                .accessibilityHint("Double tap to view full screen")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: 320)
        .clipped()
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoViewer(photoURLs: photoURLs, selection: $selection)
        }
    }
}

/// Black full-screen viewer. Pinch or double-tap to zoom, drag to pan when zoomed.
private struct FullScreenPhotoViewer: View {
    let photoURLs: [URL]
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo viewers are always black, in light and dark mode.
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(photoURLs.indices, id: \.self) { index in
                    ZoomableImage(url: photoURLs[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
            .accessibilityLabel("Close")
        }
    }
}

private struct ZoomableImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var containerSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnify)
                        // Only grab drags while zoomed, so swiping between photos still works.
                        .simultaneousGesture(scale > 1 ? pan : nil)
                        .onTapGesture(count: 2) { toggleZoom() }
                } else if phase.error != nil {
                    Image(systemName: "photo").foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { containerSize = proxy.size }
            .onChange(of: proxy.size) { _, size in containerSize = size }
        }
        .accessibilityLabel("Pet photo")
    }

    /// Keeps the zoomed photo covering the screen instead of sliding off it.
    private func clamped(_ proposed: CGSize) -> CGSize {
        let maxX = containerSize.width * (scale - 1) / 2
        let maxY = containerSize.height * (scale - 1) / 2
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), 4)
                offset = clamped(offset)
            }
            .onEnded { _ in
                lastScale = scale
                if scale == 1 { resetOffset() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clamped(CGSize(width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height))
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring) {
            scale = scale > 1 ? 1 : 2
            lastScale = scale
            if scale == 1 { resetOffset() }
        }
    }

    private func resetOffset() {
        offset = .zero
        lastOffset = .zero
    }
}
