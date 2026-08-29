//
//  ImageCropView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 29/08/26.
//


//
//  ImageCropView.swift
//  Jeopardy
//
//  A minimal drag-to-move / drag-corners-to-resize crop tool. Used by
//  ClueFormView whenever an image is attached (file picker, drop, or
//  paste), so the Host can crop the visible clue image while optionally
//  keeping the full uncropped original for the Answer Image.
//

import SwiftUI
import AppKit

struct ImageCropView: View {
    let originalImage: NSImage
    @Binding var alsoUseFullAsAnswerImage: Bool

    /// Cropped image data (PNG).
    let onCrop: (Data) -> Void
    /// Full, uncropped image data (PNG) — chosen when the Host skips cropping.
    let onUseFullImage: (Data) -> Void
    let onCancel: () -> Void

    @State private var cropRect: CGRect = .zero
    @State private var displayFrame: CGRect = .zero
    
    // NEW — track the rect as it was when this drag began
    @State private var moveStartRect: CGRect?
    @State private var resizeStartRect: CGRect?

    private let handleSize: CGFloat = 14
    private let minCropSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 16) {
            Text("Crop Image")
                .font(.headline)

            GeometryReader { geo in
                let frame = fittedFrame(for: originalImage.size, in: geo.size)

                ZStack {
                    Image(nsImage: originalImage)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geo.size))
                        path.addRect(cropRect)
                    }
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                        .gesture(moveGesture(bounds: frame))

                    ForEach(Corner.allCases, id: \.self) { corner in
                        Circle()
                            .fill(Color.white)
                            .frame(width: handleSize, height: handleSize)
                            .position(corner.point(in: cropRect))
                            .gesture(resizeGesture(corner: corner, bounds: frame))
                    }
                }
                .onAppear {
                    displayFrame = frame
                    if cropRect == .zero {
                        cropRect = frame.insetBy(dx: frame.width * 0.15, dy: frame.height * 0.15)
                    }
                }
            }
            .frame(minWidth: 480, minHeight: 340)
            .clipped()

            Toggle("Also save the uncropped image as the Answer Image", isOn: $alsoUseFullAsAnswerImage)
                .toggleStyle(.checkbox)

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Skip Crop, Use Full Image") {
                    if let data = originalImage.pngData() { onUseFullImage(data) }
                }
                Button("Crop") { performCrop() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 560, height: 460)
    }

    // MARK: - Layout

    private func fittedFrame(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (container.width - fitted.width) / 2, y: (container.height - fitted.height) / 2)
        return CGRect(origin: origin, size: fitted)
    }

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
            case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }
    }

    private func moveGesture(bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)   // 0 avoids an initial jump when the drag threshold is crossed
            .onChanged { value in
                let start = moveStartRect ?? cropRect
                if moveStartRect == nil { moveStartRect = cropRect }
                var rect = start
                rect.origin.x += value.translation.width
                rect.origin.y += value.translation.height
                cropRect = clampMove(rect, in: bounds)
            }
            .onEnded { _ in moveStartRect = nil }
    }

    private func resizeGesture(corner: Corner, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = resizeStartRect ?? cropRect
                if resizeStartRect == nil { resizeStartRect = cropRect }
                var rect = start

                switch corner {
                case .topLeft:
                    rect.origin.x = start.origin.x + value.translation.width
                    rect.origin.y = start.origin.y + value.translation.height
                    rect.size.width = start.size.width - value.translation.width
                    rect.size.height = start.size.height - value.translation.height
                case .topRight:
                    rect.origin.y = start.origin.y + value.translation.height
                    rect.size.width = start.size.width + value.translation.width
                    rect.size.height = start.size.height - value.translation.height
                case .bottomLeft:
                    rect.origin.x = start.origin.x + value.translation.width
                    rect.size.width = start.size.width - value.translation.width
                    rect.size.height = start.size.height + value.translation.height
                case .bottomRight:
                    rect.size.width = start.size.width + value.translation.width
                    rect.size.height = start.size.height + value.translation.height
                }

                if rect.width >= minCropSize, rect.height >= minCropSize {
                    cropRect = clampResize(rect, in: bounds)
                }
            }
            .onEnded { _ in resizeStartRect = nil }
    }

    // Replace the old single `clamp(_:in:)` with two purpose-built versions —
    // clamping a resize by scaling dimensions (the old shared clamp) caused
    // its own jump whenever a resized rect touched a bound.
    private func clampMove(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var r = rect
        r.origin.x = max(bounds.minX, min(r.origin.x, bounds.maxX - r.width))
        r.origin.y = max(bounds.minY, min(r.origin.y, bounds.maxY - r.height))
        return r
    }

    private func clampResize(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var r = rect
        r.origin.x = max(bounds.minX, r.origin.x)
        r.origin.y = max(bounds.minY, r.origin.y)
        r.size.width = min(r.size.width, bounds.maxX - r.origin.x)
        r.size.height = min(r.size.height, bounds.maxY - r.origin.y)
        return r
    }

    // MARK: - Crop execution

    private func performCrop() {
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              displayFrame.width > 0, displayFrame.height > 0 else {
            onCancel()
            return
        }

        let scaleX = CGFloat(cgImage.width) / displayFrame.width
        let scaleY = CGFloat(cgImage.height) / displayFrame.height

        let pixelRect = CGRect(
            x: (cropRect.minX - displayFrame.minX) * scaleX,
            y: (cropRect.minY - displayFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else {
            onCancel()
            return
        }

        let resultImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        if let data = resultImage.pngData() {
            onCrop(data)
        }
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
