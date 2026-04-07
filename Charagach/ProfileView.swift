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

    @State private var showSignOutConfirm = false
    @State private var showEditProfile = false
    @State private var showMyListings = false
    @State private var showMyBookings = false
    @State private var showComingSoon = false
    @State private var comingSoonText = ""
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
                            ProfileMenuItem(icon: "calendar.badge.checkmark", iconColor: .blue, label: "My Bookings") {
                                showMyBookings = true
                            }
                            ProfileMenuItem(icon: "star.fill", iconColor: .yellow, label: "My Reviews", showDivider: false) {
                                showPlaceholder("Your reviews screen will be here.")
                            }
                        }

                        ProfileMenuSection(title: "Account") {
                            ProfileMenuItem(icon: "person.fill", iconColor: .purple, label: "Edit Profile") {
                                showEditProfile = true
                            }
                            ProfileMenuItem(icon: "bell.fill", iconColor: .orange, label: "Notifications") {
                                showPlaceholder("Notifications settings will be here.")
                            }
                            ProfileMenuItem(icon: "lock.fill", iconColor: .gray, label: "Privacy & Security", showDivider: false) {
                                showPlaceholder("Privacy and security settings will be here.")
                            }
                        }

                        ProfileMenuSection(title: "Support") {
                            ProfileMenuItem(icon: "questionmark.circle.fill", iconColor: .teal, label: "Help Center") {
                                showPlaceholder("Help Center will be available soon.")
                            }
                            ProfileMenuItem(icon: "envelope.fill", iconColor: .indigo, label: "Contact Us", showDivider: false) {
                                showPlaceholder("Email us at support@charagach.app")
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
        .sheet(isPresented: $showMyBookings) {
            PlantSittingBookingsView(authViewModel: authViewModel)
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
        .alert("Coming Soon", isPresented: $showComingSoon) {
            Button("OK") {}
        } message: {
            Text(comingSoonText)
        }
    }

    private func showPlaceholder(_ message: String) {
        comingSoonText = message
        showComingSoon = true
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
