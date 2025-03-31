//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import func AVFoundation.AVMakeRect
import Foundation
#if os(iOS) || os(tvOS)
#if os(iOS) || os(tvOS)
import UIKit
#endif
#elseif os(macOS)
import AppKit
#endif

#if os(iOS) || os(tvOS)
public typealias PlatformImage = UIImage
#elseif os(macOS)
public typealias PlatformImage = NSImage
#else
#warning("PlatformImage not defined for this platform")
public typealias PlatformImage = NSObject
#endif

#if os(iOS) || os(tvOS)
extension UIImage {
    /// Scales this image to fit the given `maxSize`.
    func scaleToFit(maxSize: CGSize) -> UIImage {
        if size.width <= maxSize.width, size.height <= maxSize.height {
            return self
        }

        let targetRect = AVMakeRect(aspectRatio: size, insideRect: CGRect(origin: .zero, size: maxSize))
        let renderer = UIGraphicsImageRenderer(size: targetRect.size)
        return renderer.image { _ in
            draw(in: targetRect)
        }
    }
}
#elseif os(macOS)
extension NSImage {
    /// Scales this image to fit the given `maxSize`.
    func scaleToFit(maxSize: CGSize) -> NSImage {
        if size.width <= maxSize.width, size.height <= maxSize.height {
            return self
        }

        let targetRect = AVMakeRect(aspectRatio: size, insideRect: NSRect(origin: .zero, size: maxSize))

        // Create a new NSImage with the target size
        let newImage = NSImage(size: targetRect.size)

        // Lock focus on the new image to draw into it
        newImage.lockFocus()

        // Get the current graphics context
        guard let context = NSGraphicsContext.current else {
            newImage.unlockFocus()
            return self // Return original on error
        }

        // Set image interpolation quality
        context.imageInterpolation = .high

        // Draw the original image into the target rectangle
        // The source rect is the entire original image
        // Operation copy ensures transparency is handled correctly
        // Fraction 1.0 ensures it's fully opaque
        self.draw(in: targetRect, from: NSRect(origin: .zero, size: self.size), operation: .copy, fraction: 1.0)

        // Unlock focus to finalize the drawing
        newImage.unlockFocus()

        return newImage
    }
}
#endif
