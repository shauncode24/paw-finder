import Foundation

extension MessagesStore {
    /// Starts (or reopens) the chat with whoever listed a pet.
    /// - Parameters:
    ///   - listerName: shown to the adopter; falls back to the name saved on the listing.
    ///   - displayName: the adopter's own name, shown to the lister.
    /// - Returns: the conversation ID, for `Route.conversation`.
    func openChat(about pet: Pet, listerName: String?, as me: AppUser, displayName: String) async throws -> String {
        let adopterName = displayName.trimmingCharacters(in: .whitespaces)
        return try await openConversation(
            listingID: pet.id,
            listingName: pet.name,
            listingSpecies: pet.species,
            adopterID: me.id,
            adopterName: adopterName.isEmpty ? "An adopter" : adopterName,
            listerID: pet.shelterID,
            listerName: listerName ?? pet.listedBy ?? "Lister"
        )
    }
}
