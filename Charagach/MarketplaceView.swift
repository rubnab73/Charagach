//
//  MarketplaceView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Marketplace Tab

struct MarketplaceView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataStore = SupabaseDataStore()
    @State private var searchText = ""
    @State private var selectedCategory: PlantCategory = .all
    @State private var showAddListing = false

    var filtered: [PlantListing] {
        dataStore.listings.filter { listing in
            let matchCategory = selectedCategory == .all || listing.category == selectedCategory
            let matchSearch = searchText.isEmpty
                || listing.name.localizedCaseInsensitiveContains(searchText)
                || listing.species.localizedCaseInsensitiveContains(searchText)
            return matchCategory && matchSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // ── Category filter bar ────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(PlantCategory.allCases, id: \.self) { cat in
                                CategoryChip(category: cat, isSelected: selectedCategory == cat) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategory = cat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // ── Results grid ───────────────────────────────────
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("No plants found")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 14
                        ) {
                            ForEach(filtered) { listing in
                                NavigationLink(destination: PlantDetailView(listing: listing, currentUserID: authViewModel.session?.user.id)) {
                                    ListingCard(listing: listing)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Marketplace")
            .searchable(text: $searchText, prompt: "Search plants…")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddListing = true
                    } label: {
                        Label("Sell", systemImage: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .sheet(isPresented: $showAddListing) {
                AddListingView { payload in
                    Task {
                        do {
                            try await dataStore.addListing(payload, session: authViewModel.session)
                        } catch {
                            dataStore.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .task {
                await dataStore.loadListings()
            }
            .alert("Marketplace", isPresented: Binding(
                get: { dataStore.errorMessage != nil },
                set: { if !$0 { dataStore.errorMessage = nil } }
            )) {
                Button("OK") { dataStore.errorMessage = nil }
            } message: {
                Text(dataStore.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Add Listing Sheet

private struct AddListingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var species = ""
    @State private var price = ""
    @State private var city = ""
    @State private var phoneNumber = ""
    @State private var description = ""
    @State private var category: PlantCategory = .indoor
    @State private var condition: PlantCondition = .good
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var showCamera = false
    @State private var errorMessage: String?

    private let maxImageCount = 5

    let onSave: (NewListingInput) -> Void

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

                Section("Pricing & Location") {
                    TextField("Price (BDT)", text: $price)
                        .keyboardType(.numberPad)
                    TextField("City", text: $city)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Pictures") {
                    ListingImagePickerControls(
                        selectedPhotoItems: $selectedPhotoItems,
                        selectedImageData: $selectedImageData,
                        showCamera: $showCamera,
                        errorMessage: $errorMessage,
                        maxImageCount: maxImageCount
                    )
                }

                Section("Description") {
                    TextField("Write a short description", text: $description, axis: .vertical)
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
            .navigationTitle("Add Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Publish") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
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
        guard !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your phone number."
            return
        }

        let payload = NewListingInput(
            name: name,
            species: species,
            price: value,
            category: category,
            condition: condition,
            city: city,
            phoneNumber: phoneNumber,
            description: description,
            imageData: selectedImageData
        )

        onSave(payload)
        dismiss()
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var loadedImages = selectedImageData
        for item in items.prefix(maxImageCount) {
            guard loadedImages.count < maxImageCount else { break }
            if let data = try? await item.loadTransferable(type: Data.self) {
                loadedImages.append(data)
            }
        }

        selectedImageData = loadedImages
        selectedPhotoItems = []
    }

    private func addCameraImage(_ image: UIImage) {
        guard selectedImageData.count < maxImageCount else {
            errorMessage = "You can add up to \(maxImageCount) pictures."
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Could not read the camera image."
            return
        }

        selectedImageData.append(data)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: PlantCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color(.systemGray6), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

private struct MarketplaceListingImage: View {
    let imageURL: String?
    let iconName: String
    let iconColor: Color

    var body: some View {
        ZStack {
            iconFallback

            if let imageURL, let url = URL(string: imageURL), !imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        iconFallback
                    }
                }
            }
        }
        .clipped()
    }

    private var iconFallback: some View {
        ZStack {
            iconColor.opacity(0.12)
            Image(systemName: iconName)
                .font(.system(size: 46))
                .foregroundStyle(iconColor)
        }
    }
}

// MARK: - Listing Card

struct ListingCard: View {
    let listing: PlantListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Plant image area
            ZStack {
                MarketplaceListingImage(
                    imageURL: listing.primaryImageURL,
                    iconName: listing.iconName,
                    iconColor: listing.iconColor
                )
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if listing.status.lowercased() == "sold" {
                    VStack {
                        HStack {
                            Text("SOLD")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.red, in: Capsule())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(listing.species)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(1)
                HStack {
                    Text("৳\(Int(listing.price))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                    Spacer()
                    ConditionBadge(condition: listing.condition)
                }
                .padding(.top, 2)

                if listing.status.lowercased() == "sold" {
                    Text("Sold")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(listing.location)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

private struct ListingDetailHero: View {
    let listing: PlantListing

    var body: some View {
        if listing.imageURLs.isEmpty {
            ZStack {
                listing.iconColor.opacity(0.1)
                Image(systemName: listing.iconName)
                    .font(.system(size: 110))
                    .foregroundStyle(listing.iconColor)
            }
        } else {
            TabView {
                ForEach(listing.imageURLs, id: \.self) { imageURL in
                    ZoomableListingDetailImage(
                        imageURL: imageURL,
                        iconName: listing.iconName,
                        iconColor: listing.iconColor
                    )
                }
            }
            .tabViewStyle(.page(indexDisplayMode: listing.imageURLs.count > 1 ? .automatic : .never))
        }
    }
}

private struct ZoomableListingDetailImage: View {
    let imageURL: String?
    let iconName: String
    let iconColor: Color

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                iconFallback

                if let imageURL, let url = URL(string: imageURL), !imageURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(zoomAndPanGesture(in: proxy.size))
                                .onTapGesture(count: 2) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        resetZoom()
                                    }
                                }
                                .animation(.easeOut(duration: 0.15), value: scale)
                        default:
                            iconFallback
                        }
                    }
                }
            }
            .clipped()
        }
    }

    private var iconFallback: some View {
        ZStack {
            iconColor.opacity(0.12)
            Image(systemName: iconName)
                .font(.system(size: 68))
                .foregroundStyle(iconColor)
        }
    }

    private func zoomAndPanGesture(in size: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let next = max(1, min(lastScale * value, 4))
                    scale = next
                    if next <= 1.01 {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                .onEnded { value in
                    lastScale = max(1, min(lastScale * value, 4))
                    if lastScale <= 1.01 {
                        resetZoom()
                    } else {
                        clampOffset(in: size)
                    }
                },
            DragGesture()
                .onChanged { value in
                    guard scale > 1 else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { value in
                    guard scale > 1 else {
                        resetZoom()
                        return
                    }
                    lastOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    clampOffset(in: size)
                }
        )
    }

    private func clampOffset(in size: CGSize) {
        let maxX = (size.width * (scale - 1)) / 2
        let maxY = (size.height * (scale - 1)) / 2

        let clamped = CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )

        offset = clamped
        lastOffset = clamped
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Plant Detail View

struct PlantDetailView: View {
    let listing: PlantListing
    let currentUserID: UUID?
    @State private var showContact = false
    @State private var contactErrorMessage: String?
    @Environment(\.openURL) private var openURL

    private var isOwnListing: Bool {
        guard let currentUserID, let sellerID = listing.sellerID else { return false }
        return currentUserID == sellerID
    }

    private var conditionColor: Color {
        switch listing.condition {
        case .excellent: return .green
        case .good:      return .blue
        case .fair:      return .orange
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero banner
                ListingDetailHero(listing: listing)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)

                VStack(alignment: .leading, spacing: 20) {

                    // Name & price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.name)
                                .font(.title2.bold())
                            Text(listing.species)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                        Spacer()
                        Text("৳\(Int(listing.price))")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }

                    // Tags
                    HStack {
                        TagView(text: listing.category.rawValue, color: .green)
                        TagView(text: listing.condition.rawValue, color: conditionColor)
                        if listing.status.lowercased() == "sold" {
                            TagView(text: "Sold", color: .red)
                        }
                    }

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.headline)
                        Text(listing.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }

                    Divider()

                    // Seller info
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Seller")
                            .font(.headline)
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.green.opacity(0.15))
                                .frame(width: 46, height: 46)
                                .overlay {
                                    Text(String(listing.sellerName.prefix(1)))
                                        .font(.headline)
                                        .foregroundStyle(.green)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(listing.sellerName)
                                    .font(.subheadline.weight(.semibold))
                                HStack(spacing: 3) {
                                    Image(systemName: "mappin")
                                        .font(.caption)
                                    Text(listing.location)
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                                if let phone = listing.phoneNumber, !phone.isEmpty {
                                    HStack(spacing: 3) {
                                        Image(systemName: "phone.fill")
                                            .font(.caption)
                                        Text(phone)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // CTA
                    if isOwnListing {
                        Label("This is your listing", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    } else {
                        Button {
                            showContact = true
                        } label: {
                            Label("Contact Seller", systemImage: "message.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Contact Seller", isPresented: $showContact, titleVisibility: .visible) {
            if let phone = sanitizedPhoneNumber {
                Button("Call \(phone)") {
                    openContactURL(scheme: "tel", phone: phone)
                }
                Button("Message \(phone)") {
                    openContactURL(scheme: "sms", phone: phone)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if sanitizedPhoneNumber == nil {
                Text("No phone number is available for this seller.")
            } else {
                Text("Choose how to contact \(listing.sellerName). Charagach will open your Phone or Messages app.")
            }
        }
        .alert("Contact Seller", isPresented: Binding(
            get: { contactErrorMessage != nil },
            set: { if !$0 { contactErrorMessage = nil } }
        )) {
            Button("OK") { contactErrorMessage = nil }
        } message: {
            Text(contactErrorMessage ?? "")
        }
    }

    private var sanitizedPhoneNumber: String? {
        ContactUtilities.sanitizedPhoneNumber(listing.phoneNumber)
    }

    private func openContactURL(scheme: String, phone: String) {
        guard !isOwnListing else {
            contactErrorMessage = "You cannot contact yourself for your own listing."
            return
        }

        guard let url = URL(string: "\(scheme):\(phone)") else {
            contactErrorMessage = "Could not open this phone number."
            return
        }

        openURL(url) { accepted in
            if !accepted {
                contactErrorMessage = "This device cannot open \(scheme == "tel" ? "phone calls" : "messages") right now."
            }
        }
    }
}
