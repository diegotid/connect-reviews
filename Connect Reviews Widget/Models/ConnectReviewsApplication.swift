//
//  ConnectReviewsApplication.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import Foundation

struct ConnectReviewsApplication: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let iconURL: URL?
    let iconData: Data?
    let averageRating: Double?
    let totalRatingsCount: Int?
}
