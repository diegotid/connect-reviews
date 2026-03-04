//
//  ConnectReviewsWidgetBundle.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import SwiftUI
import WidgetKit

@main
struct ConnectReviewsWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ConnectReviewsGridWidget()
        ConnectReviewsRatingsWidget()
    }
}
