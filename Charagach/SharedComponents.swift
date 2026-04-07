//
//  SharedComponents.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

// MARK: - Tag Pill

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let condition: PlantCondition

    var color: Color {
        switch condition {
        case .excellent: return .green
        case .good:      return .blue
        case .fair:      return .orange
        }
    }

    var body: some View {
        Text(condition.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Flow Layout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += maxH + spacing
                x = 0
                maxH = 0
            }
            maxH = max(maxH, size.height)
            x += size.width + spacing
        }
        height = y + maxH
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += maxH + spacing
                x = bounds.minX
                maxH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxH = max(maxH, size.height)
            x += size.width + spacing
        }
    }
}
