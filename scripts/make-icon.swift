import AppKit
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let shape = NSBezierPath(roundedRect: NSRect(x: 65, y: 65, width: 894, height: 894), xRadius: 205, yRadius: 205)
    NSGradient(starting: NSColor(red: 0.12, green: 0.17, blue: 0.26, alpha: 1), ending: NSColor(red: 0.035, green: 0.055, blue: 0.10, alpha: 1))!.draw(in: shape, angle: -90)
    NSColor(white: 1, alpha: 0.12).setStroke(); shape.lineWidth = 3; shape.stroke()
    let heights: [CGFloat] = [140, 290, 455, 340, 200]
    for (index, height) in heights.enumerated() {
        let rect = NSRect(x: 282 + CGFloat(index) * 96, y: (1024-height)/2, width: 64, height: height)
        let bar = NSBezierPath(roundedRect: rect, xRadius: 32, yRadius: 32)
        NSGradient(starting: NSColor(red: 0.48, green: 0.94, blue: 0.87, alpha: 1), ending: NSColor(red: 0.24, green: 0.62, blue: 1, alpha: 1))!.draw(in: bar, angle: 90)
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
}
