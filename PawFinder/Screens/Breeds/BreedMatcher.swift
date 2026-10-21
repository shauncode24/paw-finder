import Foundation

/// Scores how well each breed fits the user's lifestyle answers.
/// Simple, explainable rules (no ML): each answer nudges the score up or
/// down and adds a short reason the user can read.
enum BreedMatcher {
    struct Match: Identifiable {
        let guide: BreedGuide
        let score: Int            // 5–99
        let pros: [String]
        let cons: [String]
        var id: String { guide.id }
    }

    static func matches(for profile: AdopterProfile, in guides: [BreedGuide] = CareContent.breedGuides) -> [Match] {
        guides.map { match($0, profile) }.sorted { $0.score > $1.score }
    }

    static func match(_ guide: BreedGuide, _ profile: AdopterProfile) -> Match {
        var score = 70
        var pros: [String] = []
        var cons: [String] = []

        if !profile.preferredSpecies.isEmpty, !profile.preferredSpecies.contains(guide.species) {
            score -= 40
            cons.append("Not the kind of animal you're looking for")
        }

        switch profile.homeType {
        case .apartment?:
            if guide.apartmentFriendly { score += 10; pros.append("Happy in an apartment") } else {
                score -= 25; cons.append("Needs more space than an apartment")
            }
        case .houseWithYard?, .farm?:
            if guide.energyLevel == 3 { score += 10; pros.append("Will love your outdoor space") }
        default:
            break
        }

        if let kids = profile.kids, kids != .none {
            if guide.kidFriendly { score += 10; pros.append("Good with kids") } else {
                score -= 30; cons.append("Better with adults or older kids")
            }
        }

        if profile.experience == .firstTime {
            if guide.firstTimeFriendly { score += 10; pros.append("Great for first-time owners") } else {
                score -= 25; cons.append("Best with an experienced owner")
            }
        }

        switch profile.schedule {
        case .awayAllDay?:
            if guide.okAloneForAWhile { score += 10; pros.append("Copes with a workday alone") } else {
                score -= 25; cons.append("Doesn't like long days alone")
            }
        case .mostlyHome?:
            score += 5
            if !guide.okAloneForAWhile { pros.append("Will love having you home") }
        default:
            break
        }

        switch profile.activity {
        case .veryActive?:
            if guide.energyLevel == 3 { score += 15; pros.append("Can keep up with your active life") }
            if guide.energyLevel == 1 { score -= 10; cons.append("Prefers a slower pace than yours") }
        case .relaxed?:
            if guide.energyLevel == 1 { score += 10; pros.append("Matches your relaxed pace") }
            if guide.energyLevel == 3 { score -= 20; cons.append("Needs more exercise than you might like") }
        case .moderate?:
            if guide.energyLevel == 2 { score += 10; pros.append("Energy level matches yours") }
        case nil:
            break
        }

        if !profile.preferredSizes.isEmpty {
            let sizeLevels = Set(profile.preferredSizes.map { size -> Int in
                switch size {
                case .small: 1
                case .medium: 2
                case .large, .xlarge: 3
                }
            })
            if sizeLevels.contains(guide.sizeLevel) { score += 10; pros.append("The size you're after") } else {
                score -= 10; cons.append("Not your preferred size")
            }
        }

        return Match(guide: guide, score: min(max(score, 5), 99), pros: pros, cons: cons)
    }
}
