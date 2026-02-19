//
//  StarRating.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 19/2/26.
//


import SwiftUI

struct StarRating: View {
    let rating: Double
    let ratingCount: Int?
    let showLabel: Bool
    let size: CGFloat
    
    init(
        rating: Double,
        ratingCount: Int? = nil,
        showLabel: Bool = true,
        size: CGFloat
    ) {
        self.rating = rating
        self.ratingCount = ratingCount
        self.showLabel = showLabel
        self.size = size
    }

    private var clampedRating: Double {
        min(max(rating, 0), 5)
    }

    private func starValue(at index: Int) -> Double {
        min(max(clampedRating - Double(index), 0), 1)
    }

    var body: some View {
        HStack(spacing: 2) {
            if showLabel {
                Text(String(format: "%.1f", rating))
                    .bold()
                    .foregroundStyle(.secondary)
                    .font(.system(size: size * 1.3))
                    .padding(.trailing, size / 4)
            }
            if let count = ratingCount {
                Text("(\(count))")
                    .foregroundStyle(.secondary)
                    .font(.system(size: size * 1.3, weight: .ultraLight))
                    .padding(.trailing, size / 4)
            }
            ForEach(0..<5, id: \.self) { index in
                let value = starValue(at: index)
                ZStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.gray.opacity(0.2))
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(value * 0.75))
                }
            }
            .padding(.top, -2)
        }
        .font(.system(size: size, weight: .semibold))
    }
}

#Preview {
    StarRating(rating: 4.2, ratingCount: 12, size: 24.0)
}
