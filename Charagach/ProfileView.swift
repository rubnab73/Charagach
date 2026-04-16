//
//  ProfileView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import Supabase
import PhotosUI
import UIKit

// MARK: - Profile Tab

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.openURL) private var openURL

    @State private var showSignOutConfirm = false
    @State private var showEditProfile = false
    @State private var showMyListings = false
    @State private var showProfileError = false
    @State private var profileErrorText = ""

    private var userEmail: String {
        if !viewModel.email.isEmpty { return viewModel.email }
        return authViewModel.session?.user.email ?? "No email"
    }

    private var userInitial: String {
        let source = displayName.isEmpty ? userEmail : displayName
        return String(source.prefix(1)).uppercased()
    }

    private var displayName: String {
        if !viewModel.fullName.isEmpty { return viewModel.fullName }
        return userEmail
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.green)
                            .padding(.top, 8)
                    }

                    // ── Avatar & name ──────────────────────────────────
                    VStack(spacing: 10) {
                        ProfileAvatarView(avatarURL: viewModel.avatarURL, fallbackInitial: userInitial)
                        Text(displayName)
                            .font(.headline)
                        if displayName != userEmail {
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !viewModel.city.isEmpty {
                            Label(viewModel.city, systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    // ── Stats row ──────────────────────────────────────
                    HStack(spacing: 0) {
                        StatTile(value: "\(viewModel.listingsCount)", label: "Listings")
                        Divider().frame(height: 40)
                        StatTile(value: "\(viewModel.bookingsCount)", label: "Bookings")
                        Divider().frame(height: 40)
                        StatTile(value: "\(viewModel.reviewsCount)", label: "Reviews")
                    }
                    .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // ── Menu ───────────────────────────────────────────
                    VStack(spacing: 0) {
                        ProfileMenuSection(title: "My Activity") {
                            ProfileMenuItem(icon: "tag.fill", iconColor: .green, label: "My Listings") {
                                showMyListings = true
                            }
                            ProfileMenuNavigationItem(icon: "calendar.badge.checkmark", iconColor: .blue, label: "My Bookings") {
                                ProfileBookingsView(authViewModel: authViewModel)
                            }
                            ProfileMenuNavigationItem(icon: "star.fill", iconColor: .yellow, label: "My Reviews", showDivider: false) {
                                ProfileReviewsView(authViewModel: authViewModel)
                            }
                        }

                        ProfileMenuSection(title: "Account") {
                            ProfileMenuItem(icon: "person.fill", iconColor: .purple, label: "Edit Profile") {
                                showEditProfile = true
                            }
                            ProfileMenuNavigationItem(icon: "bell.fill", iconColor: .orange, label: "Notifications") {
                                NotificationsSettingsView()
                            }
                            ProfileMenuNavigationItem(icon: "lock.fill", iconColor: .gray, label: "Privacy & Security", showDivider: false) {
                                PrivacySecurityView(authViewModel: authViewModel, userEmail: userEmail)
                            }
                        }

                        ProfileMenuSection(title: "Support") {
                            ProfileMenuNavigationItem(icon: "questionmark.circle.fill", iconColor: .teal, label: "Help Center") {
                                HelpCenterView()
                            }
                            ProfileMenuItem(icon: "envelope.fill", iconColor: .indigo, label: "Contact Us", showDivider: false) {
                                openSupportEmail()
                            }
                        }
                    }
                    .padding(.horizontal)

                    // ── Sign out ───────────────────────────────────────
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Profile")
            .task {
                await viewModel.load(session: authViewModel.session)
            }
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await authViewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel, session: authViewModel.session)
        }
        .sheet(isPresented: $showMyListings) {
            MyListingsView(authViewModel: authViewModel)
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            guard let message = newValue, !message.isEmpty else { return }
            profileErrorText = message
            showProfileError = true
        }
        .alert("Profile", isPresented: $showProfileError) {
            Button("OK") {
                profileErrorText = ""
                viewModel.errorMessage = nil
            }
        } message: {
            Text(profileErrorText)
        }
    }

    private func openSupportEmail() {
        guard let url = URL(string: "mailto:support@charagach.app") else {
            profileErrorText = "Could not open the support email address."
            showProfileError = true
            return
        }

        // Keep the support button from failing silently when no mail app is configured.
        openURL(url) { accepted in
            if !accepted {
                profileErrorText = "This device cannot open an email app right now."
                showProfileError = true
            }
        }
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.green)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Profile Menu Section

private struct ProfileMenuSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Profile Menu Item

private struct ProfileMenuRowLabel: View {
    let icon: String
    let iconColor: Color
    let label: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ProfileMenuItem: View {
    let icon: String
    let iconColor: Color
    let label: String
    var showDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ProfileMenuRowLabel(icon: icon, iconColor: iconColor, label: label)
        }
        if showDivider {
            Divider().padding(.leading, 64)
        }
    }
}

private struct ProfileMenuNavigationItem<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    var showDivider: Bool = true
    let destination: Destination

    init(
        icon: String,
        iconColor: Color,
        label: String,
        showDivider: Bool = true,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.showDivider = showDivider
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            ProfileMenuRowLabel(icon: icon, iconColor: iconColor, label: label)
        }
        if showDivider {
            Divider().padding(.leading, 64)
        }
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let session: Session?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    @State private var showSaveError = false
    @State private var saveErrorText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic") {
                    TextField("Full name", text: $viewModel.fullName)
                    TextField("Email", text: .constant(viewModel.email))
                        .disabled(true)
                    TextField("City", text: $viewModel.city)
                }

                Section("Profile") {
                    HStack(spacing: 14) {
                        EditableAvatarView(
                            currentAvatarURL: viewModel.avatarURL,
                            selectedAvatarData: selectedAvatarData,
                            fallbackInitial: String((viewModel.fullName.isEmpty ? viewModel.email : viewModel.fullName).prefix(1)).uppercased()
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Choose Profile Picture", systemImage: "photo")
                            }

                            Text("JPG/PNG image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("I also provide plant sitting", isOn: $viewModel.isCaregiver)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.08).ignoresSafeArea()
                        ProgressView("Saving...")
                            .padding(16)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedAvatarData = data
                    }
                }
            }
            .onChange(of: viewModel.errorMessage) { message in
                guard let message, !message.isEmpty else { return }
                saveErrorText = message
                showSaveError = true
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.save(session: session, avatarImageData: selectedAvatarData)
                            if viewModel.errorMessage == nil { dismiss() }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Could not save profile", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {
                    saveErrorText = ""
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(saveErrorText)
            }
        }
    }
}

private struct ProfileAvatarView: View {
    let avatarURL: String
    let fallbackInitial: String

    var body: some View {
        if let url = URL(string: avatarURL), !avatarURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    avatarFallback
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.green, .mint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 90, height: 90)
            .overlay {
                Text(fallbackInitial)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

private struct EditableAvatarView: View {
    let currentAvatarURL: String
    let selectedAvatarData: Data?
    let fallbackInitial: String

    var body: some View {
        Group {
            if let selectedAvatarData, let image = UIImage(data: selectedAvatarData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: currentAvatarURL), !currentAvatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(.green.opacity(0.25), lineWidth: 1))
    }

    private var fallback: some View {
        Circle()
            .fill(.green.opacity(0.15))
            .overlay {
                Text(fallbackInitial)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)
            }
    }
}

// MARK: - Bookings

private struct ProfileBookingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()

    @State private var bookings: [PlantSittingBooking] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter = BookingListFilter.all

    private var currentUserID: UUID? {
        authViewModel.session?.user.id
    }

    private var filteredBookings: [PlantSittingBooking] {
        guard let currentUserID else { return bookings }

        switch selectedFilter {
        case .all:
            return bookings
        case .owner:
            return bookings.filter { $0.role(for: currentUserID) == .owner }
        case .caregiver:
            return bookings.filter { $0.role(for: currentUserID) == .caregiver }
        }
    }

    private var showsFilter: Bool {
        guard let currentUserID else { return false }
        let hasOwnerBookings = bookings.contains { $0.role(for: currentUserID) == .owner }
        let hasCaregiverBookings = bookings.contains { $0.role(for: currentUserID) == .caregiver }
        return hasOwnerBookings && hasCaregiverBookings
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading bookings...")
                    .tint(.green)
            } else if filteredBookings.isEmpty {
                ProfileEmptyState(
                    icon: "calendar.badge.exclamationmark",
                    title: "No Bookings Yet",
                    message: "Bookings you make or manage will appear here."
                )
            } else {
                List {
                    if showsFilter {
                        Section {
                            Picker("Booking View", selection: $selectedFilter) {
                                ForEach(BookingListFilter.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    ForEach(filteredBookings) { booking in
                        if let currentUserID {
                            BookingRow(
                                booking: booking,
                                currentUserID: currentUserID,
                                onStatusChange: { status in
                                    Task { await updateStatus(bookingID: booking.id, status: status) }
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refresh()
                }
            }
        }
        .navigationTitle("My Bookings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await refresh()
        }
        .alert("Bookings", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            bookings = try await dataStore.loadMyBookings(session: authViewModel.session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateStatus(bookingID: UUID, status: BookingStatus) async {
        do {
            try await dataStore.updateBookingStatus(bookingID: bookingID, status: status, session: authViewModel.session)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum BookingListFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case owner = "As Owner"
    case caregiver = "As Caregiver"

    var id: String { rawValue }
}

private struct BookingRow: View {
    let booking: PlantSittingBooking
    let currentUserID: UUID
    let onStatusChange: (BookingStatus) -> Void

    private var role: BookingRole {
        booking.role(for: currentUserID) ?? .owner
    }

    private var counterpartLabel: String {
        role == .owner ? "Caregiver" : "Owner"
    }

    private var actionStatus: BookingStatus? {
        switch (role, booking.status) {
        case (.owner, .pending): return .cancelled
        case (.caregiver, .pending): return .confirmed
        case (.caregiver, .confirmed): return .completed
        default: return nil
        }
    }

    private var actionTitle: String {
        switch actionStatus {
        case .cancelled:
            return "Cancel Booking"
        case .confirmed:
            return "Confirm Booking"
        case .completed:
            return "Mark Completed"
        default:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.displayPlantName)
                        .font(.headline)
                    Text("\(counterpartLabel): \(booking.counterpartName(for: currentUserID))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BookingStatusBadge(status: booking.status)
            }

            HStack(spacing: 10) {
                Label(role.rawValue, systemImage: role == .owner ? "person.fill" : "hands.sparkles.fill")
                Label(
                    "\(booking.startDate.formatted(date: .abbreviated, time: .omitted)) - \(booking.endDate.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !booking.notes.isEmpty {
                Text(booking.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Total")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("BDT \(Int(booking.totalPrice))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
            }

            if let actionStatus {
                Button(actionTitle, role: actionStatus == .cancelled ? .destructive : nil) {
                    onStatusChange(actionStatus)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct BookingStatusBadge: View {
    let status: BookingStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.12), in: Capsule())
            .foregroundStyle(status.color)
    }
}

// MARK: - Reviews

private enum ReviewSheetTarget: Identifiable {
    case booking(PlantSittingBooking)
    case review(CaregiverReviewEntry)

    var id: UUID {
        switch self {
        case .booking(let booking): return booking.id
        case .review(let review): return review.id
        }
    }
}

private struct ProfileReviewsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()

    @State private var reviewCenter = ReviewCenterData.empty
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReviewTarget: ReviewSheetTarget?

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading reviews...")
                    .tint(.green)
                    .padding(.top, 40)
            } else if reviewCenter.receivedSummaryCount == 0 &&
                        reviewCenter.pending.isEmpty &&
                        reviewCenter.received.isEmpty &&
                        reviewCenter.given.isEmpty {
                ProfileEmptyState(
                    icon: "star.bubble",
                    title: "No Reviews Yet",
                    message: "Completed bookings and received feedback will appear here."
                )
                .padding(.top, 40)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if reviewCenter.receivedSummaryCount > 0 {
                        ReviewSummaryCard(
                            averageRating: reviewCenter.receivedSummaryRating,
                            reviewCount: reviewCenter.receivedSummaryCount
                        )
                    }

                    if !reviewCenter.pending.isEmpty {
                        ReviewSection(title: "Pending Feedback") {
                            ForEach(reviewCenter.pending) { booking in
                                PendingReviewCard(booking: booking) {
                                    selectedReviewTarget = .booking(booking)
                                }
                            }
                        }
                    }

                    if !reviewCenter.received.isEmpty {
                        ReviewSection(title: "Reviews You Received") {
                            ForEach(reviewCenter.received) { review in
                                ReviewRow(
                                    title: review.reviewerName,
                                    subtitle: review.plantName.isEmpty ? "Plant sitting review" : review.plantName,
                                    rating: review.rating,
                                    comment: review.comment,
                                    date: review.createdAt
                                )
                            }
                        }
                    }

                    if !reviewCenter.given.isEmpty {
                        ReviewSection(title: "Reviews You Wrote") {
                            ForEach(reviewCenter.given) { review in
                                ReviewRow(
                                    title: review.caregiverName,
                                    subtitle: review.plantName.isEmpty ? "Plant sitting review" : review.plantName,
                                    rating: review.rating,
                                    comment: review.comment,
                                    date: review.createdAt,
                                    actionTitle: "Edit Review",
                                    action: {
                                        selectedReviewTarget = .review(review)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("My Reviews")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .sheet(item: $selectedReviewTarget) { target in
            LeaveReviewSheet(authViewModel: authViewModel, target: target) {
                await refresh()
            }
        }
        .alert("Reviews", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            reviewCenter = try await dataStore.loadReviewCenter(session: authViewModel.session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReviewSummaryCard: View {
    let averageRating: Double
    let reviewCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Caregiver Rating")
                .font(.headline)
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(String(format: "%.1f", averageRating))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: Double(index) < averageRating.rounded() ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text("\(reviewCount) total review\(reviewCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct PendingReviewCard: View {
    let booking: PlantSittingBooking
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(booking.displayPlantName)
                .font(.headline)
            Text("Caregiver: \(booking.caregiverName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(booking.startDate.formatted(date: .abbreviated, time: .omitted)) - \(booking.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Leave Review") {
                onReview()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ReviewRow: View {
    let title: String
    let subtitle: String
    let rating: Double
    let comment: String
    let date: Date?
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .fontWeight(.semibold)
                    }
                    if let date {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(comment.isEmpty ? "No written comment." : comment)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LeaveReviewSheet: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()
    @Environment(\.dismiss) private var dismiss

    let bookingID: UUID
    let caregiverID: UUID
    let plantTitle: String
    let caregiverName: String
    let onSubmitted: () async -> Void

    @State private var rating: Int
    @State private var comment: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(authViewModel: AuthViewModel, target: ReviewSheetTarget, onSubmitted: @escaping () async -> Void) {
        _authViewModel = ObservedObject(wrappedValue: authViewModel)
        self.onSubmitted = onSubmitted

        switch target {
        case .booking(let booking):
            self.bookingID = booking.id
            self.caregiverID = booking.caregiverID
            self.plantTitle = booking.displayPlantName
            self.caregiverName = booking.caregiverName
            _rating = State(initialValue: 5)
            _comment = State(initialValue: "")
        case .review(let review):
            self.bookingID = review.bookingID
            self.caregiverID = review.caregiverID
            self.plantTitle = review.plantName.isEmpty ? "Plant sitting review" : review.plantName
            self.caregiverName = review.caregiverName
            // Load the saved rating/comment so edits reflect the actual persisted review.
            _rating = State(initialValue: min(5, max(1, Int(review.rating.rounded()))))
            _comment = State(initialValue: review.comment)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Booking") {
                    Text(plantTitle)
                    Text(caregiverName)
                        .foregroundStyle(.secondary)
                }

                Section("Rating") {
                    HStack {
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }

                Section("Comment") {
                    TextField("Share your experience", text: $comment, axis: .vertical)
                        .lineLimit(4...7)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Leave Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task { await submitReview() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func submitReview() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await dataStore.submitReview(
                NewReviewInput(
                    bookingID: bookingID,
                    caregiverID: caregiverID,
                    rating: rating,
                    comment: comment
                ),
                session: authViewModel.session
            )
            await onSubmitted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Notifications

private struct NotificationsSettingsView: View {
    @AppStorage("notifications.booking_updates") private var bookingUpdates = true
    @AppStorage("notifications.review_activity") private var reviewActivity = true
    @AppStorage("notifications.marketing") private var marketing = false
    @AppStorage("notifications.daily_tips") private var dailyTips = true
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Booking updates", isOn: $bookingUpdates)
                Toggle("Review activity", isOn: $reviewActivity)
                Toggle("Daily care tips", isOn: $dailyTips)
                Toggle("Offers and announcements", isOn: $marketing)
            }

            Section("System") {
                Button("Open App Notification Settings") {
                    openSettings()
                }
                Text("These preferences are stored on this device. Use your iPhone settings to manage push permissions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Privacy & Security

private struct PrivacySecurityView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let userEmail: String
    @Environment(\.openURL) private var openURL

    @State private var statusMessage = ""
    @State private var showStatusMessage = false

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Email") {
                    Text(userEmail)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Security") {
                Button("Send Password Reset Email") {
                    Task { await sendPasswordReset() }
                }
                Button("Open App Settings") {
                    openSettings()
                }
            }

            Section("Privacy") {
                Text("Your profile currently shows your name, avatar, city, listing counts, booking activity, and caregiver activity inside the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("If you need help with account privacy or data access, contact support from the Help Center.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy & Security")
        .onDisappear {
            authViewModel.errorMessage = nil
            authViewModel.successMessage = nil
        }
        .alert("Security", isPresented: $showStatusMessage) {
            Button("OK") {}
        } message: {
            Text(statusMessage)
        }
    }

    private func sendPasswordReset() async {
        authViewModel.errorMessage = nil
        authViewModel.successMessage = nil
        await authViewModel.sendPasswordReset(email: userEmail)
        statusMessage = authViewModel.errorMessage ?? authViewModel.successMessage ?? "Request finished."
        showStatusMessage = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Help Center

private struct HelpCenterView: View {
    @Environment(\.openURL) private var openURL
    @State private var supportErrorMessage: String?

    private let faqs: [HelpFAQ] = [
        HelpFAQ(
            question: "How do bookings work?",
            answer: "Choose a caregiver, enter your plant details, pick your dates, and confirm the booking. The caregiver can then confirm or complete it from their bookings list."
        ),
        HelpFAQ(
            question: "Where can I manage my listings?",
            answer: "Open Profile, then choose My Listings. From there you can edit posts, change status, or delete a listing."
        ),
        HelpFAQ(
            question: "How do reviews appear?",
            answer: "After a completed booking, the plant owner can leave a review. Caregiver ratings are updated from those submitted reviews."
        ),
        HelpFAQ(
            question: "How do I update my profile or sitter status?",
            answer: "Use Edit Profile to update your personal details. If you enable plant sitting there, the app now keeps your caregiver profile in sync."
        )
    ]

    var body: some View {
        List {
            Section("Quick Help") {
                Button("Email Support") {
                    openSupportEmail()
                }
                Link("Visit Supabase Project Dashboard", destination: URL(string: "https://supabase.com/dashboard")!)
            }

            Section("Frequently Asked Questions") {
                ForEach(faqs) { faq in
                    DisclosureGroup(faq.question) {
                        Text(faq.answer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }

            Section("Need More Help?") {
                Text("For account issues, booking questions, or profile problems, email support@charagach.app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Help Center")
        .alert("Help Center", isPresented: Binding(
            get: { supportErrorMessage != nil },
            set: { if !$0 { supportErrorMessage = nil } }
        )) {
            Button("OK") { supportErrorMessage = nil }
        } message: {
            Text(supportErrorMessage ?? "")
        }
    }

    private func openSupportEmail() {
        guard let url = URL(string: "mailto:support@charagach.app") else { return }
        // Keep the support button from failing silently when no mail app is configured.
        openURL(url) { accepted in
            if !accepted {
                supportErrorMessage = "This device cannot open an email app right now."
            }
        }
    }
}

private struct HelpFAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Shared Empty State

private struct ProfileEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
