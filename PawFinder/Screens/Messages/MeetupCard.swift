import MapKit
import SwiftUI

/// What the person tapped on a meet-up card.
enum MeetupAction {
    case accept
    case decline
    /// Suggest a different place or time.
    case counter
    /// Cancel one that was already accepted.
    case cancel
}

/// A meet-up proposal shown inside a chat: place, time, a small map, and
/// buttons to accept, decline or suggest something else. Tapping the map opens
/// the route screen.
struct MeetupCard: View {
    let meetup: Meetup
    let isMine: Bool
    let proposerName: String
    let onAction: (MeetupAction) -> Void

    private var title: String {
        isMine ? "You suggested a meet-up" : "\(proposerName) suggested a meet-up"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pfTextPrimary)

            NavigationLink(value: Route.meetupMap(meetup)) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Map(initialPosition: .region(MKCoordinateRegion(center: meetup.coordinate,
                                                                    latitudinalMeters: 900,
                                                                    longitudinalMeters: 900)),
                        interactionModes: []) {
                        Marker(meetup.placeName, coordinate: meetup.coordinate)
                            .tint(Color.pfBrandPrimary)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                    .allowsHitTesting(false)

                    Text(meetup.placeName)
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                        .multilineTextAlignment(.leading)
                    if !meetup.address.isEmpty {
                        Text(meetup.address)
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Label(meetup.dateText, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextPrimary)
                    Text("Tap for route and travel time")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfBrandPrimary)
                }
            }
            .buttonStyle(.plain)

            statusRow
        }
        .padding(Spacing.md)
        .frame(maxWidth: 300, alignment: .leading)
        .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.pfBorder))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch meetup.status {
        case .proposed:
            if isMine {
                Label("Waiting for a reply", systemImage: "clock")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            } else if meetup.isUpcoming {
                HStack(spacing: Spacing.sm) {
                    actionButton("Accept", filled: true) { onAction(.accept) }
                    actionButton("Decline", filled: false) { onAction(.decline) }
                }
                Button("Suggest another place or time") { onAction(.counter) }
                    .font(.subheadline)
            } else {
                Label("This time has passed", systemImage: "clock.badge.exclamationmark")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        case .accepted:
            Label(meetup.isUpcoming ? "Accepted" : "Accepted (this has happened)", systemImage: MeetupStatus.accepted.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pfSuccess)
            if meetup.isUpcoming {
                Button("Cancel meet-up", role: .destructive) { onAction(.cancel) }
                    .font(.subheadline)
            }
        case .declined, .changed:
            Label(meetup.status == .declined ? "Declined" : "Changed. See the newer suggestion below.",
                  systemImage: meetup.status.icon)
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
        }
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(filled ? Color.pfSurfaceElevated : Color.pfBrandPrimary)
                .background(filled ? Color.pfBrandPrimary : Color.clear, in: RoundedRectangle(cornerRadius: Radius.medium))
                .overlay {
                    if !filled { RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBrandPrimary) }
                }
        }
        .buttonStyle(.plain)
    }
}
