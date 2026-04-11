//
//  Models.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

// MARK: - Plant Listing (Marketplace)

struct PlantListing: Identifiable {
    let id: UUID
    let name: String
    let species: String
    let price: Double
    let category: PlantCategory
    let condition: PlantCondition
    let sellerName: String
    let location: String
    let description: String
    let phoneNumber: String?
    let imageURLs: [String]
    let iconName: String
    let iconColor: Color
    let postedDaysAgo: Int
    let status: String

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        price: Double,
        category: PlantCategory,
        condition: PlantCondition,
        sellerName: String,
        location: String,
        description: String,
        phoneNumber: String? = nil,
        imageURLs: [String] = [],
        iconName: String,
        iconColor: Color,
        postedDaysAgo: Int,
        status: String = "active"
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.price = price
        self.category = category
        self.condition = condition
        self.sellerName = sellerName
        self.location = location
        self.description = description
        self.phoneNumber = phoneNumber
        self.imageURLs = imageURLs
        self.iconName = iconName
        self.iconColor = iconColor
        self.postedDaysAgo = postedDaysAgo
        self.status = status
    }

    var primaryImageURL: String? {
        imageURLs.first
    }
}

enum PlantCategory: String, CaseIterable {
    case all       = "All"
    case indoor    = "Indoor"
    case outdoor   = "Outdoor"
    case succulents = "Succulents"
    case tropical  = "Tropical"
    case herbs     = "Herbs"

    var icon: String {
        switch self {
        case .all:        return "square.grid.2x2.fill"
        case .indoor:     return "house.fill"
        case .outdoor:    return "sun.max.fill"
        case .succulents: return "leaf.fill"
        case .tropical:   return "flame.fill"
        case .herbs:      return "cup.and.saucer.fill"
        }
    }
}

enum PlantCondition: String {
    case excellent = "Excellent"
    case good      = "Good"
    case fair      = "Fair"
}

// MARK: - Caregiver (Plant Sitting)

struct Caregiver: Identifiable {
    let id: UUID
    let name: String
    let bio: String
    let rating: Double
    let reviewCount: Int
    let pricePerDay: Double
    let specialties: [String]
    let location: String
    let yearsExperience: Int
    let avatarColor: Color
    let isAvailable: Bool

    init(
        id: UUID = UUID(),
        name: String,
        bio: String,
        rating: Double,
        reviewCount: Int,
        pricePerDay: Double,
        specialties: [String],
        location: String,
        yearsExperience: Int,
        avatarColor: Color,
        isAvailable: Bool
    ) {
        self.id = id
        self.name = name
        self.bio = bio
        self.rating = rating
        self.reviewCount = reviewCount
        self.pricePerDay = pricePerDay
        self.specialties = specialties
        self.location = location
        self.yearsExperience = yearsExperience
        self.avatarColor = avatarColor
        self.isAvailable = isAvailable
    }
}

enum BookingStatus: String {
    case pending = "pending"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

enum BookingRole: String, CaseIterable {
    case owner = "Owner"
    case caregiver = "Caregiver"
}

struct PlantSittingBooking: Identifiable {
    let id: UUID
    let ownerID: UUID
    let caregiverID: UUID
    let ownerName: String
    let caregiverName: String
    let plantName: String
    let notes: String
    let startDate: Date
    let endDate: Date
    let totalPrice: Double
    let status: BookingStatus
    let createdAt: Date?

    init(
        id: UUID,
        ownerID: UUID,
        caregiverID: UUID,
        ownerName: String,
        caregiverName: String,
        plantName: String,
        notes: String,
        startDate: Date,
        endDate: Date,
        totalPrice: Double,
        status: BookingStatus,
        createdAt: Date?
    ) {
        self.id = id
        self.ownerID = ownerID
        self.caregiverID = caregiverID
        self.ownerName = ownerName
        self.caregiverName = caregiverName
        self.plantName = plantName
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.totalPrice = totalPrice
        self.status = status
        self.createdAt = createdAt
    }

    var displayPlantName: String {
        plantName.isEmpty ? "Plant sitting booking" : plantName
    }

    var stayLength: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    func role(for userID: UUID) -> BookingRole? {
        if ownerID == userID { return .owner }
        if caregiverID == userID { return .caregiver }
        return nil
    }

    func counterpartName(for userID: UUID) -> String {
        ownerID == userID ? caregiverName : ownerName
    }
}

struct CaregiverReviewEntry: Identifiable {
    let id: UUID
    let bookingID: UUID
    let caregiverID: UUID
    let reviewerID: UUID
    let caregiverName: String
    let reviewerName: String
    let plantName: String
    let rating: Double
    let comment: String
    let createdAt: Date?
}

struct ReviewCenterData {
    let receivedSummaryRating: Double
    let receivedSummaryCount: Int
    let pending: [PlantSittingBooking]
    let received: [CaregiverReviewEntry]
    let given: [CaregiverReviewEntry]

    static let empty = ReviewCenterData(
        receivedSummaryRating: 0,
        receivedSummaryCount: 0,
        pending: [],
        received: [],
        given: []
    )
}

// MARK: - Plant Care Tip

struct PlantCareTip: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let content: String
    let category: TipCategory
    let difficulty: TipDifficulty
    let readMinutes: Int

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        content: String,
        category: TipCategory,
        difficulty: TipDifficulty,
        readMinutes: Int
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.category = category
        self.difficulty = difficulty
        self.readMinutes = readMinutes
    }
}

enum TipCategory: String, CaseIterable {
    case watering    = "Watering"
    case sunlight    = "Sunlight"
    case fertilizing = "Fertilizing"
    case repotting   = "Repotting"
    case pests       = "Pests"
    case general     = "General"

    var icon: String {
        switch self {
        case .watering:    return "drop.fill"
        case .sunlight:    return "sun.max.fill"
        case .fertilizing: return "leaf.fill"
        case .repotting:   return "arrow.up.circle.fill"
        case .pests:       return "exclamationmark.shield.fill"
        case .general:     return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .watering:    return .blue
        case .sunlight:    return .yellow
        case .fertilizing: return .green
        case .repotting:   return .brown
        case .pests:       return .red
        case .general:     return .purple
        }
    }
}

enum TipDifficulty: String {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"
}

// MARK: - Sample Data: Plant Listings

extension PlantListing {
    static let samples: [PlantListing] = [
        PlantListing(
            name: "Monstera Deliciosa", species: "Monstera deliciosa",
            price: 3500, category: .indoor, condition: .excellent,
            sellerName: "Nusrat Jahan", location: "Dhaka",
            description: "Healthy Monstera with big split leaves. Grown in bright indirect light. Comes with pot.",
            iconName: "leaf.fill", iconColor: .green, postedDaysAgo: 1
        ),
        PlantListing(
            name: "Snake Plant", species: "Sansevieria",
            price: 1200, category: .indoor, condition: .good,
            sellerName: "Rakib Hasan", location: "Chattogram",
            description: "Low maintenance plant, perfect for beginners. Can survive in low light.",
            iconName: "leaf", iconColor: .teal, postedDaysAgo: 3
        ),
        PlantListing(
            name: "Aloe Vera", species: "Aloe barbadensis",
            price: 800, category: .succulents, condition: .excellent,
            sellerName: "Tania Akter", location: "Sylhet",
            description: "Fresh aloe plant with multiple baby plants. Good for skin care and home use.",
            iconName: "staroflife.fill", iconColor: .mint, postedDaysAgo: 2
        ),
        PlantListing(
            name: "Fiddle Leaf Fig", species: "Ficus lyrata",
            price: 7000, category: .indoor, condition: .excellent,
            sellerName: "Mahmud Rahman", location: "Dhaka",
            description: "Large indoor plant, around 4 feet tall. Perfect for living room decoration.",
            iconName: "tree.fill", iconColor: .green, postedDaysAgo: 5
        ),
        PlantListing(
            name: "Tulsi (Holy Basil)", species: "Ocimum tenuiflorum",
            price: 500, category: .herbs, condition: .good,
            sellerName: "Shila Roy", location: "Khulna",
            description: "Fresh tulsi plant, useful for home remedies and daily use.",
            iconName: "cup.and.saucer.fill", iconColor: .green, postedDaysAgo: 2
        ),
        PlantListing(
            name: "Money Plant", species: "Epipremnum aureum",
            price: 600, category: .indoor, condition: .excellent,
            sellerName: "Imran Chowdhury", location: "Dhaka",
            description: "Easy growing plant, great for indoor decoration and air purification.",
            iconName: "leaf.fill", iconColor: .green, postedDaysAgo: 1
        ),
    ]
}

// MARK: - Sample Data: Caregivers

extension Caregiver {
    static let samples: [Caregiver] = [
        Caregiver(
            name: "Ayesha Rahman",
            bio: "Plant lover with 5+ years experience. I take care of indoor and outdoor plants with proper attention.",
            rating: 4.9, reviewCount: 40, pricePerDay: 300,
            specialties: ["Indoor", "Succulents"],
            location: "Dhaka", yearsExperience: 5,
            avatarColor: .green, isAvailable: true
        ),
        Caregiver(
            name: "Tanvir Ahmed",
            bio: "I have my own small nursery. I can handle all types of plants carefully.",
            rating: 4.7, reviewCount: 25, pricePerDay: 250,
            specialties: ["Outdoor", "Herbs"],
            location: "Chattogram", yearsExperience: 3,
            avatarColor: .teal, isAvailable: true
        ),
        Caregiver(
            name: "Nadia Sultana",
            bio: "Experienced in plant care and pest control. I will keep your plants safe and healthy.",
            rating: 5.0, reviewCount: 60, pricePerDay: 400,
            specialties: ["All Types", "Pest Care"],
            location: "Sylhet", yearsExperience: 6,
            avatarColor: .mint, isAvailable: false
        ),
    ]
}
// MARK: - Sample Data: Plant Care Tips

extension PlantCareTip {
    static let samples: [PlantCareTip] = [
        PlantCareTip(
            title: "The Finger Test",
            summary: "Never guess — always test soil moisture before watering.",
            content: "Push your finger about an inch into the soil. If it feels dry, it is time to water. If it still feels moist, wait another day or two. Overwatering is the number-one killer of houseplants and leads to root rot, yellowing leaves, and fungus gnats.",
            category: .watering, difficulty: .beginner, readMinutes: 2
        ),
        PlantCareTip(
            title: "Bottom Watering",
            summary: "Let roots absorb water upward for healthier, deeper growth.",
            content: "Place your pot in a shallow tray of water for 20–30 minutes. Roots absorb water from the bottom up, which encourages deeper root growth and prevents fungus gnats on the topsoil. Remove the pot from the tray once the top layer of soil feels slightly moist.",
            category: .watering, difficulty: .beginner, readMinutes: 3
        ),
        PlantCareTip(
            title: "Bright Indirect vs. Direct Light",
            summary: "Understanding light levels protects your plants from sunburn.",
            content: "Bright indirect light means a spot near a window where the sun does not shine directly on the leaves. Direct sunlight means the rays hit the plant. Most tropical houseplants such as Monsteras, Pothos and Philodendrons prefer bright indirect light. Succulents and cacti generally love direct sun.",
            category: .sunlight, difficulty: .beginner, readMinutes: 3
        ),
        PlantCareTip(
            title: "Rotate for Even Growth",
            summary: "Turn your pots regularly to prevent lopsided plants.",
            content: "Plants naturally grow toward their light source. Rotate your pot a quarter turn every week so all sides receive equal light. This ensures even, symmetrical growth and prevents the plant from permanently leaning toward one side.",
            category: .sunlight, difficulty: .beginner, readMinutes: 2
        ),
        PlantCareTip(
            title: "Growing Season Feeding",
            summary: "Feed your plants only during spring and summer.",
            content: "Plants are actively growing in spring and summer and benefit from a balanced liquid fertiliser every 2–4 weeks. Reduce feeding in autumn and stop entirely in winter when growth naturally slows. Over-fertilising causes salt build-up in the soil and chemical root burn.",
            category: .fertilizing, difficulty: .intermediate, readMinutes: 4
        ),
        PlantCareTip(
            title: "When to Repot",
            summary: "Roots circling the pot? Time for a new home.",
            content: "Signs your plant needs repotting: roots growing out of drainage holes, soil dries out much faster than usual, or the plant is visibly top-heavy and toppling. Choose a new pot only 1–2 inches wider than the current one — too large a pot holds excess moisture and can cause root rot.",
            category: .repotting, difficulty: .intermediate, readMinutes: 5
        ),
        PlantCareTip(
            title: "Defeating Spider Mites",
            summary: "Catch them early before they take over the whole plant.",
            content: "Spider mites thrive in hot, dry conditions. Look for fine webbing and tiny moving dots on the undersides of leaves. Isolate the affected plant immediately. Wipe leaves with a damp cloth, increase ambient humidity, and treat with a diluted neem oil spray (1 tsp per litre of water) weekly for three weeks.",
            category: .pests, difficulty: .intermediate, readMinutes: 4
        ),
        PlantCareTip(
            title: "Cleaning Dusty Leaves",
            summary: "Clean leaves absorb light far more efficiently.",
            content: "Wipe large leaves gently with a soft, damp cloth every few weeks. A layer of dust blocks sunlight and significantly reduces photosynthesis. For small-leaved plants such as ferns or maidenhair, a gentle lukewarm shower is the easiest method. Avoid leaf-shine sprays as they can block stomata.",
            category: .general, difficulty: .beginner, readMinutes: 2
        ),
    ]
}
