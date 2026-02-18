//
//  SidebarHeader.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 19/2/26.
//

import SwiftUI

struct SidebarHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

#Preview {
    SidebarHeader(title: "Diego Rivera", subtitle: "Ready for Sale")
}
