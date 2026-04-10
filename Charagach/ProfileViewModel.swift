//
//  ProfileViewModel.swift
//  Charagach
//
//  Created by macOS on 3/18/26.
//

import Foundation
@preconcurrency import Supabase
import UIKit

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
            let caregiverBookingsResponse = try await supabase.database
                .from("plant_sitting_bookings")
                .select("id", count: .exact)
                .eq("caregiver_id", value: userID.uuidString)
                .execute()
            bookingsCount = (bookingsResponse.count ?? 0) + (caregiverBookingsResponse.count ?? 0)

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

    func save(session: Session?, avatarImageData: Data? = nil) async {
        let activeSession: Session
        if let session {
            activeSession = session
        } else {
            do {
                activeSession = try await supabase.auth.session
            } catch {
                errorMessage = "Please sign in first."
                return
            }
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
            var finalAvatarURL = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)

            if let avatarImageData {
                do {
                    finalAvatarURL = try await uploadAvatarImage(avatarImageData, userID: activeSession.user.id)
                } catch {
                    throw NSError(
                        domain: "ProfileSave",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Avatar upload failed: \(error.localizedDescription)"]
                    )
                }
            }

            let profileID = activeSession.user.id.uuidString
            let decoder = JSONDecoder()

            let existingResponse = try await supabase.database
                .from("profiles")
                .select("id")
                .eq("id", value: profileID)
                .limit(1)
                .execute()
            let existingRows: [DBIdOnly] = try decodeArray(from: existingResponse.data, decoder: decoder)

            if existingRows.isEmpty {
                let insertPayload = DBProfileInsert(
                    id: activeSession.user.id,
                    email: activeSession.user.email,
                    fullName: trimmedName,
                    city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatarURL: finalAvatarURL,
                    isCaregiver: isCaregiver
                )

                do {
                    _ = try await supabase.database
                        .from("profiles")
                        .insert(insertPayload)
                        .execute()
                } catch {
                    throw NSError(
                        domain: "ProfileSave",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Profile insert failed (RLS): \(error.localizedDescription)"]
                    )
                }
            } else {
                let updatePayload = DBProfileUpdate(
                    fullName: trimmedName,
                    city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatarURL: finalAvatarURL,
                    isCaregiver: isCaregiver
                )

                do {
                    _ = try await supabase.database
                        .from("profiles")
                        .update(updatePayload)
                        .eq("id", value: profileID)
                        .execute()
                } catch {
                    throw NSError(
                        domain: "ProfileSave",
                        code: 1003,
                        userInfo: [NSLocalizedDescriptionKey: "Profile update failed (RLS): \(error.localizedDescription)"]
                    )
                }
            }

            try await syncCaregiverProfile(
                userID: activeSession.user.id,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                decoder: decoder
            )

            avatarURL = finalAvatarURL
            successMessage = "Profile updated successfully."
            await load(session: activeSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncCaregiverProfile(userID: UUID, city: String, decoder: JSONDecoder) async throws {
        let existingResponse = try await supabase.database
            .from("caregivers")
            .select("id, location")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
        let existingRows: [DBExistingCaregiver] = try decodeArray(from: existingResponse.data, decoder: decoder)

        if isCaregiver {
            if existingRows.isEmpty {
                let insertPayload = DBDefaultCaregiverInsert(
                    id: userID,
                    bio: "",
                    pricePerDay: 0,
                    yearsExperience: 0,
                    location: city,
                    specialties: [],
                    isAvailable: false,
                    rating: 0,
                    reviewCount: 0
                )

                _ = try await supabase.database
                    .from("caregivers")
                    .insert(insertPayload)
                    .execute()
            } else if !city.isEmpty {
                let updatePayload = DBCaregiverLocationUpdate(location: city)

                _ = try await supabase.database
                    .from("caregivers")
                    .update(updatePayload)
                    .eq("id", value: userID.uuidString)
                    .execute()
            }
        } else if !existingRows.isEmpty {
            let updatePayload = DBCaregiverAvailabilityUpdate(isAvailable: false)

            _ = try await supabase.database
                .from("caregivers")
                .update(updatePayload)
                .eq("id", value: userID.uuidString)
                .execute()
        }
    }

    private func decodeArray<T: Decodable>(from data: Data, decoder: JSONDecoder) throws -> [T] {
        guard !data.isEmpty else { return [] }
        if let text = String(data: data, encoding: .utf8), text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return try decoder.decode([T].self, from: data)
    }

    private func uploadAvatarImage(_ data: Data, userID: UUID) async throws -> String {
        let compressedData = compressedJPEGData(from: data)
        let fileName = "profile-\(Int(Date().timeIntervalSince1970)).jpg"
        let path = "\(userID.uuidString)/\(fileName)"

        _ = try await supabase.storage
            .from("avatars")
            .upload(
                path: path,
                file: compressedData
            )

        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }

    private func compressedJPEGData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8)
        else {
            return data
        }
        return jpeg
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

private struct DBIdOnly: Decodable {
    let id: UUID
}

private struct DBExistingCaregiver: Decodable {
    let id: UUID
    let location: String?
}

private struct DBProfileInsert: Encodable {
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

private struct DBProfileUpdate: Encodable {
    let fullName: String
    let city: String
    let avatarURL: String
    let isCaregiver: Bool

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case city
        case avatarURL = "avatar_url"
        case isCaregiver = "is_caregiver"
    }
}

private struct DBDefaultCaregiverInsert: Encodable {
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

private struct DBCaregiverLocationUpdate: Encodable {
    let location: String
}

private struct DBCaregiverAvailabilityUpdate: Encodable {
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
    }
}
