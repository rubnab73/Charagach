//
//  MyListingsView.swift
//  Charagach
//
//  Created by macOS on 3/18/26.
//

import SwiftUI
import PhotosUI
import Supabase
import UIKit

struct MyListingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()

    @State private var listings: [PlantListing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingListing: PlantListing?

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
                                onEdit: {
                                    editingListing = listing
                                },
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
            .sheet(item: $editingListing) { listing in
                EditListingSheet(listing: listing) { input in
                    Task {
                        do {
                            try await dataStore.updateListing(listingID: listing.id, input: input, session: authViewModel.session)
                            await refresh()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
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
    let onEdit: () -> Void
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
                    Button("Edit Post") { onEdit() }
                    Divider()
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

private struct EditListingSheet: View {
    let listing: PlantListing
    let onSave: (UpdateListingInput) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var species = ""
    @State private var price = ""
    @State private var city = ""
    @State private var phone = ""
    @State private var description = ""
    @State private var category: PlantCategory = .indoor
    @State private var condition: PlantCondition = .good
    @State private var existingImageURLs: [String] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var showCamera = false
    @State private var didLoadListing = false
    @State private var errorMessage: String?

    private let maxImageCount = 5
    private var maxNewImageCount: Int {
        max(0, maxImageCount - existingImageURLs.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plant") {
                    TextField("Plant name", text: $name)
                    TextField("Species", text: $species)
                    Picker("Category", selection: $category) {
                        ForEach(PlantCategory.allCases.filter { $0 != .all }, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    Picker("Condition", selection: $condition) {
                        Text("Excellent").tag(PlantCondition.excellent)
                        Text("Good").tag(PlantCondition.good)
                        Text("Fair").tag(PlantCondition.fair)
                    }
                }

                Section("Pricing & Contact") {
                    TextField("Price (BDT)", text: $price)
                        .keyboardType(.numberPad)
                    TextField("City", text: $city)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Description") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(4...7)
                }

                Section("Pictures") {
                    if existingImageURLs.isEmpty && selectedImageData.isEmpty {
                        Text("No pictures added yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !existingImageURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current pictures")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(existingImageURLs.enumerated()), id: \.offset) { index, imageURL in
                                        ExistingListingImageThumb(imageURL: imageURL) {
                                            existingImageURLs.remove(at: index)
                                            selectedPhotoItems = []
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    ListingImagePickerControls(
                        selectedPhotoItems: $selectedPhotoItems,
                        selectedImageData: $selectedImageData,
                        showCamera: $showCamera,
                        errorMessage: $errorMessage,
                        maxImageCount: maxNewImageCount
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                guard !didLoadListing else { return }
                didLoadListing = true
                name = listing.name
                species = listing.species
                price = String(Int(listing.price))
                city = listing.location
                phone = listing.phoneNumber ?? ""
                description = listing.description
                category = listing.category
                condition = listing.condition
                existingImageURLs = listing.imageURLs
            }
            .onChange(of: selectedPhotoItems) { newItems in
                Task { await loadSelectedPhotos(newItems) }
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    addCameraImage(image)
                }
            }
        }
    }

    private func save() {
        errorMessage = nil

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter plant name."
            return
        }
        guard !species.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter species."
            return
        }
        guard let value = Double(price), value >= 0 else {
            errorMessage = "Please enter a valid price."
            return
        }
        guard !city.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter city."
            return
        }
        guard !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter phone number."
            return
        }

        let input = UpdateListingInput(
            name: name,
            species: species,
            price: value,
            category: category,
            condition: condition,
            city: city,
            phoneNumber: phone,
            description: description,
            existingImageURLs: existingImageURLs,
            newImageData: selectedImageData
        )

        onSave(input)
        dismiss()
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var loadedImages = selectedImageData
        for item in items.prefix(maxNewImageCount) {
            guard loadedImages.count < maxNewImageCount else { break }
            if let data = try? await item.loadTransferable(type: Data.self) {
                loadedImages.append(data)
            }
        }

        selectedImageData = loadedImages
        selectedPhotoItems = []
    }

    private func addCameraImage(_ image: UIImage) {
        guard selectedImageData.count < maxNewImageCount else {
            errorMessage = "You can keep up to \(maxImageCount) pictures per listing."
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Could not read the camera image."
            return
        }

        selectedImageData.append(data)
    }
}
