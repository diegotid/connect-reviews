//
//  ConnectReviewsWidgetConstants.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import Foundation

enum ConnectReviewsWidgetConstants {
    static let kind = "ConnectReviewsSidebarWidget"
    static let gridKind = "ConnectReviewsGridWidget"
    static let refreshInterval: TimeInterval = 6 * 60 * 60
    static let appGroupIdentifier = "group.studio.cuatro.connect"
    static let credentialsStorageKey = "app_store_connect_credentials_v1"
    static let appStoreConnectBaseURL = URL(string: "https://api.appstoreconnect.apple.com/v1/")!
    static let iTunesLookupURL = URL(string: "https://itunes.apple.com/lookup")!
    static let iTunesLookupEntity = "desktopSoftware"
    static let iTunesMainTerritoryCodes = [
        "US", "CA", "GB",
        "JP", "AU", "CN", "KR", "BR", "IN", "MX", "CH", "SG",
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
        "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
        "SI", "ES", "SE"
    ]

    static func sharedDefaults() -> UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: appGroupIdentifier)
    }
}
