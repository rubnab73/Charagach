//
//  SupabaseDataStore.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import Supabase

struct NewListingInput {
    let name: String
    let species: String
    let price: Double
    let category: PlantCategory
    let condition: PlantCondition
    let city: String
    let description: String
}

struct NewCaregiverInput {
    let fullName: String
    let location: String
    let bio: String
    let specialties: [String]
    let yearsExperience: Int
    let pricePerDay: Double
    let isAvailable: Bool
}

@MainActor
final class SupabaseDataStore: ObservableObject {
    @Published var listings: [PlantListing] = []
    @Published var caregivers: [Caregiver] = []
    @Published var errorMessage: String?

    func loadListings() async {
        do {
            let response = try await supabase.database
                .from("plant_listings")
                .select()
                .execute()

            let decoder = JSONDecoder()

            let dbListings: [DBPlantListing] = try decodeArray(from: response.data, decoder: decoder)

            let profileResponse = try await supabase.database
                .from("profiles")
                .select("id, full_name")
                .execute()
            let dbProfiles: [DBListingProfile] = try decodeArray(from: profileResponse.data, decoder: decoder)
            let nameByID = Dictionary(uniqueKeysWithValues: dbProfiles.map { ($0.id, $0.fullName ?? "Seller") })

            let mapped = dbListings.map { row in
                PlantListing(
                    id: row.id,
                    name: row.title,
                    species: row.species,
                    price: row.price,
                    category: PlantCategory(rawValue: row.category) ?? .indoor,
                    condition: PlantCondition(rawValue: row.condition) ?? .good,
                    sellerName: nameByID[row.sellerId] ?? "Seller",
                    location: row.city ?? "Unknown",
                    description: row.description ?? "",
                    iconName: Self.iconName(for: row.category),
                    iconColor: Self.iconColor(for: row.category),
                    postedDaysAgo: Self.daysAgo(from: row.createdAt),
                    status: row.status
                )
            }

            self.listings = mapped.isEmpty ? PlantListing.samples : mapped
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            if listings.isEmpty { listings = PlantListing.samples }
        }
    }

    func addListing(_ input: NewListingInput, session: Session?) async throws {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        let payload = DBPlantListingInsert(
            sellerID: userID,
            title: input.name,
            species: input.species,
            price: input.price,
            category: input.category.rawValue,
            condition: input.condition.rawValue,
            description: input.description,
            city: input.city,
            status: "active"
        )

        _ = try await supabase.database
            .from("plant_listings")
            .insert(payload)
            .execute()

        await loadListings()
    }

    func loadMyListings(session: Session?) async throws -> [PlantListing] {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        let response = try await supabase.database
            .from("plant_listings")
            .select()
            .eq("seller_id", value: userID.uuidString)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        let rows: [DBPlantListing] = try decodeArray(from: response.data, decoder: decoder)

        return rows.map { row in
            PlantListing(
                id: row.id,
                name: row.title,
                species: row.species,
                price: row.price,
                category: PlantCategory(rawValue: row.category) ?? .indoor,
                condition: PlantCondition(rawValue: row.condition) ?? .good,
                sellerName: "You",
                location: row.city ?? "Unknown",
                description: row.description ?? "",
                iconName: Self.iconName(for: row.category),
                iconColor: Self.iconColor(for: row.category),
                postedDaysAgo: Self.daysAgo(from: row.createdAt),
                status: row.status
            )
        }
    }

    func updateListingStatus(listingID: UUID, status: String, session: Session?) async throws {
        guard session != nil else { throw DataStoreError.notAuthenticated }

        let payload = DBListingStatusUpdate(status: status)

        _ = try await supabase.database
            .from("plant_listings")
            .update(payload)
            .eq("id", value: listingID.uuidString)
            .execute()
    }

    func deleteListing(listingID: UUID, session: Session?) async throws {
        guard session != nil else { throw DataStoreError.notAuthenticated }

        _ = try await supabase.database
            .from("plant_listings")
            .delete()
            .eq("id", value: listingID.uuidString)
            .execute()
    }

    func loadCaregivers() async {
        do {
            let response = try await supabase.database
                .from("caregivers")
                .select()
                .execute()

            let decoder = JSONDecoder()

            let dbCaregivers: [DBCaregiver] = try decodeArray(from: response.data, decoder: decoder)

            let profileResponse = try await supabase.database
                .from("profiles")
                .select("id, full_name, city")
                .execute()
            let dbProfiles: [DBCaregiverProfile] = try decodeArray(from: profileResponse.data, decoder: decoder)
            let profileByID = Dictionary(uniqueKeysWithValues: dbProfiles.map { ($0.id, $0) })

            let mapped = dbCaregivers.map { row in
                let profile = profileByID[row.id]
                return Caregiver(
                    id: row.id,
                    name: profile?.fullName?.isEmpty == false ? profile!.fullName! : "Caregiver",
                    bio: row.bio ?? "",
                    rating: row.rating,
                    reviewCount: row.reviewCount,
                    pricePerDay: row.pricePerDay,
                    specialties: row.specialties,
                    location: row.location ?? profile?.city ?? "Unknown",
                    yearsExperience: row.yearsExperience,
                    avatarColor: .green,
                    isAvailable: row.isAvailable
                )
            }

            self.caregivers = mapped.isEmpty ? Caregiver.samples : mapped
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            if caregivers.isEmpty { caregivers = Caregiver.samples }
        }
    }

    func registerCaregiver(_ input: NewCaregiverInput, session: Session?) async throws {
        let activeSession: Session
        if let session {
            activeSession = session
        } else {
            do {
                activeSession = try await supabase.auth.session
            } catch {
                throw DataStoreError.notAuthenticated
            }
        }

        let userID = activeSession.user.id

        guard activeSession.user.email != nil || !input.fullName.isEmpty else {
            throw DataStoreError.notAuthenticated
        }

        // Ensure a profile row exists for this user (important for FK: caregivers.id -> profiles.id).
        let profileUpsert = DBProfileUpsert(
            id: userID,
            email: activeSession.user.email,
            fullName: input.fullName,
            city: input.location,
            isCaregiver: true
        )

        _ = try await supabase.database
            .from("profiles")
            .upsert(profileUpsert)
            .execute()

        let profileUpdate = DBProfileUpdate(
            fullName: input.fullName,
            city: input.location,
            isCaregiver: true
        )

        _ = try await supabase.database
            .from("profiles")
            .update(profileUpdate)
            .eq("id", value: userID.uuidString)
            .execute()

        let caregiverUpsert = DBCaregiverUpsert(
            id: userID,
            bio: input.bio,
            pricePerDay: input.pricePerDay,
            yearsExperience: input.yearsExperience,
            location: input.location,
            specialties: input.specialties,
            isAvailable: input.isAvailable,
            rating: 0,
            reviewCount: 0
        )

        // Some projects enforce policies that make upsert brittle.
        // Upsert by primary key id, then verify to avoid silent no-op writes.
        _ = try await supabase.database
            .from("caregivers")
            .upsert(caregiverUpsert)
            .execute()

        let verifyResponse = try await supabase.database
            .from("caregivers")
            .select("id")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()

        let decoder = JSONDecoder()
        let savedRows: [DBIdOnly] = try decodeArray(from: verifyResponse.data, decoder: decoder)
        guard !savedRows.isEmpty else {
            throw DataStoreError.caregiverSaveFailed
        }

        await loadCaregivers()
    }

    private static func iconName(for category: String) -> String {
        switch category {
        case PlantCategory.indoor.rawValue: return "leaf.fill"
        case PlantCategory.outdoor.rawValue: return "sun.max.fill"
        case PlantCategory.succulents.rawValue: return "circle.hexagongrid.fill"
        case PlantCategory.tropical.rawValue: return "bird.fill"
        case PlantCategory.herbs.rawValue: return "cup.and.saucer.fill"
        default: return "leaf.fill"
        }
    }

    private static func iconColor(for category: String) -> Color {
        switch category {
        case PlantCategory.indoor.rawValue: return .green
        case PlantCategory.outdoor.rawValue: return .orange
        case PlantCategory.succulents.rawValue: return .mint
        case PlantCategory.tropical.rawValue: return .pink
        case PlantCategory.herbs.rawValue: return .teal
        default: return .green
        }
    }

    private static func daysAgo(from rawDate: String?) -> Int {
        guard let rawDate else { return 1 }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let parsedDate = formatter.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate)
        guard let date = parsedDate else { return 1 }

        let diff = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return max(1, diff)
    }

    private func decodeArray<T: Decodable>(from data: Data, decoder: JSONDecoder) throws -> [T] {
        // Some responses may return an empty body. Treat it as no rows instead of throwing.
        guard !data.isEmpty else { return [] }

        // Defensive check for whitespace-only bodies.
        if let text = String(data: data, encoding: .utf8), text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        return try decoder.decode([T].self, from: data)
    }
}

enum DataStoreError: LocalizedError {
    case notAuthenticated
    case caregiverSaveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in first."
        case .caregiverSaveFailed:
            return "Could not save sitter profile. Please check your Supabase RLS policies and try again."
        }
    }
}

private struct DBIdOnly: Decodable {
    let id: UUID
}

private struct DBPlantListing: Decodable {
    let id: UUID
    let sellerId: UUID
    let title: String
    let species: String
    let price: Double
    let category: String
    let condition: String
    let description: String?
    let city: String?
    let createdAt: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case title
        case species
        case price
        case category
        case condition
        case description
        case city
        case createdAt = "created_at"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sellerId = try container.decode(UUID.self, forKey: .sellerId)
        title = try container.decode(String.self, forKey: .title)
        species = try container.decode(String.self, forKey: .species)
        price = try container.decodeLossyDouble(forKey: .price)
        category = try container.decode(String.self, forKey: .category)
        condition = try container.decode(String.self, forKey: .condition)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
    }
}

private struct DBPlantListingInsert: Encodable {
    let sellerID: UUID
    let title: String
    let species: String
    let price: Double
    let category: String
    let condition: String
    let description: String
    let city: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case sellerID = "seller_id"
        case title
        case species
        case price
        case category
        case condition
        case description
        case city
        case status
    }
}

private struct DBListingStatusUpdate: Encodable {
    let status: String
}

private struct DBListingProfile: Decodable {
    let id: UUID
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
    }
}

private struct DBCaregiver: Decodable {
    let id: UUID
    let bio: String?
    let pricePerDay: Double
    let yearsExperience: Int
    let location: String?
    let specialties: [String]
    let isAvailable: Bool
    let rating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case bio
        case pricePerDay = "price_per_day"
        case yearsExperience = "years_experience"
        case location
        case specialties
        case isAvailable = "is_available"
        case rating
        case reviewCount = "review_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        pricePerDay = try container.decodeLossyDouble(forKey: .pricePerDay)
        yearsExperience = try container.decodeLossyInt(forKey: .yearsExperience)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        specialties = try container.decodeIfPresent([String].self, forKey: .specialties) ?? []
        isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
        rating = try container.decodeLossyDouble(forKey: .rating)
        reviewCount = try container.decodeLossyInt(forKey: .reviewCount)
    }
}

private struct DBProfileUpdate: Encodable {
    let fullName: String
    let city: String
    let isCaregiver: Bool

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case city
        case isCaregiver = "is_caregiver"
    }
}

private struct DBProfileUpsert: Encodable {
    let id: UUID
    let email: String?
    let fullName: String
    let city: String
    let isCaregiver: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case city
        case isCaregiver = "is_caregiver"
    }
}

private struct DBCaregiverUpsert: Encodable {
    let id: UUID
    let bio: String
    let pricePerDay: Double
    let yearsExperience: Int
    let location: String
    let specialties: [String]
    let isAvailable: Bool
    let rating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case bio
        case pricePerDay = "price_per_day"
        case yearsExperience = "years_experience"
        case location
        case specialties
        case isAvailable = "is_available"
        case rating
        case reviewCount = "review_count"
    }
}

private struct DBCaregiverProfile: Decodable {
    let id: UUID
    let fullName: String?
    let city: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case city
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key), let parsed = Double(value) { return parsed }
        return 0
    }

    func decodeLossyInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key), let parsed = Int(value) { return parsed }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        return 0
    }
}
