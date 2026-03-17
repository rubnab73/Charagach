//
//  MyListingsView.swift
//  Charagach
//
//  Created by macOS on 3/18/26.
//

import SwiftUI
import Supabase

struct MyListingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()

    @State private var listings: [PlantListing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.green)
                        Text("Loading your listings...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if listings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("No Listings Yet")
                            .font(.headline)
                        Text("You have not posted any plants yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                } else {
                    List {
                        ForEach(listings) { listing in
                            MyListingRow(
                                listing: listing,
                                onStatusChange: { status in
                                    Task { await updateStatus(listingID: listing.id, status: status) }
                                },
                                onDelete: {
                                    Task { await deleteListing(listingID: listing.id) }
                                }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Listings")
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
            .alert("Listings", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            listings = try await dataStore.loadMyListings(session: authViewModel.session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateStatus(listingID: UUID, status: String) async {
        do {
            try await dataStore.updateListingStatus(listingID: listingID, status: status, session: authViewModel.session)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteListing(listingID: UUID) async {
        do {
            try await dataStore.deleteListing(listingID: listingID, session: authViewModel.session)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MyListingRow: View {
    let listing: PlantListing
    let onStatusChange: (String) -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var statusColor: Color {
        switch listing.status.lowercased() {
        case "active": return .green
        case "sold": return .orange
        case "archived": return .gray
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.name)
                        .font(.headline)
                    Text(listing.species)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                Spacer()
                Text("৳\(Int(listing.price))")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 8) {
                Text(listing.status.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)

                Spacer()

                Menu {
                    Button("Set Active") { onStatusChange("active") }
                    Button("Mark Sold") { onStatusChange("sold") }
                    Button("Archive") { onStatusChange("archived") }
                } label: {
                    Label("Status", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
        .confirmationDialog("Delete Listing", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(listing.name)?")
        }
    }
}
