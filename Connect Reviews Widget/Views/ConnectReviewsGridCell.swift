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

    private var ratingText: String {
        guard let averageRating = app.averageRating else {
            return "—"
        }
        return String(format: "%.1f", averageRating)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(app.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(ratingText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quinary)
        )
    }
}
