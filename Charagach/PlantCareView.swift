//
//  PlantCareView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

// MARK: - Plant Care Tips Tab

struct PlantCareView: View {
    @State private var selectedCategory: TipCategory? = nil

    private var filtered: [PlantCareTip] {
        guard let cat = selectedCategory else { return PlantCareTip.samples }
        return PlantCareTip.samples.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Category filter ────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            TipCategoryChip(
                                label: "All",
                                icon: "sparkles",
                                color: .purple,
                                isSelected: selectedCategory == nil
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCategory = nil
                                }
                            }
                            ForEach(TipCategory.allCases, id: \.self) { cat in
                                TipCategoryChip(
                                    label: cat.rawValue,
                                    icon: cat.icon,
                                    color: cat.color,
                                    isSelected: selectedCategory == cat
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategory = cat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // ── Tips list ──────────────────────────────────────
                    VStack(spacing: 12) {
                        ForEach(filtered) { tip in
                            NavigationLink(destination: TipDetailView(tip: tip)) {
                                TipCard(tip: tip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Plant Care Tips")
        }
    }
}

// MARK: - Tip Category Chip

private struct TipCategoryChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray6), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Tip Card

struct TipCard: View {
    let tip: PlantCareTip

    private func difficultyColor(_ d: TipDifficulty) -> Color {
        switch d {
        case .beginner:     return .green
        case .intermediate: return .orange
        case .advanced:     return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {

            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tip.category.color.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: tip.category.icon)
                    .font(.title3)
                    .foregroundStyle(tip.category.color)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(tip.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(tip.readMinutes) min")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                Text(tip.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    TagView(text: tip.category.rawValue, color: tip.category.color)
                    TagView(text: tip.difficulty.rawValue, color: difficultyColor(tip.difficulty))
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Tip Detail View

struct TipDetailView: View {
    let tip: PlantCareTip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Hero icon
                ZStack {
                    tip.category.color.opacity(0.1)
                    Image(systemName: tip.category.icon)
                        .font(.system(size: 68))
                        .foregroundStyle(tip.category.color)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Title & meta
                VStack(alignment: .leading, spacing: 8) {
                    Text(tip.title)
                        .font(.title2.bold())
                    Text(tip.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TagView(text: tip.category.rawValue, color: tip.category.color)
                        TagView(text: tip.difficulty.rawValue, color: difficultyColor(tip.difficulty))
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(tip.readMinutes) min read")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Article body
                Text(tip.content)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
            }
            .padding(20)
        }
        .navigationTitle(tip.category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func difficultyColor(_ d: TipDifficulty) -> Color {
        switch d {
        case .beginner:     return .green
        case .intermediate: return .orange
        case .advanced:     return .red
        }
    }
}
