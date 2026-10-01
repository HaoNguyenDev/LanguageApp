//
//  FlowLayout.swift
//  LanguageApp
//
//  Lays out children left to right and wraps to the next line (word chips, sentence tiles).
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private struct Row {
        var items: [(index: Int, x: CGFloat)] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(maxWidth: bounds.width, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                                           proposal: .unspecified)
            }
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        guard !subviews.isEmpty else { return [] }
        var rows = [Row()]
        var x: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                let previous = rows[rows.count - 1]
                rows.append(Row(y: previous.y + previous.height + lineSpacing))
                x = 0
            }
            rows[rows.count - 1].items.append((index: index, x: x))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            rows[rows.count - 1].width = x + size.width
            x += size.width + spacing
        }
        return rows
    }
}
