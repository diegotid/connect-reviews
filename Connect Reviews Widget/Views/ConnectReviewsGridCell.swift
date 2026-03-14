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
    let style: Style

    private var ratingText: String? {
        guard let averageRating = app.averageRating else {
            return nil
        }
        return String(format: "%.1f", averageRating)
    }

    init(app: ConnectReviewsApplication, style: Style = .compact) {
        self.app = app
        self.style = style
    }

    var body: some View {
        VStack(alignment: .center, spacing: style.spacing) {
            Text(app.name)
                .font(style.titleFont)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.leading, style == .regular ? 2 : 0)
                .padding(.bottom, style == .regular ? -8 : 0)

            if let ratingText {
                ZStack {
                    HStack {
                        if style == .promoted {
                            Spacer()
                        }
                        Text(ratingText)
                            .font(.system(size: style.ratingFontSize, weight: .semibold, design: .default))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.bottom, style == .regular ? -9 : 0)
                        Spacer()
                    }
                    .padding(.leading, 3)
                    .padding(.bottom, -6)
                    if let count = app.totalRatingsCount {
                        VStack {
                            HStack {
                                Spacer()
                                Text("(\(count))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(maxHeight: style == .promoted ? 60 : 24)
                    }
                }
            } else {
                Image(systemName: "star.slash")
                    .font(.system(size: style.missingRatingFontSize))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not yet rated")
                    .opacity(0.6)
                    .padding(.top, 4)
                    .padding(.bottom, style == .regular ? -5 : 4)
                    .frame(height: style == .promoted ? 60 : 24)
            }

            WidgetStarRating(
                rating: app.averageRating ?? 0,
                size: style.starSize,
                ratingCount: nil,
                showRating: false
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: style == .regular ? 120 : .infinity,
            alignment: .center
        )
        .padding(style.padding)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(.quinary)
        )
    }
    
    enum Style: Equatable {
        case regular
        case compact
        case promoted
        case hero

        var titleFont: Font {
            switch self {
            case .regular:
                return .caption
            case .compact:
                return .system(size: 10, weight: .medium)
            case .promoted:
                return .system(size: 14, weight: .medium)
            case .hero:
                return .system(size: 13, weight: .medium)
            }
        }

        var ratingFontSize: CGFloat {
            switch self {
            case .regular:
                return 22
            case .compact:
                return 22
            case .promoted:
                return 48
            case .hero:
                return 36
            }
        }

        var missingRatingFontSize: CGFloat {
            switch self {
            case .regular:
                return 20
            case .compact:
                return 16
            case .promoted:
                return 28
            case .hero:
                return 26
            }
        }

        var starSize: CGFloat {
            switch self {
            case .regular:
                return 8
            case .compact:
                return 6
            case .promoted:
                return 12
            case .hero:
                return 9
            }
        }

        var padding: CGFloat {
            switch self {
            case .regular:
                return 6
            case .compact:
                return 6
            case .promoted:
                return 10
            case .hero:
                return 12
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .regular:
                return 20
            case .compact:
                return 16
            case .promoted:
                return 20
            case .hero:
                return 24
            }
        }

        var spacing: CGFloat {
            switch self {
            case .regular:
                return 8
            case .compact:
                return 2
            case .promoted:
                return 4
            case .hero:
                return 6
            }
        }
    }

}
