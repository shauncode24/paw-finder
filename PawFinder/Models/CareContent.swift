import Foundation

/// Care Hub content, built into the app (SPEC wanted remote config; that's
/// cloud, so it's bundled here instead and works offline).

struct CareArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let icon: String
    let minutes: Int
    /// Markdown: **bold**, *italic*, and bullet lines starting with "- ".
    let body: String
}

struct BreedGuide: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let species: PetFilters.Species
    let size: String
    let lifespan: String
    let energy: String
    let temperament: String
    let care: String
    let goodFor: String

    // Used by the breed match quiz (BreedMatcher).
    let energyLevel: Int          // 1 = calm, 2 = moderate, 3 = very active
    let sizeLevel: Int            // 1 = small, 2 = medium, 3 = large
    let kidFriendly: Bool
    let firstTimeFriendly: Bool
    let apartmentFriendly: Bool
    let okAloneForAWhile: Bool    // copes with a workday alone (with a walk/visit)
}

struct CareChecklist: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let items: [String]
}

enum CareContent {
    static let articles: [CareArticle] = [
        CareArticle(
            id: "first-week", title: "Your pet's first week home",
            summary: "How to help a new pet settle in calmly.", icon: "house", minutes: 4,
            body: """
            The first few days are a big change for a shelter pet. **Go slow and keep things calm.**

            - Set up a quiet space with a bed, water, and a few toys before they arrive.
            - Keep visitors to a minimum for the first week.
            - Stick to a routine: meals, walks, and bedtime at the same times each day.
            - Let them explore one room at a time.
            - Expect some accidents, hiding, or a small appetite at first. It's normal.

            Most pets start to relax after about **three days**, learn the routine after **three weeks**, and feel truly at home after **three months**.
            """
        ),
        CareArticle(
            id: "supplies", title: "What to buy before adoption day",
            summary: "The essentials, without overspending.", icon: "cart", minutes: 3,
            body: """
            You don't need everything at once. Start with:

            - Food the shelter has been feeding (switch slowly over a week if you change it)
            - Food and water bowls
            - A bed or crate
            - Collar or harness, ID tag, and a leash (dogs)
            - Litter box, litter, and a scoop (cats)
            - A few chew toys or scratching post
            - Pet-safe cleaning spray for accidents

            *Tip:* ask the shelter what your pet likes. Familiar food and toys help a lot.
            """
        ),
        CareArticle(
            id: "vet", title: "The first vet visit",
            summary: "What to bring and what to ask.", icon: "cross.case", minutes: 3,
            body: """
            Book a check-up within the **first week or two**, even if the shelter did one.

            **Bring:** the shelter's medical records, vaccine history, and a list of questions.

            **Ask about:**
            - Vaccines and when the next ones are due
            - Flea, tick, and worm prevention
            - The right food and portion size
            - Spay/neuter, if not done yet
            - Microchip: make sure it's registered to **you**
            """
        ),
        CareArticle(
            id: "intro-pets", title: "Introducing a new pet to your other pets",
            summary: "Slow introductions prevent fights.", icon: "pawprint", minutes: 5,
            body: """
            **Dogs:** introduce them on neutral ground, like a walk, both on leashes. Keep the first meetings short and positive.

            **Cats:** keep the new cat in a separate room for a few days. Swap bedding so they learn each other's smell, then let them see each other through a gate.

            - Feed pets separately at first.
            - Give each pet their own bed, bowls, and (for cats) litter box.
            - Watch body language: stiff posture, growling, or hissing means slow down.
            - Never leave them alone together until you're sure they get along.
            """
        ),
        CareArticle(
            id: "training", title: "Gentle training basics",
            summary: "Rewards work better than punishment.", icon: "graduationcap", minutes: 4,
            body: """
            Shelter pets learn quickly with **positive reinforcement**: reward what you want to see.

            - Keep sessions short: 5 minutes, a few times a day.
            - Use small, tasty treats and lots of praise.
            - Start with name, sit, and come.
            - Be consistent: everyone at home uses the same words.
            - Never hit or shout. It breaks trust and makes fear worse.

            A local positive-reinforcement class is a great way to bond.
            """
        ),
        CareArticle(
            id: "budget", title: "The real cost of a pet",
            summary: "Plan for the yearly costs, not just adoption day.", icon: "dollarsign.circle", minutes: 3,
            body: """
            Adoption fees are usually the smallest cost. Plan for:

            - Food and treats
            - Yearly vet visits and vaccines
            - Flea, tick, and worm prevention
            - Grooming (some breeds need it often)
            - Pet insurance or an emergency fund
            - Pet sitting or boarding when you travel

            Setting aside a little each month makes surprise vet bills much less stressful.
            """
        ),
    ]

    static let breedGuides: [BreedGuide] = [
        BreedGuide(name: "Labrador Retriever", species: .dog, size: "Large", lifespan: "10–12 years", energy: "High",
                   temperament: "Friendly, eager to please, great with families.",
                   care: "Daily exercise and play; prone to weight gain, so watch portions.",
                   goodFor: "Active families, homes with a yard",
                   energyLevel: 3, sizeLevel: 3, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: false, okAloneForAWhile: false),
        BreedGuide(name: "Beagle", species: .dog, size: "Small to medium", lifespan: "12–15 years", energy: "High",
                   temperament: "Curious, merry, follows its nose.",
                   care: "Needs walks and a secure yard; can be vocal; food-motivated.",
                   goodFor: "Families with kids, people who enjoy walks",
                   energyLevel: 3, sizeLevel: 2, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: false, okAloneForAWhile: false),
        BreedGuide(name: "German Shepherd Dog", species: .dog, size: "Large", lifespan: "9–13 years", energy: "High",
                   temperament: "Loyal, smart, protective.",
                   care: "Needs training, mental challenges, and regular brushing.",
                   goodFor: "Experienced owners with time to train",
                   energyLevel: 3, sizeLevel: 3, kidFriendly: true, firstTimeFriendly: false,
                   apartmentFriendly: false, okAloneForAWhile: false),
        BreedGuide(name: "Golden Retriever", species: .dog, size: "Large", lifespan: "10–12 years", energy: "Medium to high",
                   temperament: "Gentle, patient, loves people.",
                   care: "Brush a few times a week; daily exercise.",
                   goodFor: "Families and first-time owners",
                   energyLevel: 2, sizeLevel: 3, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: false, okAloneForAWhile: false),
        BreedGuide(name: "Pit Bull Terrier", species: .dog, size: "Medium", lifespan: "12–14 years", energy: "High",
                   temperament: "Affectionate, playful, people-focused.",
                   care: "Daily exercise and training; check local housing rules.",
                   goodFor: "Active owners who want a cuddly companion",
                   energyLevel: 3, sizeLevel: 2, kidFriendly: true, firstTimeFriendly: false,
                   apartmentFriendly: true, okAloneForAWhile: false),
        BreedGuide(name: "Chihuahua", species: .dog, size: "Small", lifespan: "14–16 years", energy: "Medium",
                   temperament: "Big personality, devoted to one person.",
                   care: "Short walks; keep warm; gentle handling (fragile).",
                   goodFor: "Apartments and adults or older kids",
                   energyLevel: 2, sizeLevel: 1, kidFriendly: false, firstTimeFriendly: true,
                   apartmentFriendly: true, okAloneForAWhile: true),
        BreedGuide(name: "Poodle", species: .dog, size: "Small to large", lifespan: "12–15 years", energy: "Medium",
                   temperament: "Very smart, eager, low-shedding.",
                   care: "Regular grooming every few weeks; enjoys training games.",
                   goodFor: "Families, people with allergies",
                   energyLevel: 2, sizeLevel: 2, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: true, okAloneForAWhile: false),
        BreedGuide(name: "Greyhound", species: .dog, size: "Large", lifespan: "10–13 years", energy: "Low (indoors)",
                   temperament: "Gentle, quiet, a famous couch potato.",
                   care: "A couple of short walks and a safe place to sprint now and then.",
                   goodFor: "Calm homes, apartments, first-time owners",
                   energyLevel: 1, sizeLevel: 3, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: true, okAloneForAWhile: true),
        BreedGuide(name: "Domestic Short Hair", species: .cat, size: "Medium", lifespan: "12–18 years", energy: "Medium",
                   temperament: "Varies a lot: often easygoing and adaptable.",
                   care: "Low grooming; play daily; yearly vet visits.",
                   goodFor: "Almost any home, including apartments",
                   energyLevel: 2, sizeLevel: 2, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: true, okAloneForAWhile: true),
        BreedGuide(name: "Siamese", species: .cat, size: "Medium", lifespan: "12–20 years", energy: "High",
                   temperament: "Talkative, social, very attached to people.",
                   care: "Needs company and play; doesn't like being alone all day.",
                   goodFor: "People who are home a lot",
                   energyLevel: 3, sizeLevel: 2, kidFriendly: true, firstTimeFriendly: false,
                   apartmentFriendly: true, okAloneForAWhile: false),
        BreedGuide(name: "Maine Coon", species: .cat, size: "Large", lifespan: "12–15 years", energy: "Medium",
                   temperament: "Gentle giant, friendly, good with kids and dogs.",
                   care: "Brush a few times a week; lots of space to climb.",
                   goodFor: "Families and multi-pet homes",
                   energyLevel: 2, sizeLevel: 3, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: true, okAloneForAWhile: true),
        BreedGuide(name: "Ragdoll", species: .cat, size: "Large", lifespan: "12–17 years", energy: "Low",
                   temperament: "Relaxed, floppy, loves to be held.",
                   care: "Brush weekly; an indoor cat that enjoys calm homes.",
                   goodFor: "Quiet homes, first-time cat owners",
                   energyLevel: 1, sizeLevel: 3, kidFriendly: true, firstTimeFriendly: true,
                   apartmentFriendly: true, okAloneForAWhile: true),
    ]

    static let checklists: [CareChecklist] = [
        CareChecklist(id: "before", title: "Before adoption day", icon: "list.bullet.clipboard", items: [
            "Check your lease or building rules allow pets",
            "Agree on house rules with everyone at home",
            "Pet-proof the house: cables, plants, small objects",
            "Buy the basics (see \"What to buy\")",
            "Find a vet near you",
            "Plan time off or a quiet weekend for the first days",
        ]),
        CareChecklist(id: "first-week", title: "First week", icon: "calendar", items: [
            "Set up a quiet space with a bed and water",
            "Start a daily routine for meals and walks",
            "Book the first vet visit",
            "Register the microchip in your name",
            "Get an ID tag with your phone number",
            "Keep visitors to a minimum",
            "Take lots of photos!",
        ]),
    ]
}
