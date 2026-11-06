import UIKit

/// 15 made-up listings for demos and testing, added from Settings › Troubleshooting.
///
/// They are real Firestore listings owned by the signed-in lister, so they
/// appear in Discover, Swipe and on the map exactly like pets people post.
///
/// Photos are real animal photos downloaded when you press the button, from free
/// public picture services (dog.ceo, The Cat API, LoremFlickr), then shrunk and
/// stored in Firestore like any other photo. If a download fails, that pet gets a
/// plain coloured card instead, and the result message says so.
enum SamplePets {
    /// Where a pet's photos come from.
    private enum PhotoSource {
        case dog(breed: String?)       // dog.ceo breed name, or nil for any dog
        case cat(breedID: String?)     // The Cat API breed id, or nil for any cat
        case flickr(String)            // a keyword for LoremFlickr
    }

    private struct Entry {
        let name: String
        let species: PetFilters.Species
        var custom = ""                // the animal, when species is Other
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
        let source: PhotoSource
        let story: String
    }

    private static let entries: [Entry] = [
        Entry(name: "Bruno", species: .dog, breed: "Labrador Retriever", age: .adult, gender: .male, size: .large,
              colors: "Golden", traits: ["Friendly", "Playful", "Energetic"], kids: true, dogs: true, cats: nil,
              trained: true, fee: "2000", place: "Bandra, Mumbai", source: .dog(breed: "labrador"),
              story: "Bruno loves fetch and long walks on the beach. He is gentle with children and learns tricks in minutes. He needs a family with a garden or a daily run."),
        Entry(name: "Luna", species: .cat, breed: "Domestic Short Hair", age: .young, gender: .female, size: .small,
              colors: "Black and white", traits: ["Curious", "Affectionate", "Quiet"], kids: true, dogs: nil, cats: true,
              trained: true, fee: "0", place: "Andheri, Mumbai", source: .cat(breedID: nil),
              story: "Luna was found as a kitten under a parked car. She purrs the moment you sit down and loves window seats. Litter trained and ready for a calm flat."),
        Entry(name: "Coco", species: .dog, breed: "Indian Pariah Dog", age: .young, gender: .female, size: .medium,
              colors: "Tan", traits: ["Smart", "Playful", "Gentle"], kids: true, dogs: true, cats: false,
              trained: false, fee: "0", place: "Powai, Mumbai", source: .dog(breed: nil),
              story: "Coco is a clever street rescue who already knows sit and paw. She is still learning her house manners and needs patient, consistent training."),
        Entry(name: "Mittens", species: .cat, breed: "Persian", age: .senior, gender: .female, size: .small,
              colors: "Cream", traits: ["Calm", "Cuddly", "Independent"], kids: false, dogs: false, cats: nil,
              trained: true, fee: "1000", place: "Thane", source: .cat(breedID: "pers"),
              story: "Mittens is ten years old and wants a quiet lap to sleep on. Her long coat needs brushing a few times a week. Best in a calm adult home."),
        Entry(name: "Rocky", species: .dog, breed: "German Shepherd Dog", age: .adult, gender: .male, size: .large,
              colors: "Black and tan", traits: ["Protective", "Smart", "Energetic"], kids: true, dogs: false, cats: false,
              trained: true, fee: "3000", place: "Navi Mumbai", source: .dog(breed: "germanshepherd"),
              story: "Rocky is a loyal, well trained guardian who needs a job and plenty of exercise. He does best as the only pet with an experienced owner."),
        Entry(name: "Peanut", species: .rabbit, breed: "Holland Lop", age: .baby, gender: .male, size: .small,
              colors: "Brown and white", traits: ["Shy", "Gentle", "Curious"], kids: true, dogs: nil, cats: nil,
              trained: false, fee: "500", place: "Vidyavihar, Mumbai", source: .flickr("rabbit"),
              story: "Peanut is a young lop-eared rabbit who is still getting used to being held. He loves fresh greens and binkies around the living room."),
        Entry(name: "Simba", species: .cat, breed: "Tabby", age: .baby, gender: .male, size: .small,
              colors: "Orange", traits: ["Playful", "Energetic", "Vocal"], kids: true, dogs: true, cats: true,
              trained: true, fee: "0", place: "Juhu, Mumbai", source: .flickr("kitten"),
              story: "Simba is a ten week old ball of energy who chases anything that moves. Vaccinated and dewormed. He wants a family that plays with him every day."),
        Entry(name: "Daisy", species: .dog, breed: "Beagle", age: .senior, gender: .female, size: .medium,
              colors: "Tricolour", traits: ["Calm", "Affectionate", "Gentle"], kids: true, dogs: true, cats: true,
              trained: true, fee: "0", place: "Pune", source: .dog(breed: "beagle"),
              story: "Daisy is eight and has the best manners in the shelter. She enjoys slow sniffy walks and naps in the sun. A perfect first dog for a quiet home."),
        Entry(name: "Kiwi", species: .bird, breed: "Budgerigar", age: .young, gender: .female, size: .small,
              colors: "Green and yellow", traits: ["Vocal", "Curious", "Smart"], kids: true, dogs: nil, cats: false,
              trained: false, fee: "300", place: "Colaba, Mumbai", source: .flickr("budgerigar"),
              story: "Kiwi whistles along to music and is learning to step up onto a finger. She needs a roomy cage and an hour of out-of-cage time every day."),
        Entry(name: "Max", species: .dog, breed: "Pug", age: .adult, gender: .male, size: .small,
              colors: "Fawn", traits: ["Cuddly", "Quiet", "Friendly"], kids: true, dogs: true, cats: true,
              trained: true, fee: "1500", place: "Borivali, Mumbai", source: .dog(breed: "pug"),
              story: "Max snores, snuggles and follows you from room to room. He needs short walks only, and a cool home in summer. Great with flat living."),
        Entry(name: "Shadow", species: .cat, breed: "Bombay", age: .adult, gender: .male, size: .medium,
              colors: "Black", traits: ["Independent", "Shy", "Gentle"], kids: false, dogs: false, cats: nil,
              trained: true, fee: "0", place: "Lonavala", source: .cat(breedID: "bomb"),
              story: "Shadow takes time to trust but then shows up for head scratches every evening. He has been in foster care for months and now needs a home of his own."),
        Entry(name: "Tara", species: .dog, breed: "Mixed Breed", age: .baby, gender: .female, size: .medium,
              colors: "Brown and white", traits: ["Playful", "Friendly", "Energetic"], kids: true, dogs: true, cats: nil,
              trained: false, fee: "0", place: "Nashik", source: .dog(breed: nil),
              story: "Tara is a four month old puppy rescued with her siblings. She is vaccinated, loves chewing shoes and needs a foster or forever home this month."),
        Entry(name: "Biscuit", species: .guineaPig, breed: "Abyssinian", age: .young, gender: .male, size: .small,
              colors: "Ginger and white", traits: ["Vocal", "Friendly", "Curious"], kids: true, dogs: nil, cats: nil,
              trained: false, fee: "400", place: "Dadar, Mumbai", source: .flickr("guineapig"),
              story: "Biscuit squeaks happily whenever the fridge opens. Guinea pigs like company, so he would love to join another one, or a family who spends time with him."),
        Entry(name: "Ziggy", species: .reptile, breed: "Bearded Dragon", age: .adult, gender: .male, size: .small,
              colors: "Sandy yellow", traits: ["Calm", "Independent", "Curious"], kids: true, dogs: nil, cats: nil,
              trained: false, fee: "2500", place: "Chembur, Mumbai", source: .flickr("beardeddragon"),
              story: "Ziggy is a relaxed bearded dragon who enjoys basking and eating greens. He comes with his tank, heat lamp and UVB light. Best for someone with reptile experience."),
        Entry(name: "Pepper", species: .other, custom: "Hedgehog", breed: "African Pygmy", age: .young, gender: .female, size: .small,
              colors: "Salt and pepper", traits: ["Shy", "Quiet", "Independent"], kids: false, dogs: nil, cats: nil,
              trained: false, fee: "1800", place: "Goregaon, Mumbai", source: .flickr("hedgehog"),
              story: "Pepper is a nocturnal hedgehog who rolls into a ball when startled and warms up slowly. She runs on her wheel all night, so she suits a calm bedroom or study."),
    ]

    /// Adds the sample listings. Pets whose name you already posted are skipped,
    /// so pressing the button twice doesn't create duplicates.
    /// - Returns: how many were added, how many had to use a plain card instead of a
    ///   real photo, and a problem message if something failed.
    @MainActor
    static func add(using listings: ListingsService, owner: ListerProfile)
        async -> (added: Int, withoutRealPhoto: Int, problem: String?) {
        let existing = Set(listings.myListings.map { $0.name.lowercased() })
        var added = 0
        var plain = 0
        for (index, entry) in entries.enumerated() where !existing.contains(entry.name.lowercased()) {
            var draft = ListingDraft()
            draft.name = entry.name
            draft.species = entry.species
            draft.customSpecies = entry.custom
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

            var photos: [Data] = await fetchPhotos(entry.source, seed: index)
            if photos.isEmpty {
                plain += 1
                photos = [plainCard(caption: entry.name, hue: CGFloat(index) / CGFloat(entries.count))]
            }
            draft.photos = photos

            do {
                try await listings.publish(draft, owner: owner)
                added += 1
            } catch {
                return (added, plain, error.localizedDescription)
            }
        }
        return (added, plain, nil)
    }

    // MARK: - Downloading real photos

    private static func fetchPhotos(_ source: PhotoSource, seed: Int) async -> [Data] {
        var urls: [URL] = []
        switch source {
        case .dog(let breed):
            let path: String = breed.map { "breed/\($0)/images/random/2" } ?? "breeds/image/random/2"
            if let url = URL(string: "https://dog.ceo/api/\(path)") {
                urls = await listedURLs(at: url)
            }
        case .cat(let breedID):
            var text = "https://api.thecatapi.com/v1/images/search?limit=2"
            if let breedID { text += "&breed_ids=\(breedID)" }
            if let url = URL(string: text) {
                urls = await listedURLs(at: url)
            }
        case .flickr(let keyword):
            // "lock" makes LoremFlickr return the same picture every time for this number.
            urls = (1...2).compactMap { URL(string: "https://loremflickr.com/800/800/\(keyword)?lock=\(seed * 10 + $0)") }
        }

        var photos: [Data] = []
        for url in urls.prefix(2) {
            guard let data = await download(url), UIImage(data: data) != nil,
                  let small = ImageCompressor.fullSize(from: data) else { continue }
            photos.append(small)
        }
        return photos
    }

    /// Reads the picture addresses out of a dog.ceo or The Cat API answer.
    private static func listedURLs(at url: URL) async -> [URL] {
        guard let data = await download(url),
              let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var texts: [String] = []
        if let object = json as? [String: Any], let list = object["message"] as? [String] {
            texts = list                                              // dog.ceo
        } else if let list = json as? [[String: Any]] {
            texts = list.compactMap { $0["url"] as? String }          // The Cat API
        }
        return texts.compactMap { URL(string: $0) }
    }

    private static func download(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    /// Used only when a download fails: a plain coloured card with the pet's name.
    private static func plainCard(caption: String, hue: CGFloat) -> Data {
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
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: style,
            ]
            (caption as NSString).draw(in: CGRect(x: 40, y: 330, width: size.width - 80, height: 140),
                                       withAttributes: attributes)
        }
        return image.jpegData(compressionQuality: 0.7) ?? Data()
    }
}
