import MapKit
import SwiftUI

/// Small, non-interactive map with a pin. Tapping it opens Apple Maps.
struct ShelterMiniMap: View {
    let name: String
    let coordinate: CLLocationCoordinate2D
    var height: CGFloat = 160
    @Environment(\.openURL) private var openURL

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate,
                                                        latitudinalMeters: 1500,
                                                        longitudinalMeters: 1500)),
            interactionModes: []) {
            Marker(name, coordinate: coordinate)
                .tint(Color.pfBrandPrimary)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
        .allowsHitTesting(false)
        .overlay {
            // Transparent layer on top that catches the tap.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { openURL(MapsLink.place(name: name, coordinate: coordinate)) }
        }
        .accessibilityElement()
        .accessibilityLabel("Open \(name) in Maps")
        .accessibilityAddTraits(.isButton)
    }
}

/// Apple Maps links (they open the Maps app).
enum MapsLink {
    static func place(name: String, coordinate: CLLocationCoordinate2D) -> URL {
        url([
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
        ])
    }

    /// Driving directions from the user's location.
    static func directions(name: String, coordinate: CLLocationCoordinate2D) -> URL {
        url([
            URLQueryItem(name: "daddr", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "dirflg", value: "d"),
        ])
    }

    private static func url(_ items: [URLQueryItem]) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = items
        return components?.url ?? URL(fileURLWithPath: "/")
    }
}

/// Call / Email / Website buttons. Missing ones are left out.
struct ContactButtons: View {
    let phone: String?
    let email: String?
    let website: URL?

    var body: some View {
        let phoneURL = phone.flatMap { URL(string: "tel:\($0.filter { $0.isNumber || $0 == "+" })") }
        let emailURL = email.flatMap { URL(string: "mailto:\($0)") }

        if phoneURL != nil || emailURL != nil || website != nil {
            HStack(spacing: Spacing.sm) {
                if let phoneURL { contactLink("Call", icon: "phone.fill", url: phoneURL) }
                if let emailURL { contactLink("Email", icon: "envelope.fill", url: emailURL) }
                if let website { contactLink("Website", icon: "safari.fill", url: website) }
            }
        }
    }

    private func contactLink(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Color.pfBrandPrimary)
                .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
        }
    }
}

/// "Open now · closes 5:00 PM" in green, or "Closed now". Nothing if hours are unknown.
struct OpenStatusLabel: View {
    let shelter: Shelter

    var body: some View {
        let status = shelter.openStatus()
        if let label = status.label {
            Label(label, systemImage: "clock")
                .font(.pfCaption.weight(.semibold))
                .foregroundStyle(status == .closed ? Color.pfTextSecondary : Color.pfSuccess)
        }
    }
}
