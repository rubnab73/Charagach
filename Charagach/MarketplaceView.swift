//
//  MarketplaceView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

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
                                NavigationLink(destination: PlantDetailView(listing: listing)) {
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
    @State private var errorMessage: String?

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
            description: description
        )

        onSave(payload)
        dismiss()
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

// MARK: - Listing Card

struct ListingCard: View {
    let listing: PlantListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Plant image area
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(listing.iconColor.opacity(0.12))
                    .frame(height: 120)
                Image(systemName: listing.iconName)
                    .font(.system(size: 46))
                    .foregroundStyle(listing.iconColor)

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

// MARK: - Plant Detail View

struct PlantDetailView: View {
    let listing: PlantListing
    @State private var showContact = false

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
                ZStack {
                    listing.iconColor.opacity(0.1)
                    Image(systemName: listing.iconName)
                        .font(.system(size: 110))
                        .foregroundStyle(listing.iconColor)
                }
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

                    // Tags & posted date
                    HStack {
                        TagView(text: listing.category.rawValue, color: .green)
                        TagView(text: listing.condition.rawValue, color: conditionColor)
                        if listing.status.lowercased() == "sold" {
                            TagView(text: "Sold", color: .red)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(listing.postedDaysAgo == 1
                                 ? "1 day ago"
                                 : "\(listing.postedDaysAgo) days ago")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
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
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Contact Seller", isPresented: $showContact) {
            Button("OK") {}
        } message: {
            Text("In a future update you will be able to message \(listing.sellerName) directly in-app.")
        }
    }
}
