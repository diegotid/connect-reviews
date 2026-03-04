//
//  WidgetAppIcon.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import SwiftUI
import Foundation

struct WidgetAppIcon: View {
    let iconData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let iconData, let image = NSImage(data: iconData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                iconPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(.black.opacity(0.08))
        }
    }

    private var iconPlaceholder: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(.quinary)
            .overlay {
                Image(systemName: "app")
                    .foregroundStyle(.secondary)
            }
    }
}
