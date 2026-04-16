//
//  PlantSittingView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import CoreLocation

// MARK: - Plant Sitting Tab

struct PlantSittingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()
    @StateObject private var locationManager = NearbyLocationManager()
    @State private var showBecomeSitter = false
    @State private var showSaved = false
    @State private var nearbyCity = ""
    @State private var showOnlyNearby = false

    private var trimmedNearbyCity: String {
        nearbyCity.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nearbyCaregivers: [Caregiver] {
        guard !trimmedNearbyCity.isEmpty else { return [] }
        return dataStore.caregivers.filter { locationMatches($0.location, city: trimmedNearbyCity) }
    }

    private var displayedCaregivers: [Caregiver] {
        let source = showOnlyNearby && !trimmedNearbyCity.isEmpty ? nearbyCaregivers : dataStore.caregivers
        return source.sorted { lhs, rhs in
            let lhsNearby = !trimmedNearbyCity.isEmpty && locationMatches(lhs.location, city: trimmedNearbyCity)
            let rhsNearby = !trimmedNearbyCity.isEmpty && locationMatches(rhs.location, city: trimmedNearbyCity)

            if lhsNearby != rhsNearby { return lhsNearby && !rhsNearby }
            if lhs.isAvailable != rhs.isAvailable { return lhs.isAvailable && !rhs.isAvailable }
            if lhs.rating != rhs.rating { return lhs.rating > rhs.rating }
            return lhs.name < rhs.name
        }
    }

    private var nearbyAvailableCount: Int {
        nearbyCaregivers.filter(\.isAvailable).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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

                    HStack(spacing: 0) {
                        HowItWorksStep(number: "1", icon: "magnifyingglass", label: "Browse\nCaregivers")
                        Divider().frame(height: 40)
                        HowItWorksStep(number: "2", icon: "calendar", label: "Pick\nDates")
                        Divider().frame(height: 40)
                        HowItWorksStep(number: "3", icon: "checkmark.seal.fill", label: "Confirm\nBooking")
                    }
                    .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    NearbyCaregiverCheck(
                        city: $nearbyCity,
                        showOnlyNearby: $showOnlyNearby,
                        nearbyCount: nearbyCaregivers.count,
                        nearbyAvailableCount: nearbyAvailableCount,
                        isLocating: locationManager.isLocating,
                        locationMessage: locationManager.locationMessage,
                        onUseCurrentLocation: {
                            locationManager.requestCurrentCity()
                        }
                    )
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Available Caregivers")
                                .font(.headline)
                            Spacer()
                            Text("\(displayedCaregivers.filter(\.isAvailable).count) available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        if displayedCaregivers.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.secondary)
                                Text("No nearby caregivers found")
                                    .font(.headline)
                                Text("Try another city or show all caregivers.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .padding(.horizontal)
                        } else {
                            ForEach(displayedCaregivers) { caregiver in
                                NavigationLink(destination: CaregiverDetailView(caregiver: caregiver, authViewModel: authViewModel)) {
                                    CaregiverCard(caregiver: caregiver)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
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
                await loadDefaultNearbyCity()
            }
            .onAppear {
                // Refresh on tab revisit so updated caregiver ratings are not shown from stale state.
                Task { await dataStore.loadCaregivers() }
            }
            .onChange(of: locationManager.detectedCity) { detectedCity in
                // Nearby filtering already works by city; CoreLocation only fills this field safely.
                if let detectedCity, !detectedCity.isEmpty {
                    nearbyCity = detectedCity
                    showOnlyNearby = true
                }
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

    private func loadDefaultNearbyCity() async {
        guard trimmedNearbyCity.isEmpty else { return }
        guard let city = try? await dataStore.loadCurrentUserCity(session: authViewModel.session), let city, !city.isEmpty else {
            return
        }
        nearbyCity = city
    }

    private func locationMatches(_ location: String, city: String) -> Bool {
        let normalizedLocation = normalizeLocation(location)
        let normalizedCity = normalizeLocation(city)
        guard !normalizedLocation.isEmpty, !normalizedCity.isEmpty else { return false }

        let locationParts = normalizedLocation
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        return locationParts.contains(normalizedCity)
            || normalizedLocation == normalizedCity
            || normalizedLocation.hasPrefix("\(normalizedCity),")
    }

    private func normalizeLocation(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private struct NearbyCaregiverCheck: View {
    @Binding var city: String
    @Binding var showOnlyNearby: Bool

    let nearbyCount: Int
    let nearbyAvailableCount: Int
    let isLocating: Bool
    let locationMessage: String?
    let onUseCurrentLocation: () -> Void

    private var trimmedCity: String {
        city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check Nearby Caregivers")
                .font(.headline)

            TextField("Enter your city", text: $city)
                .textFieldStyle(.roundedBorder)

            Button {
                onUseCurrentLocation()
            } label: {
                HStack(spacing: 8) {
                    if isLocating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Label("Use Current Location", systemImage: "location.fill")
                }
            }
            .buttonStyle(.bordered)
            .tint(.green)
            .disabled(isLocating)

            if let locationMessage, !locationMessage.isEmpty {
                // Permission failures stay non-blocking because manual city search still works.
                Text(locationMessage)
                    .font(.caption)
                    .foregroundStyle(locationMessage.hasPrefix("Using") ? .green : .orange)
            }

            if trimmedCity.isEmpty {
                Label("Enter a city to check nearby sitters.", systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if nearbyCount == 0 {
                Label("No caregivers found in \(trimmedCity).", systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label(
                    "\(nearbyAvailableCount) of \(nearbyCount) caregiver\(nearbyCount == 1 ? "" : "s") available in \(trimmedCity).",
                    systemImage: "location.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }

            Toggle("Show nearby only", isOn: $showOnlyNearby)
                .disabled(trimmedCity.isEmpty)
        }
        .padding(14)
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
                    Text("BDT \(Int(caregiver.pricePerDay))/day")
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
                    Text("|")
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
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()

    @State private var plantName = ""
    @State private var notes = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var showBookingConfirm = false
    @State private var showBooked = false
    @State private var isSavingBooking = false
    @State private var bookingErrorMessage: String?

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    private var totalCost: Double {
        Double(nights) * caregiver.pricePerDay
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", caregiver.rating))
                            .fontWeight(.semibold)
                        Text("(\(caregiver.reviewCount) reviews)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    HStack(spacing: 8) {
                        Label(caregiver.location, systemImage: "mappin")
                        Text("|")
                        Label("\(caregiver.yearsExperience) yrs exp.", systemImage: "leaf")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text(caregiver.bio.isEmpty ? "This caregiver has not added a bio yet." : caregiver.bio)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

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

                VStack(alignment: .leading, spacing: 14) {
                    Text("Your Plants")
                        .font(.headline)
                    TextField("Plant name", text: $plantName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Care notes (optional)", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }
                .padding(.horizontal)

                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Book a Stay")
                        .font(.headline)
                    DatePicker("Drop-off Date", selection: $startDate, in: Date()..., displayedComponents: .date)
                    DatePicker("Pick-up Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                .padding(.horizontal)

                VStack(spacing: 10) {
                    HStack {
                        Text("BDT \(Int(caregiver.pricePerDay)) x \(nights) day\(nights == 1 ? "" : "s")")
                        Spacer()
                        Text("BDT \(Int(totalCost))")
                    }
                    .font(.subheadline)
                    Divider()
                    HStack {
                        Text("Total").fontWeight(.semibold)
                        Spacer()
                        Text("BDT \(Int(totalCost))")
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                Button {
                    startBookingFlow()
                } label: {
                    HStack(spacing: 8) {
                        if isSavingBooking {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        }
                        Text(caregiver.isAvailable ? "Confirm Booking" : "Unavailable")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(caregiver.isAvailable ? .green : .gray)
                .disabled(!caregiver.isAvailable || isSavingBooking)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Caregiver Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: startDate) { newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
        .confirmationDialog("Confirm Booking", isPresented: $showBookingConfirm, titleVisibility: .visible) {
            Button("Book for BDT \(Int(totalCost))") {
                Task { await confirmBooking() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Book \(caregiver.name) from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))?")
        }
        .alert("Plant Sitting", isPresented: Binding(
            get: { bookingErrorMessage != nil },
            set: { if !$0 { bookingErrorMessage = nil } }
        )) {
            Button("OK") { bookingErrorMessage = nil }
        } message: {
            Text(bookingErrorMessage ?? "")
        }
        .alert("Booking Confirmed", isPresented: $showBooked) {
            Button("Great!") {}
        } message: {
            Text("\(caregiver.name) will care for your plants. You will receive a confirmation shortly.")
        }
    }

    private func startBookingFlow() {
        guard caregiver.isAvailable else { return }
        guard authViewModel.session != nil else {
            bookingErrorMessage = "Please sign in first."
            return
        }
        guard !plantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            bookingErrorMessage = "Please enter your plant name before booking."
            return
        }

        showBookingConfirm = true
    }

    private func confirmBooking() async {
        isSavingBooking = true
        defer { isSavingBooking = false }

        do {
            try await dataStore.createBooking(
                NewBookingInput(
                    caregiverID: caregiver.id,
                    plantName: plantName,
                    notes: notes,
                    startDate: startDate,
                    endDate: endDate,
                    totalPrice: totalCost
                ),
                session: authViewModel.session
            )
            plantName = ""
            notes = ""
            showBooked = true
        } catch {
            bookingErrorMessage = error.localizedDescription
        }
    }
}

private final class NearbyLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var detectedCity: String?
    @Published var locationMessage: String?
    @Published var isLocating = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestCurrentCity() {
        locationMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            isLocating = false
            locationMessage = "Location permission is off. You can still type your city manually."
        @unknown default:
            isLocating = false
            locationMessage = "Could not check location permission. Please type your city manually."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            isLocating = false
            locationMessage = "Location permission is off. You can still type your city manually."
        case .notDetermined:
            break
        @unknown default:
            isLocating = false
            locationMessage = "Could not check location permission. Please type your city manually."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLocating = false
            locationMessage = "Could not detect your location. Please type your city manually."
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLocating = false

                if error != nil {
                    self.locationMessage = "Could not read your city from location. Please type it manually."
                    return
                }

                let placemark = placemarks?.first
                let city = placemark?.locality
                    ?? placemark?.subAdministrativeArea
                    ?? placemark?.administrativeArea

                guard let city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.locationMessage = "Could not detect your city. Please type it manually."
                    return
                }

                self.detectedCity = city
                self.locationMessage = "Using your current city: \(city)."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        locationMessage = "Could not detect your location. Please type your city manually."
    }

    private func requestLocation() {
        isLocating = true
        manager.requestLocation()
    }
}
