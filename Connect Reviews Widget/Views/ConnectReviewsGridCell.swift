//
//  ConnectReviewsGridCell.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import SwiftUI
import Foundation

struct ConnectReviewsGridCell: View {
    let app: ConnectReviewsApplication

    private var ratingText: String? {
        guard let averageRating = app.averageRating else {
            return nil
        }
        return String(format: "%.1f", averageRating)
    }

    var body: some View {
        VStack(alignment: .center) {
            Text(app.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: -18)
            
            WidgetStarRating(rating: app.averageRating ?? 0,
                             size: 8,
                             ratingCount: nil,
                             showRating: false)
            
            Spacer(minLength: -18)
            
            if let ratingText {
                Text(ratingText)
                    .font(.system(size: 50, weight: .bold, design: .default))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "star.slash")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not yet rated")
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
        .padding(.bottom, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.quinary)
        )
    }
}
