//
//  SupabaseDataStore.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import Supabase
import UIKit

struct NewListingInput {
    let name: String
    let species: String
    let price: Double
    let category: PlantCategory
    let condition: PlantCondition
    let city: String
    let phoneNumber: String
    let description: String
    let imageData: [Data]
}

struct UpdateListingInput {
    let name: String
    let species: String
    let price: Double
    let category: PlantCategory
    let condition: PlantCondition
    let city: String
    let phoneNumber: String
    let description: String
    let existingImageURLs: [String]
    let newImageData: [Data]
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

struct NewBookingInput {
    let caregiverID: UUID
    let plantName: String
    let notes: String
    let startDate: Date
    let endDate: Date
    let totalPrice: Double
}

struct NewReviewInput {
    let bookingID: UUID
    let caregiverID: UUID
    let rating: Int
    let comment: String
}

@MainActor
final class SupabaseDataStore: ObservableObject {
    @Published var listings: [PlantListing] = []
    @Published var caregivers: [Caregiver] = []
    @Published var careTips: [PlantCareTip] = PlantCareTip.samples
    @Published var errorMessage: String?

    // NOTE: Move this key to secure config before production release.
    private let perenualAPIKey = "sk-EVKQ69e7269a2887e16618"

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
                    sellerID: row.sellerId,
                    name: row.title,
                    species: row.species,
                    price: row.price,
                    category: PlantCategory(rawValue: row.category) ?? .indoor,
                    condition: PlantCondition(rawValue: row.condition) ?? .good,
                    sellerName: nameByID[row.sellerId] ?? "Seller",
                    location: row.city ?? "Unknown",
                    description: row.description ?? "",
                    phoneNumber: row.phoneNumber,
                    imageURLs: row.resolvedImageURLs,
                    iconName: Self.iconName(for: row.category),
                    iconColor: Self.iconColor(for: row.category),
                    createdAt: Self.parseTimestamp(row.createdAt),
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

        let imageURLs = try await uploadListingImages(input.imageData, userID: userID)

        let payload = DBPlantListingInsert(
            sellerID: userID,
            title: input.name,
            species: input.species,
            price: input.price,
            category: input.category.rawValue,
            condition: input.condition.rawValue,
            description: input.description,
            city: input.city,
            phoneNumber: input.phoneNumber,
            imageURL: imageURLs.first,
            imageURLs: imageURLs,
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
                sellerID: row.sellerId,
                name: row.title,
                species: row.species,
                price: row.price,
                category: PlantCategory(rawValue: row.category) ?? .indoor,
                condition: PlantCondition(rawValue: row.condition) ?? .good,
                sellerName: "You",
                location: row.city ?? "Unknown",
                description: row.description ?? "",
                phoneNumber: row.phoneNumber,
                imageURLs: row.resolvedImageURLs,
                iconName: Self.iconName(for: row.category),
                iconColor: Self.iconColor(for: row.category),
                createdAt: Self.parseTimestamp(row.createdAt),
                postedDaysAgo: Self.daysAgo(from: row.createdAt),
                status: row.status
            )
        }
    }

    func updateListing(listingID: UUID, input: UpdateListingInput, session: Session?) async throws {
        guard let userID = session?.user.id else { throw DataStoreError.notAuthenticated }

        let uploadedImageURLs = try await uploadListingImages(input.newImageData, userID: userID)
        let imageURLs = Array((input.existingImageURLs + uploadedImageURLs).prefix(5))

        let payload = DBListingEditUpdate(
            title: input.name,
            species: input.species,
            price: input.price,
            category: input.category.rawValue,
            condition: input.condition.rawValue,
            city: input.city,
            phoneNumber: input.phoneNumber,
            description: input.description,
            imageURL: imageURLs.first ?? "",
            imageURLs: imageURLs
        )

        _ = try await supabase.database
            .from("plant_listings")
            .update(payload)
            .eq("id", value: listingID.uuidString)
            .execute()
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
                .select("id, full_name, city, is_caregiver")
                .execute()
            let dbProfiles: [DBCaregiverProfile] = try decodeArray(from: profileResponse.data, decoder: decoder)
            let profileByID = Dictionary(uniqueKeysWithValues: dbProfiles.map { ($0.id, $0) })

            let mapped: [Caregiver] = dbCaregivers.compactMap { row in
                let profile = profileByID[row.id]
                guard profile?.isCaregiver ?? true else { return nil }
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

    func loadCurrentUserCity(session: Session?) async throws -> String? {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        let response = try await supabase.database
            .from("profiles")
            .select("city")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()

        let decoder = JSONDecoder()
        let rows: [DBProfileCity] = try decodeArray(from: response.data, decoder: decoder)
        return rows.first?.city?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadCurrentUserProfile(session: Session?) async throws -> (fullName: String?, city: String?, isCaregiver: Bool?)? {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        let response = try await supabase.database
            .from("profiles")
            .select("id, full_name, city, is_caregiver")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()

        let decoder = JSONDecoder()
        let rows: [DBCaregiverProfile] = try decodeArray(from: response.data, decoder: decoder)
        guard let row = rows.first else { return nil }
        return (row.fullName, row.city, row.isCaregiver)
    }

    func loadCareTips() async {
        // Prefer Perenual free API tips first.
        if let perenualTips = try? await loadCareTipsFromPerenualAPI(), !perenualTips.isEmpty {
            self.careTips = perenualTips
            self.errorMessage = nil
            return
        }

        // Prefer free public API tips first so this feature works without Supabase data seeding.
        if let apiTips = try? await loadCareTipsFromFreeAPI(), !apiTips.isEmpty {
            self.careTips = apiTips
            self.errorMessage = nil
            return
        }

        do {
            let response = try await supabase.database
                .from("plant_care_tips")
                .select()
                .eq("published", value: true)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            let rows: [DBPlantCareTip] = try decodeArray(from: response.data, decoder: decoder)

            let mapped = rows.map { row in
                PlantCareTip(
                    id: row.id,
                    title: row.title,
                    summary: row.summary,
                    content: row.content,
                    category: TipCategory(rawValue: row.category) ?? .general,
                    difficulty: TipDifficulty(rawValue: row.difficulty) ?? .beginner,
                    readMinutes: max(1, row.readMinutes)
                )
            }

            self.careTips = mapped.isEmpty ? PlantCareTip.samples : mapped
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Could not fetch online care tips. Showing built-in tips instead."
            if careTips.isEmpty { careTips = PlantCareTip.samples }
        }
    }

    private func loadCareTipsFromPerenualAPI() async throws -> [PlantCareTip] {
        guard !perenualAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: "https://perenual.com/api/species-care-guide-list?key=\(perenualAPIKey)&page=1")
        else {
            return []
        }

        let data = try await fetchData(from: url, timeout: 8)
        let response = try JSONDecoder().decode(PerenualCareGuideResponse.self, from: data)

        var tips: [PlantCareTip] = []

        for item in response.data.prefix(10) {
            for section in item.section {
                let cleaned = cleanWikipediaText(section.description)
                guard !cleaned.isEmpty else { continue }

                let category = mapPerenualTypeToTipCategory(section.type)
                let title = "\(item.commonName) • \(section.type.capitalized)"
                let summary = String(cleaned.prefix(120))
                let readMinutes = max(1, min(8, cleaned.count / 220))

                tips.append(
                    PlantCareTip(
                        id: UUID(),
                        title: title,
                        summary: summary,
                        content: cleaned,
                        category: category,
                        difficulty: .beginner,
                        readMinutes: readMinutes
                    )
                )
            }
        }

        return Array(tips.prefix(20))
    }

    private func mapPerenualTypeToTipCategory(_ rawType: String) -> TipCategory {
        let type = rawType.lowercased()
        if type.contains("water") { return .watering }
        if type.contains("sun") || type.contains("light") { return .sunlight }
        if type.contains("fertil") || type.contains("feed") { return .fertilizing }
        if type.contains("pot") || type.contains("soil") || type.contains("repot") { return .repotting }
        if type.contains("pest") || type.contains("disease") || type.contains("bug") { return .pests }
        return .general
    }

    private func loadCareTipsFromFreeAPI() async throws -> [PlantCareTip] {
        let topics: [(title: String, category: TipCategory)] = [
            ("Houseplant", .general),
            ("Irrigation", .watering),
            ("Sunlight", .sunlight),
            ("Fertilizer", .fertilizing),
            ("Potting soil", .repotting),
            ("Pest (organism)", .pests)
        ]

        var tips: [PlantCareTip] = []

        for topic in topics {
            guard let encodedTitle = topic.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let summaryURL = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)")
            else {
                continue
            }

            do {
                let summaryData = try await fetchData(from: summaryURL, timeout: 6)
                let summary = try JSONDecoder().decode(WikipediaSummaryResponse.self, from: summaryData)
                let cleanedSummary = cleanWikipediaText(summary.extract ?? summary.description ?? "")
                guard !cleanedSummary.isEmpty else { continue }

                let readMinutes = max(1, min(8, cleanedSummary.count / 220))
                tips.append(
                    PlantCareTip(
                        id: UUID(),
                        title: (summary.title?.isEmpty == false ? summary.title! : topic.title),
                        summary: String(cleanedSummary.prefix(120)),
                        content: cleanedSummary,
                        category: topic.category,
                        difficulty: .beginner,
                        readMinutes: readMinutes
                    )
                )
            } catch {
                // Skip one article and continue building the rest.
                continue
            }

            if tips.count >= 5 { break }
        }

        // Remove accidental duplicate titles and keep stable order.
        var seen = Set<String>()
        let unique = tips.filter { tip in
            let key = tip.title.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        return unique
    }

    private func fetchData(from url: URL, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return data
    }

    private func cleanWikipediaText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

        let decoder = JSONDecoder()
        let existingCaregiverResponse = try await supabase.database
            .from("caregivers")
            .select("id")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
        let existingCaregivers: [DBIdOnly] = try decodeArray(from: existingCaregiverResponse.data, decoder: decoder)

        if existingCaregivers.isEmpty {
            let caregiverInsert = DBCaregiverInsert(
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

            _ = try await supabase.database
                .from("caregivers")
                .insert(caregiverInsert)
                .execute()
        } else {
            let caregiverUpdate = DBCaregiverUpdate(
                bio: input.bio,
                pricePerDay: input.pricePerDay,
                yearsExperience: input.yearsExperience,
                location: input.location,
                specialties: input.specialties,
                isAvailable: input.isAvailable
            )

            _ = try await supabase.database
                .from("caregivers")
                .update(caregiverUpdate)
                .eq("id", value: userID.uuidString)
                .execute()
        }

        let verifyResponse = try await supabase.database
            .from("caregivers")
            .select("id")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()

        let savedRows: [DBIdOnly] = try decodeArray(from: verifyResponse.data, decoder: decoder)
        guard !savedRows.isEmpty else {
            throw DataStoreError.caregiverSaveFailed
        }

        await loadCaregivers()
    }

    func createBooking(_ input: NewBookingInput, session: Session?) async throws {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        guard input.caregiverID != userID else {
            throw DataStoreError.invalidBooking("You cannot book yourself as a sitter.")
        }

        let trimmedPlantName = input.plantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlantName.isEmpty else {
            throw DataStoreError.invalidBooking("Please enter your plant name.")
        }

        guard input.endDate >= input.startDate else {
            throw DataStoreError.invalidBooking("Pick-up date must be on or after the drop-off date.")
        }

        let payload = DBPlantSittingBookingInsert(
            ownerID: userID,
            caregiverID: input.caregiverID,
            plantName: trimmedPlantName,
            notes: input.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: Self.dateOnlyFormatter.string(from: input.startDate),
            endDate: Self.dateOnlyFormatter.string(from: input.endDate),
            totalPrice: input.totalPrice,
            status: BookingStatus.pending.rawValue
        )

        _ = try await supabase.database
            .from("plant_sitting_bookings")
            .insert(payload)
            .execute()
    }

    func loadMyBookings(session: Session?) async throws -> [PlantSittingBooking] {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        let decoder = JSONDecoder()

        let ownerResponse = try await supabase.database
            .from("plant_sitting_bookings")
            .select()
            .eq("owner_id", value: userID.uuidString)
            .order("start_date", ascending: false)
            .execute()

        let caregiverResponse = try await supabase.database
            .from("plant_sitting_bookings")
            .select()
            .eq("caregiver_id", value: userID.uuidString)
            .order("start_date", ascending: false)
            .execute()

        let ownerRows: [DBPlantSittingBooking] = try decodeArray(from: ownerResponse.data, decoder: decoder)
        let caregiverRows: [DBPlantSittingBooking] = try decodeArray(from: caregiverResponse.data, decoder: decoder)
        let bookingRows = uniqueBookings(from: ownerRows + caregiverRows)

        let profileResponse = try await supabase.database
            .from("profiles")
            .select("id, full_name, city, is_caregiver")
            .execute()
        let profileRows: [DBCaregiverProfile] = try decodeArray(from: profileResponse.data, decoder: decoder)
        let profileByID = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })

        return bookingRows.map { row in
            PlantSittingBooking(
                id: row.id,
                ownerID: row.ownerID,
                caregiverID: row.caregiverID,
                ownerName: profileByID[row.ownerID]?.fullName?.isEmpty == false ? profileByID[row.ownerID]!.fullName! : "Owner",
                caregiverName: profileByID[row.caregiverID]?.fullName?.isEmpty == false ? profileByID[row.caregiverID]!.fullName! : "Caregiver",
                plantName: row.plantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                notes: row.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                startDate: Self.parseDateOnly(row.startDate),
                endDate: Self.parseDateOnly(row.endDate),
                totalPrice: row.totalPrice,
                status: BookingStatus(rawValue: row.status.lowercased()) ?? .pending,
                createdAt: Self.parseTimestamp(row.createdAt)
            )
        }
        .sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return (lhs.createdAt ?? lhs.startDate) > (rhs.createdAt ?? rhs.startDate)
            }
            return lhs.startDate > rhs.startDate
        }
    }

    func updateBookingStatus(bookingID: UUID, status: BookingStatus, session: Session?) async throws {
        guard session != nil else {
            throw DataStoreError.notAuthenticated
        }

        let payload = DBBookingStatusUpdate(status: status.rawValue)

        _ = try await supabase.database
            .from("plant_sitting_bookings")
            .update(payload)
            .eq("id", value: bookingID.uuidString)
            .execute()
    }

    func loadReviewCenter(session: Session?) async throws -> ReviewCenterData {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        do {
            let decoder = JSONDecoder()

            let givenResponse = try await supabase.database
                .from("caregiver_reviews")
                .select()
                .eq("reviewer_id", value: userID.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let receivedResponse = try await supabase.database
                .from("caregiver_reviews")
                .select()
                .eq("caregiver_id", value: userID.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let givenRows: [DBCaregiverReviewEntry] = try decodeArray(from: givenResponse.data, decoder: decoder)
            let receivedRows: [DBCaregiverReviewEntry] = try decodeArray(from: receivedResponse.data, decoder: decoder)

            let ownerBookingResponse = try await supabase.database
                .from("plant_sitting_bookings")
                .select()
                .eq("owner_id", value: userID.uuidString)
                .order("start_date", ascending: false)
                .execute()

            let caregiverBookingResponse = try await supabase.database
                .from("plant_sitting_bookings")
                .select()
                .eq("caregiver_id", value: userID.uuidString)
                .order("start_date", ascending: false)
                .execute()

            let ownerBookingRows: [DBPlantSittingBooking] = try decodeArray(from: ownerBookingResponse.data, decoder: decoder)
            let caregiverBookingRows: [DBPlantSittingBooking] = try decodeArray(from: caregiverBookingResponse.data, decoder: decoder)
            let bookingRows = uniqueBookings(from: ownerBookingRows + caregiverBookingRows)
            let bookingNameByID = Dictionary(uniqueKeysWithValues: bookingRows.map {
                ($0.id, $0.plantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            })

            let profileResponse = try await supabase.database
                .from("profiles")
                .select("id, full_name, city, is_caregiver")
                .execute()
            let profileRows: [DBCaregiverProfile] = try decodeArray(from: profileResponse.data, decoder: decoder)
            let profileByID = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })

            let summaryResponse = try await supabase.database
                .from("caregivers")
                .select("rating, review_count")
                .eq("id", value: userID.uuidString)
                .limit(1)
                .execute()
            let summaryRows: [DBCaregiverSummary] = try decodeArray(from: summaryResponse.data, decoder: decoder)

            let givenReviewBookingIDs = Set(givenRows.map(\.bookingID))
            let pending = ownerBookingRows
                .filter { $0.status.lowercased() == BookingStatus.completed.rawValue && !givenReviewBookingIDs.contains($0.id) }
                .map { row in
                    PlantSittingBooking(
                        id: row.id,
                        ownerID: row.ownerID,
                        caregiverID: row.caregiverID,
                        ownerName: profileByID[row.ownerID]?.fullName?.isEmpty == false ? profileByID[row.ownerID]!.fullName! : "Owner",
                        caregiverName: profileByID[row.caregiverID]?.fullName?.isEmpty == false ? profileByID[row.caregiverID]!.fullName! : "Caregiver",
                        plantName: row.plantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        notes: row.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        startDate: Self.parseDateOnly(row.startDate),
                        endDate: Self.parseDateOnly(row.endDate),
                        totalPrice: row.totalPrice,
                        status: .completed,
                        createdAt: Self.parseTimestamp(row.createdAt)
                    )
                }

            let given = givenRows.map { row in
                CaregiverReviewEntry(
                    id: row.id,
                    bookingID: row.bookingID,
                    caregiverID: row.caregiverID,
                    reviewerID: row.reviewerID,
                    caregiverName: profileByID[row.caregiverID]?.fullName?.isEmpty == false ? profileByID[row.caregiverID]!.fullName! : "Caregiver",
                    reviewerName: profileByID[row.reviewerID]?.fullName?.isEmpty == false ? profileByID[row.reviewerID]!.fullName! : "You",
                    plantName: bookingNameByID[row.bookingID] ?? row.plantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    rating: row.rating,
                    comment: row.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    createdAt: Self.parseTimestamp(row.createdAt)
                )
            }

            let received = receivedRows.map { row in
                CaregiverReviewEntry(
                    id: row.id,
                    bookingID: row.bookingID,
                    caregiverID: row.caregiverID,
                    reviewerID: row.reviewerID,
                    caregiverName: profileByID[row.caregiverID]?.fullName?.isEmpty == false ? profileByID[row.caregiverID]!.fullName! : "You",
                    reviewerName: profileByID[row.reviewerID]?.fullName?.isEmpty == false ? profileByID[row.reviewerID]!.fullName! : "Plant owner",
                    plantName: bookingNameByID[row.bookingID] ?? row.plantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    rating: row.rating,
                    comment: row.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    createdAt: Self.parseTimestamp(row.createdAt)
                )
            }

            let summary = summaryRows.first
            return ReviewCenterData(
                receivedSummaryRating: summary?.rating ?? 0,
                receivedSummaryCount: summary?.reviewCount ?? received.count,
                pending: pending,
                received: received,
                given: given
            )
        } catch {
            throw mapReviewFeatureError(error)
        }
    }

    func submitReview(_ input: NewReviewInput, session: Session?) async throws {
        guard let userID = session?.user.id else {
            throw DataStoreError.notAuthenticated
        }

        guard (1...5).contains(input.rating) else {
            throw DataStoreError.invalidReview("Please choose a rating between 1 and 5 stars.")
        }

        do {
            let decoder = JSONDecoder()
            let existingResponse = try await supabase.database
                .from("caregiver_reviews")
                .select("id")
                .eq("booking_id", value: input.bookingID.uuidString)
                .eq("reviewer_id", value: userID.uuidString)
                .limit(1)
                .execute()
            let existingRows: [DBIdOnly] = try decodeArray(from: existingResponse.data, decoder: decoder)

            if let existingReview = existingRows.first {
                // Reuse the saved review row so editing a rating updates persisted data instead of failing on the unique booking constraint.
                let payload = DBCaregiverReviewUpdate(
                    rating: Double(input.rating),
                    comment: input.comment.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                _ = try await supabase.database
                    .from("caregiver_reviews")
                    .update(payload)
                    .eq("id", value: existingReview.id.uuidString)
                    .execute()
            } else {
                let payload = DBCaregiverReviewInsert(
                    bookingID: input.bookingID,
                    caregiverID: input.caregiverID,
                    reviewerID: userID,
                    rating: Double(input.rating),
                    comment: input.comment.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                _ = try await supabase.database
                    .from("caregiver_reviews")
                    .insert(payload)
                    .execute()
            }
        } catch {
            throw mapReviewFeatureError(error)
        }
    }

    nonisolated private func uploadListingImages(_ images: [Data], userID: UUID) async throws -> [String] {
        guard !images.isEmpty else { return [] }

        var urls: [String] = []
        for (index, imageData) in images.prefix(5).enumerated() {
            let compressedData = Self.compressedJPEGData(from: imageData)
            let fileName = "listing-\(Int(Date().timeIntervalSince1970))-\(index)-\(UUID().uuidString).jpg"
            let path = "\(userID.uuidString)/\(fileName)"

            _ = try await supabase.storage
                .from("listing-images")
                .upload(
                    path: path,
                    file: compressedData
                )

            let publicURL = try supabase.storage
                .from("listing-images")
                .getPublicURL(path: path)

            urls.append(publicURL.absoluteString)
        }

        return urls
    }

    nonisolated private static func compressedJPEGData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.82)
        else {
            return data
        }
        return jpeg
    }

    private static func iconName(for category: String) -> String {
        switch category {
        case PlantCategory.indoor.rawValue: return "leaf.fill"
        case PlantCategory.outdoor.rawValue: return "sun.max.fill"
        case "Succulents": return "circle.hexagongrid.fill"
        case PlantCategory.tropical.rawValue: return "bird.fill"
        case PlantCategory.herbs.rawValue: return "cup.and.saucer.fill"
        default: return "leaf.fill"
        }
    }

    private static func iconColor(for category: String) -> Color {
        switch category {
        case PlantCategory.indoor.rawValue: return .green
        case PlantCategory.outdoor.rawValue: return .orange
        case "Succulents": return .mint
        case PlantCategory.tropical.rawValue: return .pink
        case PlantCategory.herbs.rawValue: return .teal
        default: return .green
        }
    }

    private static func daysAgo(from rawDate: String?) -> Int {
        guard let date = parseServerTimestamp(rawDate) else { return 1 }

        let calendar = Calendar.current
        let startOfListingDay = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: Date())
        let diff = calendar.dateComponents([.day], from: startOfListingDay, to: startOfToday).day ?? 0
        return max(0, diff)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func parseDateOnly(_ value: String) -> Date {
        Self.dateOnlyFormatter.date(from: value) ?? Date()
    }

    private static func parseTimestamp(_ value: String?) -> Date? {
        parseServerTimestamp(value)
    }

    private static func parseServerTimestamp(_ value: String?) -> Date? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractional.date(from: raw) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // PostgREST / PostgreSQL timestamp formats commonly seen in responses.
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }

        return nil
    }

    private func uniqueBookings(from rows: [DBPlantSittingBooking]) -> [DBPlantSittingBooking] {
        Array(Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) }).values)
    }

    private func mapReviewFeatureError(_ error: Error) -> Error {
        let message = error.localizedDescription.lowercased()
        if message.contains("caregiver_reviews") || message.contains("relation") {
            return DataStoreError.reviewFeatureRequiresMigration
        }
        return error
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
    case invalidBooking(String)
    case invalidReview(String)
    case reviewFeatureRequiresMigration

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in first."
        case .caregiverSaveFailed:
            return "Could not save sitter profile. Please check your Supabase RLS policies and try again."
        case .invalidBooking(let message):
            return message
        case .invalidReview(let message):
            return message
        case .reviewFeatureRequiresMigration:
            return "The reviews feature needs the new Supabase migration before it can be used."
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
    let phoneNumber: String?
    let imageURL: String?
    let imageURLs: [String]
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
        case phoneNumber = "phone_number"
        case imageURL = "image_url"
        case imageURLs = "image_urls"
        case createdAt = "created_at"
        case status
    }

    var resolvedImageURLs: [String] {
        if !imageURLs.isEmpty { return imageURLs }
        if let imageURL, !imageURL.isEmpty { return [imageURL] }
        return []
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
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs) ?? []
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
    let phoneNumber: String
    let imageURL: String?
    let imageURLs: [String]
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
        case phoneNumber = "phone_number"
        case imageURL = "image_url"
        case imageURLs = "image_urls"
        case status
    }
}

private struct DBListingEditUpdate: Encodable {
    let title: String
    let species: String
    let price: Double
    let category: String
    let condition: String
    let city: String
    let phoneNumber: String
    let description: String
    let imageURL: String?
    let imageURLs: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case species
        case price
        case category
        case condition
        case city
        case phoneNumber = "phone_number"
        case description
        case imageURL = "image_url"
        case imageURLs = "image_urls"
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

private struct DBProfileCity: Decodable {
    let city: String?
}

private struct DBPlantCareTip: Decodable {
    let id: UUID
    let title: String
    let summary: String
    let content: String
    let category: String
    let difficulty: String
    let readMinutes: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case content
        case category
        case difficulty
        case readMinutes = "read_minutes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        readMinutes = try container.decodeLossyInt(forKey: .readMinutes)
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

private struct DBCaregiverInsert: Encodable {
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

private struct DBCaregiverUpdate: Encodable {
    let bio: String
    let pricePerDay: Double
    let yearsExperience: Int
    let location: String
    let specialties: [String]
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case bio
        case pricePerDay = "price_per_day"
        case yearsExperience = "years_experience"
        case location
        case specialties
        case isAvailable = "is_available"
    }
}

private struct DBCaregiverProfile: Decodable {
    let id: UUID
    let fullName: String?
    let city: String?
    let isCaregiver: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case city
        case isCaregiver = "is_caregiver"
    }
}

private struct DBPlantSittingBookingInsert: Encodable {
    let ownerID: UUID
    let caregiverID: UUID
    let plantName: String
    let notes: String
    let startDate: String
    let endDate: String
    let totalPrice: Double
    let status: String

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case caregiverID = "caregiver_id"
        case plantName = "plant_name"
        case notes
        case startDate = "start_date"
        case endDate = "end_date"
        case totalPrice = "total_price"
        case status
    }
}

private struct DBPlantSittingBooking: Decodable {
    let id: UUID
    let ownerID: UUID
    let caregiverID: UUID
    let plantName: String?
    let notes: String?
    let startDate: String
    let endDate: String
    let totalPrice: Double
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case caregiverID = "caregiver_id"
        case plantName = "plant_name"
        case notes
        case startDate = "start_date"
        case endDate = "end_date"
        case totalPrice = "total_price"
        case status
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerID = try container.decode(UUID.self, forKey: .ownerID)
        caregiverID = try container.decode(UUID.self, forKey: .caregiverID)
        plantName = try container.decodeIfPresent(String.self, forKey: .plantName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decode(String.self, forKey: .endDate)
        totalPrice = try container.decodeLossyDouble(forKey: .totalPrice)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? BookingStatus.pending.rawValue
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

private struct DBBookingStatusUpdate: Encodable {
    let status: String
}

private struct DBCaregiverSummary: Decodable {
    let rating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case rating
        case reviewCount = "review_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rating = try container.decodeLossyDouble(forKey: .rating)
        reviewCount = try container.decodeLossyInt(forKey: .reviewCount)
    }
}

private struct DBCaregiverReviewInsert: Encodable {
    let bookingID: UUID
    let caregiverID: UUID
    let reviewerID: UUID
    let rating: Double
    let comment: String

    enum CodingKeys: String, CodingKey {
        case bookingID = "booking_id"
        case caregiverID = "caregiver_id"
        case reviewerID = "reviewer_id"
        case rating
        case comment
    }
}

private struct DBCaregiverReviewUpdate: Encodable {
    let rating: Double
    let comment: String
}

private struct DBCaregiverReviewEntry: Decodable {
    let id: UUID
    let bookingID: UUID
    let caregiverID: UUID
    let reviewerID: UUID
    let plantName: String?
    let rating: Double
    let comment: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bookingID = "booking_id"
        case caregiverID = "caregiver_id"
        case reviewerID = "reviewer_id"
        case plantName = "plant_name"
        case rating
        case comment
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bookingID = try container.decode(UUID.self, forKey: .bookingID)
        caregiverID = try container.decode(UUID.self, forKey: .caregiverID)
        reviewerID = try container.decode(UUID.self, forKey: .reviewerID)
        plantName = try container.decodeIfPresent(String.self, forKey: .plantName)
        rating = try container.decodeLossyDouble(forKey: .rating)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

private struct WikipediaSearchResponse: Decodable {
    let query: WikipediaSearchQuery
}

private struct WikipediaSearchQuery: Decodable {
    let search: [WikipediaSearchItem]
}

private struct WikipediaSearchItem: Decodable {
    let title: String
}

private struct WikipediaSummaryResponse: Decodable {
    let title: String?
    let extract: String?
    let description: String?
}

private struct PerenualCareGuideResponse: Decodable {
    let data: [PerenualCareGuideItem]
}

private struct PerenualCareGuideItem: Decodable {
    let id: Int
    let commonName: String
    let section: [PerenualCareGuideSection]

    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case section
    }
}

private struct PerenualCareGuideSection: Decodable {
    let id: Int
    let type: String
    let description: String
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
