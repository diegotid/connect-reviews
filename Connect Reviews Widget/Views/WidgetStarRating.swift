//
//  WidgetStarRating.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import SwiftUI
import Foundation

struct WidgetStarRating: View {
    let rating: Double
    let ratingCount: Int?
    let size: CGFloat

    private var clampedRating: Double {
        min(max(rating, 0), 5)
    }

    private func starValue(at index: Int) -> Double {
        min(max(clampedRating - Double(index), 0), 1)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "%.1f", rating))
                .bold()
                .foregroundStyle(.secondary)
                .font(.system(size: size * 1.3))
                .padding(.trailing, size / 4)
            ForEach(0..<5, id: \.self) { index in
                let value = starValue(at: index)
                ZStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.gray.opacity(0.2))
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(value * 0.5))
                }
            }
            if let ratingCount {
                Text("(\(ratingCount))")
                    .font(.system(size: size * 1.25, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: size, weight: .semibold))
    }
}
