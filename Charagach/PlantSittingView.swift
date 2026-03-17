//
//  PlantSittingView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

// MARK: - Plant Sitting Tab

struct PlantSittingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()
    @State private var showBecomeSitter = false
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Hero banner ────────────────────────────────────
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Plant Sitting")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Trusted caregivers look after\nyour plants while you're away.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineSpacing(2)
                            }
                            Spacer()
                            Image(systemName: "hands.and.sparkles.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(20)
                    }
                    .padding(.horizontal)

                    // ── How it works ───────────────────────────────────
                    HStack(spacing: 0) {
                        HowItWorksStep(number: "1", icon: "magnifyingglass", label: "Browse\nCaregivers")
                        Divider().frame(height: 40)
                        HowItWorksStep(number: "2", icon: "calendar", label: "Pick\nDates")
                        Divider().frame(height: 40)
                        HowItWorksStep(number: "3", icon: "checkmark.seal.fill", label: "Confirm\nBooking")
                    }
                    .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // ── Caregiver list ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Available Caregivers")
                                .font(.headline)
                            Spacer()
                            Text("\(dataStore.caregivers.filter(\.isAvailable).count) available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ForEach(dataStore.caregivers) { caregiver in
                            NavigationLink(destination: CaregiverDetailView(caregiver: caregiver)) {
                                CaregiverCard(caregiver: caregiver)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Plant Sitting")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showBecomeSitter = true
                    } label: {
                        Text("Become a Sitter")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }
            .sheet(isPresented: $showBecomeSitter) {
                BecomeSitterView { payload in
                    Task {
                        do {
                            try await dataStore.registerCaregiver(payload, session: authViewModel.session)
                            showSaved = true
                        } catch {
                            dataStore.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .task {
                await dataStore.loadCaregivers()
            }
            .alert("Plant Sitting", isPresented: Binding(
                get: { dataStore.errorMessage != nil },
                set: { if !$0 { dataStore.errorMessage = nil } }
            )) {
                Button("OK") { dataStore.errorMessage = nil }
            } message: {
                Text(dataStore.errorMessage ?? "")
            }
            .alert("Success", isPresented: $showSaved) {
                Button("OK") {}
            } message: {
                Text("Your sitter profile has been saved.")
            }
        }
    }
}

// MARK: - Become Sitter Sheet

private struct BecomeSitterView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var bio = ""
    @State private var specialtiesInput = ""
    @State private var yearsExperience = ""
    @State private var pricePerDay = ""
    @State private var isAvailable = true
    @State private var errorMessage: String?

    let onSave: (NewCaregiverInput) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Full name", text: $name)
                    TextField("Location", text: $location)
                    TextField("Short bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Services") {
                    TextField("Specialties (comma separated)", text: $specialtiesInput)
                    TextField("Years of experience", text: $yearsExperience)
                        .keyboardType(.numberPad)
                    TextField("Price per day (BDT)", text: $pricePerDay)
                        .keyboardType(.numberPad)
                    Toggle("Available now", isOn: $isAvailable)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Become a Sitter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        errorMessage = nil

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard !location.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your location."
            return
        }
        guard let years = Int(yearsExperience), years >= 0 else {
            errorMessage = "Enter valid years of experience."
            return
        }
        guard let rate = Double(pricePerDay), rate >= 0 else {
            errorMessage = "Enter a valid daily rate."
            return
        }

        let specialties = specialtiesInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let payload = NewCaregiverInput(
            fullName: name,
            location: location,
            bio: bio,
            specialties: specialties.isEmpty ? ["General"] : specialties,
            yearsExperience: years,
            pricePerDay: rate,
            isAvailable: isAvailable
        )

        onSave(payload)
        dismiss()
    }
}

// MARK: - How It Works Step

private struct HowItWorksStep: View {
    let number: String
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Caregiver Card

struct CaregiverCard: View {
    let caregiver: Caregiver

    var body: some View {
        HStack(spacing: 14) {

            // Avatar with availability dot
            Circle()
                .fill(caregiver.avatarColor.opacity(0.18))
                .frame(width: 58, height: 58)
                .overlay {
                    Text(String(caregiver.name.prefix(1)))
                        .font(.title3.bold())
                        .foregroundStyle(caregiver.avatarColor)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(caregiver.isAvailable ? Color.green : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(caregiver.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("৳\(Int(caregiver.pricePerDay))/day")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", caregiver.rating))
                        .font(.caption.weight(.semibold))
                    Text("(\(caregiver.reviewCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Image(systemName: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(caregiver.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(caregiver.specialties, id: \.self) { spec in
                            Text(spec)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.1), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Caregiver Detail View

struct CaregiverDetailView: View {
    let caregiver: Caregiver

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var showBookingConfirm = false
    @State private var showBooked = false

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }
    private var totalCost: Double { Double(nights) * caregiver.pricePerDay }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Avatar hero ────────────────────────────────────────
                VStack(spacing: 12) {
                    Circle()
                        .fill(caregiver.avatarColor.opacity(0.18))
                        .frame(width: 100, height: 100)
                        .overlay {
                            Text(String(caregiver.name.prefix(1)))
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(caregiver.avatarColor)
                        }
                    Text(caregiver.name)
                        .font(.title2.bold())
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text(String(format: "%.1f", caregiver.rating))
                            .fontWeight(.semibold)
                        Text("(\(caregiver.reviewCount) reviews)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    HStack(spacing: 8) {
                        Label(caregiver.location, systemImage: "mappin")
                        Text("·")
                        Label("\(caregiver.yearsExperience) yrs exp.", systemImage: "leaf")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    // Availability
                    HStack(spacing: 6) {
                        Circle()
                            .fill(caregiver.isAvailable ? .green : .gray)
                            .frame(width: 9, height: 9)
                        Text(caregiver.isAvailable ? "Available Now" : "Currently Unavailable")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(caregiver.isAvailable ? .green : .secondary)
                    }
                }
                .padding(.top)

                Divider().padding(.horizontal)

                // ── Bio ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text(caregiver.bio)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // ── Specialties ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Specialties")
                        .font(.headline)
                    FlowLayout(spacing: 8) {
                        ForEach(caregiver.specialties, id: \.self) { spec in
                            Text(spec)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(.green.opacity(0.1), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Divider().padding(.horizontal)

                // ── Booking date picker ────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    Text("Book a Stay")
                        .font(.headline)
                    DatePicker("Drop-off Date", selection: $startDate, in: Date()..., displayedComponents: .date)
                    DatePicker("Pick-up Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                .padding(.horizontal)

                // ── Cost summary ───────────────────────────────────────
                VStack(spacing: 10) {
                    HStack {
                        Text("৳\(Int(caregiver.pricePerDay)) × \(nights) day\(nights == 1 ? "" : "s")")
                        Spacer()
                        Text("৳\(Int(totalCost))")
                    }
                    .font(.subheadline)
                    Divider()
                    HStack {
                        Text("Total").fontWeight(.semibold)
                        Spacer()
                        Text("৳\(Int(totalCost))")
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                // ── Book button ────────────────────────────────────────
                Button {
                    if caregiver.isAvailable { showBookingConfirm = true }
                } label: {
                    Text(caregiver.isAvailable ? "Confirm Booking" : "Unavailable")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(caregiver.isAvailable ? .green : .gray)
                .disabled(!caregiver.isAvailable)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Caregiver Profile")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Confirm Booking", isPresented: $showBookingConfirm, titleVisibility: .visible) {
            Button("Book for ৳\(Int(totalCost))") { showBooked = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Book \(caregiver.name) from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))?")
        }
        .alert("Booking Confirmed! 🌿", isPresented: $showBooked) {
            Button("Great!") {}
        } message: {
            Text("\(caregiver.name) will care for your plants. You will receive a confirmation shortly.")
        }
    }
}
