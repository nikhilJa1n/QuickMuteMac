import Cocoa
import CoreGraphics

func processImage() {
    let inputPath = "quickmute_logo.jpg"
    let outputPath = "quickmute_logo_transparent.png"
    
    guard let image = NSImage(contentsOfFile: inputPath),
          let tiffData = image.tiffRepresentation,
          let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        print("Error: Could not load source image")
        return
    }
    
    let width = cgImage.width
    let height = cgImage.height
    
    // Get pixel bytes
    guard let colorSpace = cgImage.colorSpace,
          let context = CGContext(
              data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        print("Error: Could not create context")
        return
    }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let pixelData = context.data else {
        print("Error: Could not read pixel data")
        return
    }
    
    let buffer = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
    
    // Helper to get luminance at coordinate
    func getLuminance(x: Int, y: Int) -> Double {
        let offset = (y * width + x) * 4
        let r = buffer[offset]
        let g = buffer[offset + 1]
        let b = buffer[offset + 2]
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }
    
    // Use an offset scanning line (e.g. at 25% of width/height) to avoid the central white microphone icon.
    // The inner squircle is roughly in the center, so 25% width/height is inside the squircle but outside the icon.
    let scanLine = width / 4 // 256 for 1024x1024
    let consecutiveDarkRequired = 15
    
    // 1. Scan Left to Right to find Left boundary of inner squircle (at y = scanLine)
    var xMin = 0
    for x in 0..<(width - consecutiveDarkRequired) {
        var isSquircle = true
        for offset in 0..<consecutiveDarkRequired {
            if getLuminance(x: x + offset, y: scanLine) >= 120.0 {
                isSquircle = false
                break
            }
        }
        if isSquircle {
            xMin = x
            break
        }
    }
    
    // 2. Scan Right to Left to find Right boundary of inner squircle (at y = scanLine)
    var xMax = width
    for x in stride(from: width - 1, to: consecutiveDarkRequired, by: -1) {
        var isSquircle = true
        for offset in 0..<consecutiveDarkRequired {
            if getLuminance(x: x - offset, y: scanLine) >= 120.0 {
                isSquircle = false
                break
            }
        }
        if isSquircle {
            xMax = x
            break
        }
    }
    
    // 3. Scan Top to Bottom to find Top boundary of inner squircle (at x = scanLine)
    var yMin = 0
    for y in 0..<(height - consecutiveDarkRequired) {
        var isSquircle = true
        for offset in 0..<consecutiveDarkRequired {
            if getLuminance(x: scanLine, y: y + offset) >= 120.0 {
                isSquircle = false
                break
            }
        }
        if isSquircle {
            yMin = y
            break
        }
    }
    
    // 4. Scan Bottom to Top to find Bottom boundary of inner squircle (at x = scanLine)
    var yMax = height
    for y in stride(from: height - 1, to: consecutiveDarkRequired, by: -1) {
        var isSquircle = true
        for offset in 0..<consecutiveDarkRequired {
            if getLuminance(x: scanLine, y: y - offset) >= 120.0 {
                isSquircle = false
                break
            }
        }
        if isSquircle {
            yMax = y
            break
        }
    }
    
    let rectWidth = xMax - xMin
    let rectHeight = yMax - yMin
    let size = min(rectWidth, rectHeight)
    
    // Center the square cropping region
    let xOffset = xMin + (rectWidth - size) / 2
    let yOffset = yMin + (rectHeight - size) / 2
    
    print("Detected INNER squircle boundary: x=\(xOffset)...\(xOffset + size), y=\(yOffset)...\(yOffset + size), size=\(size)")
    
    // Crop the image
    guard let croppedImage = cgImage.cropping(to: CGRect(x: xOffset, y: yOffset, width: size, height: size)) else {
        print("Error: Could not crop image")
        return
    }
    
    // Create new transparent context for the cropped size
    guard let transparentContext = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Error: Could not create output context")
        return
    }
    
    // Apply macOS squircle mask (corner radius is 22.37% of size in Big Sur+)
    let cornerRadius = CGFloat(size) * 0.223
    let path = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    
    transparentContext.addPath(path)
    transparentContext.clip()
    transparentContext.draw(croppedImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    
    guard let finalCGImage = transparentContext.makeImage() else {
        print("Error: Could not generate final image")
        return
    }
    
    let finalNSImage = NSImage(cgImage: finalCGImage, size: NSSize(width: size, height: size))
    guard let pngData = finalNSImage.pngRepresentation else {
        print("Error: Could not encode PNG")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Successfully created transparent icon at: \(outputPath)")
    } catch {
        print("Error saving PNG file: \(error)")
    }
}

extension NSImage {
    var pngRepresentation: Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

processImage()
