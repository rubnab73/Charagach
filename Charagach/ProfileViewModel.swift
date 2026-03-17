//
//  ProfileViewModel.swift
//  Charagach
//
//  Created by macOS on 3/18/26.
//

import Foundation
import Supabase

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var email: String = ""
    @Published var city: String = ""
    @Published var avatarURL: String = ""
    @Published var isCaregiver: Bool = false

    @Published var listingsCount: Int = 0
    @Published var bookingsCount: Int = 0
    @Published var reviewsCount: Int = 0

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load(session: Session?) async {
        guard let session else {
            errorMessage = "Please sign in first."
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let userID = session.user.id
            email = session.user.email ?? ""

            let decoder = JSONDecoder()

            let profileResponse = try await supabase.database
                .from("profiles")
                .select("id, email, full_name, city, avatar_url, is_caregiver")
                .eq("id", value: userID.uuidString)
                .limit(1)
                .execute()

            let profiles: [DBProfile] = try decodeArray(from: profileResponse.data, decoder: decoder)
            if let profile = profiles.first {
                fullName = profile.fullName ?? ""
                city = profile.city ?? ""
                avatarURL = profile.avatarURL ?? ""
                isCaregiver = profile.isCaregiver ?? false
                if email.isEmpty { email = profile.email ?? "" }
            } else {
                fullName = ""
                city = ""
                avatarURL = ""
                isCaregiver = false
            }

            let listingsResponse = try await supabase.database
                .from("plant_listings")
                .select("id", count: .exact)
                .eq("seller_id", value: userID.uuidString)
                .execute()
            listingsCount = listingsResponse.count ?? 0

            let bookingsResponse = try await supabase.database
                .from("plant_sitting_bookings")
                .select("id", count: .exact)
                .eq("owner_id", value: userID.uuidString)
                .execute()
            bookingsCount = bookingsResponse.count ?? 0

            let caregiversResponse = try await supabase.database
                .from("caregivers")
                .select("review_count")
                .eq("id", value: userID.uuidString)
                .limit(1)
                .execute()
            let caregiverRows: [DBCaregiverReview] = try decodeArray(from: caregiversResponse.data, decoder: decoder)
            reviewsCount = caregiverRows.first?.reviewCount ?? 0

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(session: Session?) async {
        guard let session else {
            errorMessage = "Please sign in first."
            return
        }

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "Please enter your full name."
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        successMessage = nil

        do {
            let payload = DBProfileUpsert(
                id: session.user.id,
                email: session.user.email,
                fullName: trimmedName,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarURL: avatarURL.trimmingCharacters(in: .whitespacesAndNewlines),
                isCaregiver: isCaregiver
            )

            _ = try await supabase.database
                .from("profiles")
                .upsert(payload)
                .execute()

            successMessage = "Profile updated successfully."
            await load(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decodeArray<T: Decodable>(from data: Data, decoder: JSONDecoder) throws -> [T] {
        guard !data.isEmpty else { return [] }
        if let text = String(data: data, encoding: .utf8), text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return try decoder.decode([T].self, from: data)
    }
}

private struct DBProfile: Decodable {
    let id: UUID
    let email: String?
    let fullName: String?
    let city: String?
    let avatarURL: String?
    let isCaregiver: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case city
        case avatarURL = "avatar_url"
        case isCaregiver = "is_caregiver"
    }
}

private struct DBCaregiverReview: Decodable {
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case reviewCount = "review_count"
    }
}

private struct DBProfileUpsert: Encodable {
    let id: UUID
    let email: String?
    let fullName: String
    let city: String
    let avatarURL: String
    let isCaregiver: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case city
        case avatarURL = "avatar_url"
        case isCaregiver = "is_caregiver"
    }
}
