import MapKit
import SwiftUI

/// Shelter name, address, a small map, and call/email/website buttons.
struct ShelterCard: View {
    let state: PetDetailViewModel.ShelterState
    let coordinate: CLLocationCoordinate2D?
    let pet: Pet
    let retry: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        PFCard {
            switch state {
            case .loading:
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Loading shelter...").foregroundStyle(Color.pfTextSecondary)
                }
            case .failed:
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Couldn't load the shelter.").foregroundStyle(Color.pfTextSecondary)
                    Button("Try again", action: retry)
                    // We can still show the pet's own contact details.
                    contactButtons(phone: pet.contactPhone, email: pet.contactEmail, website: nil)
                }
            case .loaded(let shelter):
                loaded(shelter)
            }
        }
    }

    private func loaded(_ shelter: Shelter) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(shelter.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                if !shelter.address.isEmpty {
                    Text(shelter.address)
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                if let distance = pet.distance {
                    Text("\(Int(distance.rounded())) miles away")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }

            if let coordinate {
                miniMap(shelter: shelter, coordinate: coordinate)
            }

            contactButtons(phone: shelter.phone ?? pet.contactPhone,
                           email: shelter.email ?? pet.contactEmail,
                           website: shelter.website ?? shelter.petfinderURL)
        }
    }

    /// Non-interactive map; tapping opens Apple Maps for directions.
    private func miniMap(shelter: Shelter, coordinate: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate,
                                                        latitudinalMeters: 1500,
                                                        longitudinalMeters: 1500)),
            interactionModes: []) {
            Marker(shelter.name, coordinate: coordinate)
                .tint(Color.pfBrandPrimary)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
        .allowsHitTesting(false)
        .overlay {
            // Transparent layer on top that catches the tap.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { openURL(appleMapsURL(name: shelter.name, coordinate: coordinate)) }
        }
        .accessibilityElement()
        .accessibilityLabel("Open \(shelter.name) in Maps")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func contactButtons(phone: String?, email: String?, website: URL?) -> some View {
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

    private func appleMapsURL(name: String, coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
        ]
        return components?.url ?? URL(fileURLWithPath: "/")
    }
}
