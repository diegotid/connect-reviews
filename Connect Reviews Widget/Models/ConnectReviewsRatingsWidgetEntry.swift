//
//  ConnectReviewsRatingsWidgetEntry.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import WidgetKit

struct ConnectReviewsRatingsWidgetEntry: TimelineEntry {
    let date: Date
    let vendorName: String
    let apps: [ConnectReviewsApplication]
    let errorMessage: String?
}
