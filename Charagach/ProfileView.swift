//
//  ProfileView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

// MARK: - Profile Tab

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showSignOutConfirm = false

    private var userEmail: String {
        authViewModel.session?.user.email ?? "No email"
    }

    private var userInitial: String {
        String((authViewModel.session?.user.email?.prefix(1) ?? "?").uppercased())
    }

    private var displayName: String {
        if let raw = authViewModel.session?.user.userMetadata["full_name"],
           case .string(let name) = raw, !name.isEmpty {
            return name
        }
        return userEmail
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Avatar & name ──────────────────────────────────
                    VStack(spacing: 10) {
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
                                Text(userInitial)
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        Text(displayName)
                            .font(.headline)
                        if displayName != userEmail {
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    // ── Stats row ──────────────────────────────────────
                    HStack(spacing: 0) {
                        StatTile(value: "3", label: "Listings")
                        Divider().frame(height: 40)
                        StatTile(value: "1", label: "Bookings")
                        Divider().frame(height: 40)
                        StatTile(value: "0", label: "Reviews")
                    }
                    .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // ── Menu ───────────────────────────────────────────
                    VStack(spacing: 0) {
                        ProfileMenuSection(title: "My Activity") {
                            ProfileMenuItem(icon: "tag.fill",               iconColor: .green,  label: "My Listings")
                            ProfileMenuItem(icon: "calendar.badge.checkmark", iconColor: .blue,   label: "My Bookings")
                            ProfileMenuItem(icon: "star.fill",              iconColor: .yellow, label: "My Reviews")
                        }

                        ProfileMenuSection(title: "Account") {
                            ProfileMenuItem(icon: "person.fill",  iconColor: .purple, label: "Edit Profile")
                            ProfileMenuItem(icon: "bell.fill",    iconColor: .orange, label: "Notifications")
                            ProfileMenuItem(icon: "lock.fill",    iconColor: .gray,   label: "Privacy & Security")
                        }

                        ProfileMenuSection(title: "Support") {
                            ProfileMenuItem(icon: "questionmark.circle.fill", iconColor: .teal,   label: "Help Center")
                            ProfileMenuItem(icon: "envelope.fill",            iconColor: .indigo, label: "Contact Us")
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
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await authViewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
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

private struct ProfileMenuItem: View {
    let icon: String
    let iconColor: Color
    let label: String

    var body: some View {
        Button {
            // TODO: per-item navigation
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
        Divider().padding(.leading, 64)
    }
}
