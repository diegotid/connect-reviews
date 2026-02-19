//
//  AppIcon.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 19/2/26.
//

import SwiftUI
import AppKit
import Combine

struct AppIcon: View {
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

        var cropRect = CGRect(
            x: minX,
            y: minY,
            width: (maxX - minX + 1),
            height: (maxY - minY + 1)
        )

        if cropRect.width != cropRect.height {
            let squareSize = max(cropRect.width, cropRect.height)
            let midX = cropRect.midX
            let midY = cropRect.midY
            cropRect = CGRect(
                x: midX - squareSize / 2,
                y: midY - squareSize / 2,
                width: squareSize,
                height: squareSize
            ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        }

        if Int(cropRect.width) == width && Int(cropRect.height) == height {
            return self
        }

        return cropping(to: cropRect) ?? self
    }
}
