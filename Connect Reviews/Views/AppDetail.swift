//
//  AppDetail.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 19/2/26.
//

import SwiftUI

struct AppDetail: View {
    let app: ConnectApp
    private let reviewStarSize: CGFloat = 16
    private let summaryStarScale: CGFloat = 1.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    AppIcon(url: app.iconURL, size: 64)
                    Spacer(minLength: 12)
                    if let averageRating = app.averageRating {
                        StarRating(
                            rating: averageRating,
                            ratingCount: app.totalRatingsCount,
                            size: reviewStarSize * summaryStarScale
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Average rating")
                        .accessibilityValue(String(format: "%.2f out of 5", averageRating))
                    }
                }
                if app.reviews.isEmpty {
                    GroupBox {
                        Text("No reviews found")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(app.reviews) { review in
                            GroupBox {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        StarRating(rating: Double(review.rating),
                                                   showLabel: false,
                                                   size: reviewStarSize)
                                        Text(flag(from: review.territoryCode))
                                            .font(.title)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if let date = review.createdDate {
                                            Text(date, style: .date)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if let title = review.title, !title.isEmpty {
                                        Text(title)
                                            .font(.headline)
                                    }
                                    if let body = review.body, !body.isEmpty {
                                        Text(body)
                                            .font(.body)
                                    }
                                    if let reviewer = review.reviewerNickname, !reviewer.isEmpty {
                                        Text("by \(reviewer)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(8)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }

    private func flag(from territoryCode: String) -> String {
        let code = territoryCode.uppercased()
        guard code.count == 2 else { return territoryCode }
        let base: UInt32 = 127397
        var scalars = String.UnicodeScalarView()
        for scalar in code.unicodeScalars {
            guard scalar.properties.isAlphabetic, let flagScalar = UnicodeScalar(base + scalar.value) else {
                return territoryCode
            }
            scalars.append(flagScalar)
        }
        return String(scalars)
    }
}

#Preview {
    let localRating = TerritoryRating(territoryCode: "ES",
                                      reviewCount: 3,
                                      averageRating: 4.8)
    let appReview = AppReview(id: "222",
                              rating: 4,
                              territoryCode: "ES",
                              title: nil,
                              body: nil,
                              reviewerNickname: nil,
                              createdDate: nil)
    let app = ConnectApp(id: "123456789",
                         name: "Connect Reviews",
                         bundleID: "studio.cuatro.connect",
                         appStoreStates: ["READY_FOR_SALE"],
                         primaryAppStoreState: nil,
                         iconURL: nil,
                         ratingsByTerritory: [localRating],
                         hasAllRatingsCoverage: true,
                         totalRatingsCount: 5,
                         ratingsFromReviewsCount: 2,
                         ratingsWithoutReviewCount: nil,
                         textReviewCount: 2,
                         averageRating: nil,
                         reviews: [appReview])
    AppDetail(app: app)
}
