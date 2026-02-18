//
//  ContentView.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 16/2/26.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @StateObject private var store = ConnectStore()
    @State private var selectedAppID: String?

    private var selectedApp: ConnectApp? {
        guard let selectedAppID else { return nil }
        return store.apps.first(where: { $0.id == selectedAppID })
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SidebarHeaderView(
                    title: store.vendorDisplayName,
                    subtitle: "Ready for Sale"
                )

                List(store.apps, selection: $selectedAppID) { app in
                    HStack(spacing: 12) {
                        AppIconView(url: app.iconURL, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.headline)
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(app.id)
                }
            }
            .navigationTitle("")
        } detail: {
            Group {
                if store.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading App Store Connect data...")
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = store.errorMessage {
                    VStack(spacing: 10) {
                        Text("Failed to load")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }
                    .padding()
                } else if let app = selectedApp {
                    AppDetailView(app: app)
                } else if let firstApp = store.apps.first {
                    AppDetailView(app: firstApp)
                } else {
                    ContentUnavailableView("No apps found", systemImage: "app.badge")
                }
            }
            .navigationTitle(selectedApp?.name ?? "Connect Reviews")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                    .disabled(store.isLoading)
                }
            }
        }
        .task {
            await store.refresh()
            if selectedAppID == nil {
                selectedAppID = store.apps.first?.id
            }
        }
        .onChange(of: store.apps) { _ in
            if let selectedAppID, store.apps.contains(where: { $0.id == selectedAppID }) {
                return
            }
            self.selectedAppID = store.apps.first?.id
        }
    }
}

#Preview {
    ContentView()
}

private struct SidebarHeaderView: View {
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

private struct AppDetailView: View {
    let app: ConnectApp
    private let reviewStarSize: CGFloat = 16
    private let summaryStarScale: CGFloat = 1.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    AppIconView(url: app.iconURL, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2.bold())
                        Text(app.bundleID)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    AverageRatingIndicatorView(
                        rating: app.averageRating,
                        starSize: reviewStarSize * summaryStarScale
                    )
                }

                GroupBox("Reviews") {
                    if app.reviews.isEmpty {
                        Text("No reviews found.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(app.reviews) { review in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        StarRatingView(rating: Double(review.rating), size: reviewStarSize)
                                        Text("(\(review.rating))")
                                            .foregroundStyle(.secondary)
                                        Text(review.territoryCode)
                                            .font(.system(.caption, design: .monospaced))
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
                                .padding(.vertical, 8)

                                Divider()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct AverageRatingIndicatorView: View {
    let rating: Double?
    let starSize: CGFloat

    init(rating: Double?, starSize: CGFloat = 24) {
        self.rating = rating
        self.starSize = starSize
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            StarRatingView(rating: rating, size: starSize)

            Text(rating.map { String(format: "%.2f", $0) } ?? "N/A")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Average rating")
        .accessibilityValue(rating.map { String(format: "%.2f out of 5", $0) } ?? "Unavailable")
    }
}

private struct StarRatingView: View {
    let rating: Double?
    let size: CGFloat

    private var clampedRating: Double {
        min(max(rating ?? 0, 0), 5)
    }

    private func starValue(at index: Int) -> Double {
        min(max(clampedRating - Double(index), 0), 1)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let value = starValue(at: index)
                ZStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.gray.opacity(0.2))
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(value))
                }
            }
        }
        .font(.system(size: size, weight: .semibold))
    }
}

private struct AppIconView: View {
    let url: URL?
    let size: CGFloat
    @StateObject private var loader = AppIconLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if url != nil {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .fill(.quinary)
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(.quinary)
                    .overlay {
                        Image(systemName: "app")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(.black.opacity(0.08))
        }
        .task(id: url) {
            await loader.load(url: url)
        }
    }
}

@MainActor
private final class AppIconLoader: ObservableObject {
    @Published var image: NSImage?
    private static let cache = NSCache<NSURL, NSImage>()

    func load(url: URL?) async {
        guard let url else {
            image = nil
            return
        }

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        image = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }
            guard
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode),
                let decoded = NSImage(data: data)
            else {
                image = nil
                return
            }

            let processed = decoded.croppingTransparentPadding() ?? decoded
            Self.cache.setObject(processed, forKey: url as NSURL)
            image = processed
        } catch {
            image = nil
        }
    }
}

private extension NSImage {
    func croppingTransparentPadding(alphaThreshold: UInt8 = 2) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let cropped = cgImage.croppingTransparentPadding(alphaThreshold: alphaThreshold) else { return nil }
        return NSImage(
            cgImage: cropped,
            size: NSSize(width: cropped.width, height: cropped.height)
        )
    }
}

private extension CGImage {
    func croppingTransparentPadding(alphaThreshold: UInt8) -> CGImage? {
        let width = self.width
        let height = self.height
        guard width > 0, height > 0 else { return self }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else {
            return self
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let alpha = pixels[rowOffset + (x * bytesPerPixel) + 3]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return self }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: (maxX - minX + 1),
            height: (maxY - minY + 1)
        )

        if Int(cropRect.width) == width && Int(cropRect.height) == height {
            return self
        }

        return cropping(to: cropRect) ?? self
    }
}
