import MapKit
import SwiftUI

/// On the pet detail screen: the shelter's name, address, a small map,
/// contact buttons, directions, and a link to the full shelter profile.
struct ShelterCard: View {
    let state: PetDetailViewModel.ShelterState
    let coordinate: CLLocationCoordinate2D?
    /// The user's last known location, for "x miles away" (nil if never shared).
    var userLocation: CLLocation?
    let pet: Pet
    let retry: () -> Void

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
                    ContactButtons(phone: pet.contactPhone, email: pet.contactEmail, website: nil)
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
                OpenStatusLabel(shelter: shelter)
                if let distance = distanceInMiles {
                    Text("\(Int(distance.rounded())) miles away")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }

            if let coordinate {
                ShelterMiniMap(name: shelter.name, coordinate: coordinate)
                Link(destination: MapsLink.directions(name: shelter.name, coordinate: coordinate)) {
                    Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            ContactButtons(phone: shelter.phone ?? pet.contactPhone,
                           email: shelter.email ?? pet.contactEmail,
                           website: shelter.website ?? shelter.petfinderURL)

            NavigationLink(value: Route.shelter(id: shelter.id)) {
                HStack {
                    Text("View shelter and its pets")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pfBrandPrimary)
            }
        }
    }

    /// Prefer the real distance from the user; fall back to Petfinder's search distance.
    private var distanceInMiles: Double? {
        if let userLocation, let coordinate {
            return userLocation.miles(to: coordinate)
        }
        return pet.distance
    }
}
