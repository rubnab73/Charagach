//
//  CharagachTests.swift
//  CharagachTests
//
//  Created by macOS on 1/24/26.
//

import XCTest
@testable import Charagach

final class CharagachTests: XCTestCase {

    func testBookingStayLengthCountsAtLeastOneDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let sameDay = PlantSittingBooking(
            id: UUID(),
            ownerID: UUID(),
            caregiverID: UUID(),
            ownerName: "Owner",
            caregiverName: "Caregiver",
            plantName: "Money Plant",
            notes: "",
            startDate: start,
            endDate: start,
            totalPrice: 300,
            status: .pending,
            createdAt: nil
        )

        XCTAssertEqual(sameDay.stayLength, 1)
    }

    func testBookingStayLengthCountsMultipleDays() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: start))

        let booking = PlantSittingBooking(
            id: UUID(),
            ownerID: UUID(),
            caregiverID: UUID(),
            ownerName: "Owner",
            caregiverName: "Caregiver",
            plantName: "Snake Plant",
            notes: "",
            startDate: start,
            endDate: end,
            totalPrice: 900,
            status: .confirmed,
            createdAt: nil
        )

        XCTAssertEqual(booking.stayLength, 3)
    }

    func testPhoneSanitizerKeepsOnlyPlusAndDigits() {
        XCTAssertEqual(ContactUtilities.sanitizedPhoneNumber("+880 1712-345-678"), "+8801712345678")
        XCTAssertEqual(ContactUtilities.sanitizedPhoneNumber("(017) 12 abc"), "01712")
        XCTAssertNil(ContactUtilities.sanitizedPhoneNumber("call me"))
        XCTAssertNil(ContactUtilities.sanitizedPhoneNumber(nil))
    }

    func testPlantCareReminderCodableRoundTrip() throws {
        let dueDate = Date(timeIntervalSince1970: 1_777_777_777)
        let reminder = PlantCareReminder(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            plantName: "Monstera",
            task: .water,
            dueDate: dueDate,
            notes: "Check the top inch of soil first.",
            isCompleted: false,
            createdAt: Date(timeIntervalSince1970: 1_777_700_000)
        )

        let data = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(PlantCareReminder.self, from: data)

        XCTAssertEqual(decoded.id, reminder.id)
        XCTAssertEqual(decoded.plantName, "Monstera")
        XCTAssertEqual(decoded.task, .water)
        XCTAssertEqual(decoded.notes, reminder.notes)
        XCTAssertEqual(decoded.isCompleted, false)
        XCTAssertEqual(decoded.notificationID, "care-reminder-11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(decoded.dueDate.timeIntervalSince1970, dueDate.timeIntervalSince1970, accuracy: 0.001)
    }
}
