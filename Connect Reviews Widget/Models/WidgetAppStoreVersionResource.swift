//
//  WidgetAppStoreVersionResource.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

struct WidgetAppStoreVersionResource: Decodable {
    let attributes: Attributes

    struct Attributes: Decodable {
        let appStoreState: String?
    }
}
