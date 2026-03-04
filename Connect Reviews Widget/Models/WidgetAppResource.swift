//
//  WidgetAppResource.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

struct WidgetAppResource: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let name: String
        let bundleId: String
    }
}
