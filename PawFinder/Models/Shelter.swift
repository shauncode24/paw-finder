import Foundation

/// The shelter or rescue group that lists a pet ("organization" in Petfinder).
struct Shelter: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let address: String          // "7201 Levander Loop, Austin, TX 78702"
    let website: URL?
    let petfinderURL: URL?
}
