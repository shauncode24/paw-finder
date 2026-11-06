import UIKit

/// 12 made-up listings for demos and testing, added from Settings › Troubleshooting.
///
/// They are real Firestore listings owned by the signed-in lister, so they
/// appear in Discover, Swipe and on the map exactly like pets people post.
/// Photos are drawn on the phone (a coloured card with an emoji), so there is
/// nothing to download or upload by hand.
enum SamplePets {
    private struct Entry {
        let name: String
        let species: PetFilters.Species
        let breed: String
        let age: PetFilters.Age
        let gender: PetFilters.Gender
        let size: PetFilters.Size
        let colors: String
        let traits: [String]
        let kids: Bool?
        let dogs: Bool?
        let cats: Bool?
        let trained: Bool
        let fee: String
        let place: String
        let story: String
    }

    private static let entries: [Entry] = [
        Entry(name: "Bruno", species: .dog, breed: "Labrador Retriever", age: .adult, gender: .male, size: .large,
              colors: "Golden", traits: ["Friendly", "Playful", "Energetic"], kids: true, dogs: true, cats: nil,
              trained: true, fee: "2000", place: "Bandra, Mumbai",
              story: "Bruno loves fetch and long walks on the beach. He is gentle with children and learns tricks in minutes. He needs a family with a garden or a daily run."),
        Entry(name: "Luna", species: .cat, breed: "Domestic Shorthair", age: .young, gender: .female, size: .small,
              colors: "Black and white", traits: ["Curious", "Affectionate", "Quiet"], kids: true, dogs: nil, cats: true,
              trained: true, fee: "0", place: "Andheri, Mumbai",
              story: "Luna was found as a kitten under a parked car. She purrs the moment you sit down and loves window seats. Litter trained and ready for a calm flat."),
        Entry(name: "Coco", species: .dog, breed: "Indian Pariah", age: .young, gender: .female, size: .medium,
              colors: "Tan", traits: ["Smart", "Playful", "Gentle"], kids: true, dogs: true, cats: false,
              trained: false, fee: "0", place: "Powai, Mumbai",
              story: "Coco is a clever street rescue who already knows sit and paw. She is still learning her house manners and needs patient, consistent training."),
        Entry(name: "Mittens", species: .cat, breed: "Persian", age: .senior, gender: .female, size: .small,
              colors: "Cream", traits: ["Calm", "Cuddly", "Independent"], kids: false, dogs: false, cats: nil,
              trained: true, fee: "1000", place: "Thane",
              story: "Mittens is ten years old and wants a quiet lap to sleep on. Her long coat needs brushing a few times a week. Best in a calm adult home."),
        Entry(name: "Rocky", species: .dog, breed: "German Shepherd", age: .adult, gender: .male, size: .large,
              colors: "Black and tan", traits: ["Protective", "Smart", "Energetic"], kids: true, dogs: false, cats: false,
              trained: true, fee: "3000", place: "Navi Mumbai",
              story: "Rocky is a loyal, well trained guardian who needs a job and plenty of exercise. He does best as the only pet with an experienced owner."),
        Entry(name: "Peanut", species: .rabbit, breed: "Holland Lop", age: .baby, gender: .male, size: .small,
              colors: "Brown and white", traits: ["Shy", "Gentle", "Curious"], kids: true, dogs: nil, cats: nil,
              trained: false, fee: "500", place: "Vidyavihar, Mumbai",
              story: "Peanut is a young lop-eared rabbit who is still getting used to being held. He loves fresh greens and binkies around the living room."),
        Entry(name: "Simba", species: .cat, breed: "Orange Tabby", age: .baby, gender: .male, size: .small,
              colors: "Orange", traits: ["Playful", "Energetic", "Vocal"], kids: true, dogs: true, cats: true,
              trained: true, fee: "0", place: "Juhu, Mumbai",
              story: "Simba is a ten week old ball of energy who chases anything that moves. Vaccinated and dewormed. He wants a family that plays with him every day."),
        Entry(name: "Daisy", species: .dog, breed: "Beagle", age: .senior, gender: .female, size: .medium,
              colors: "Tricolour", traits: ["Calm", "Affectionate", "Gentle"], kids: true, dogs: true, cats: true,
              trained: true, fee: "0", place: "Pune",
              story: "Daisy is eight and has the best manners in the shelter. She enjoys slow sniffy walks and naps in the sun. A perfect first dog for a quiet home."),
        Entry(name: "Kiwi", species: .bird, breed: "Budgerigar", age: .young, gender: .female, size: .small,
              colors: "Green and yellow", traits: ["Vocal", "Curious", "Smart"], kids: true, dogs: nil, cats: false,
              trained: false, fee: "300", place: "Colaba, Mumbai",
              story: "Kiwi whistles along to music and is learning to step up onto a finger. She needs a roomy cage and an hour of out-of-cage time every day."),
        Entry(name: "Max", species: .dog, breed: "Pug", age: .adult, gender: .male, size: .small,
              colors: "Fawn", traits: ["Cuddly", "Quiet", "Friendly"], kids: true, dogs: true, cats: true,
              trained: true, fee: "1500", place: "Borivali, Mumbai",
              story: "Max snores, snuggles and follows you from room to room. He needs short walks only, and a cool home in summer. Great with flat living."),
        Entry(name: "Shadow", species: .cat, breed: "Bombay", age: .adult, gender: .male, size: .medium,
              colors: "Black", traits: ["Independent", "Shy", "Gentle"], kids: false, dogs: false, cats: nil,
              trained: true, fee: "0", place: "Lonavala",
              story: "Shadow takes time to trust but then shows up for head scratches every evening. He has been in foster care for months and now needs a home of his own."),
        Entry(name: "Tara", species: .dog, breed: "Indie Mix", age: .baby, gender: .female, size: .medium,
              colors: "Brown and white", traits: ["Playful", "Friendly", "Energetic"], kids: true, dogs: true, cats: nil,
              trained: false, fee: "0", place: "Nashik",
              story: "Tara is a four month old puppy rescued with her siblings. She is vaccinated, loves chewing shoes and needs a foster or forever home this month."),
    ]

    /// Adds the sample listings. Pets whose name you already posted are skipped,
    /// so pressing the button twice doesn't create duplicates.
    /// - Returns: how many were added, and a problem message if something failed.
    @MainActor
    static func add(using listings: ListingsService, owner: ListerProfile) async -> (added: Int, problem: String?) {
        let existing = Set(listings.myListings.map { $0.name.lowercased() })
        var added = 0
        for (index, entry) in entries.enumerated() where !existing.contains(entry.name.lowercased()) {
            var draft = ListingDraft()
            draft.name = entry.name
            draft.species = entry.species
            draft.breed = entry.breed
            draft.age = entry.age
            draft.gender = entry.gender
            draft.size = entry.size
            draft.colors = entry.colors
            draft.temperament = Set(entry.traits)
            draft.goodWithKids = TriState(entry.kids)
            draft.goodWithDogs = TriState(entry.dogs)
            draft.goodWithCats = TriState(entry.cats)
            draft.houseTrained = entry.trained
            draft.vaccinated = true
            draft.spayedNeutered = entry.age != .baby
            draft.microchipped = index % 2 == 0
            draft.adoptionFee = entry.fee
            draft.description = entry.story
            draft.city = entry.place
            draft.state = "Maharashtra"
            draft.contactEmail = owner.contactEmail
            draft.contactPhone = owner.contactPhone
            if entry.name == "Tara" {
                draft.fosterNeeded = true
                draft.fosterReason = "The shelter is full and Tara needs a calm place to grow up for a few weeks."
                draft.fosterDuration = .weeks
            }
            if entry.name == "Shadow" { draft.status = .pending }

            let hue = CGFloat(index) / CGFloat(entries.count)
            draft.photos = [
                photo(emoji: emoji(for: entry.species), caption: entry.name, hue: hue),
                photo(emoji: "🐾", caption: entry.breed, hue: (hue + 0.5).truncatingRemainder(dividingBy: 1)),
            ]

            do {
                try await listings.publish(draft, owner: owner)
                added += 1
            } catch {
                return (added, error.localizedDescription)
            }
        }
        return (added, nil)
    }

    private static func emoji(for species: PetFilters.Species) -> String {
        switch species {
        case .dog: "🐶"
        case .cat: "🐱"
        case .rabbit: "🐰"
        case .bird: "🐦"
        }
    }

    /// A 800 x 800 coloured card with a big emoji and a caption, as JPEG bytes.
    private static func photo(emoji: String, caption: String, hue: CGFloat) -> Data {
        let size = CGSize(width: 800, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let light = UIColor(hue: hue, saturation: 0.30, brightness: 0.97, alpha: 1)
            let dark = UIColor(hue: hue, saturation: 0.55, brightness: 0.78, alpha: 1)
            let colors = [light.cgColor, dark.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                     end: CGPoint(x: size.width, y: size.height), options: [])
            }

            let emojiAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 380)]
            let emojiSize = (emoji as NSString).size(withAttributes: emojiAttributes)
            (emoji as NSString).draw(at: CGPoint(x: (size.width - emojiSize.width) / 2, y: 110),
                                     withAttributes: emojiAttributes)

            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: style,
            ]
            (caption as NSString).draw(in: CGRect(x: 40, y: 620, width: size.width - 80, height: 100),
                                       withAttributes: captionAttributes)
        }
        return image.jpegData(compressionQuality: 0.7) ?? Data()
    }
}
