// render_app_icon.swift
// Draws the CloudNote AI app icon (1024×1024 PNG). Not part of the app build.
//
// Regenerate all three versions from the repository root:
//   swiftc -O -o /tmp/render_app_icon Design/render_app_icon.swift
//   A=Notes/Assets.xcassets/AppIcon.appiconset
//   /tmp/render_app_icon light  $A/AppIcon.png
//   /tmp/render_app_icon dark   $A/AppIcon-Dark.png
//   /tmp/render_app_icon tinted $A/AppIcon-Tinted.png
// Then resize AppIcon.png to 96, 192 and 288 px for Notes/Assets.xcassets/logo.imageset.
//
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let variant = CommandLine.arguments[1]
let output = URL(fileURLWithPath: CommandLine.arguments[2])

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                    bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Work in top-left coordinates.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// MARK: Palette per variant

let isLight = variant == "light"
let isDark = variant == "dark"
let isTinted = variant == "tinted"

// MARK: Background

let full = CGRect(x: 0, y: 0, width: size, height: size)
if isLight {
    ctx.drawLinearGradient(gradient([rgb(0x6C4CF5), rgb(0x3B82F6), rgb(0x22C3EE)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
    // Soft light from the top left, like the glass of a modern icon.
    ctx.drawRadialGradient(gradient([rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0)]),
                           startCenter: CGPoint(x: 260, y: 140), startRadius: 0,
                           endCenter: CGPoint(x: 260, y: 140), endRadius: 760, options: [])
} else if isTinted {
    ctx.setFillColor(rgb(0x000000))
    ctx.fill(full)
}
// Dark: transparent background; the system draws its own dark backdrop.

// MARK: Cloud

/// The cloud as separate shapes; filled together inside one transparency layer
/// so the shadow and gradient treat them as one silhouette.
/// Shifts the whole design left a little so cloud and sparkle sit centered together.
let dx: CGFloat = -26
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - r + dx, y: cy - r, width: r * 2, height: r * 2), transform: nil)
}
/// Side puffs share one bottom line (y = 750), and the base fills between their
/// centers, so the outline is smooth all the way around.
let cloudShapes: [CGPath] = [
    circle(360, 580, 170),                       // left puff
    circle(540, 480, 205),                       // big top puff
    circle(690, 600, 150),                       // right puff
    CGPath(rect: CGRect(x: 360 + dx, y: 580, width: 330, height: 170), transform: nil),  // base
]
let cloud = CGMutablePath()
cloudShapes.forEach { cloud.addPath($0) }

ctx.saveGState()
if isLight {
    ctx.setShadow(offset: CGSize(width: 0, height: -28), blur: 60, color: rgb(0x1E1A6E, 0.38))
} else if isDark {
    ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 50, color: rgb(0x000000, 0.45))
}
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
for shape in cloudShapes {
    ctx.addPath(shape)
    ctx.fillPath()
}
// Paint the union with a gentle top-to-bottom gradient.
ctx.setBlendMode(.sourceIn)
let cloudColors: [CGColor] = isTinted
    ? [rgb(0xFFFFFF), rgb(0xE6E6E6)]
    : isDark ? [rgb(0xF4F6FF), rgb(0xD9E0FF)] : [rgb(0xFFFFFF), rgb(0xEAF0FF)]
ctx.drawLinearGradient(gradient(cloudColors), start: CGPoint(x: 0, y: 275), end: CGPoint(x: 0, y: 750), options: [])
ctx.setBlendMode(.normal)
ctx.endTransparencyLayer()
ctx.restoreGState()

// MARK: Note lines inside the cloud

let lineHeight: CGFloat = 40
let lines: [CGRect] = [
    CGRect(x: 330 + dx, y: 538, width: 372, height: lineHeight),
    CGRect(x: 330 + dx, y: 608, width: 372, height: lineHeight),
    CGRect(x: 330 + dx, y: 678, width: 236, height: lineHeight),
]
ctx.saveGState()
let linesPath = CGMutablePath()
for line in lines {
    linesPath.addPath(CGPath(roundedRect: line, cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil))
}
ctx.addPath(linesPath)
ctx.clip()
let lineColors: [CGColor] = isTinted
    ? [rgb(0x6E6E6E), rgb(0x5A5A5A)]
    : [rgb(0x6C4CF5), rgb(0x2E8BF0)]
ctx.drawLinearGradient(gradient(lineColors), start: CGPoint(x: 330 + dx, y: 0), end: CGPoint(x: 702 + dx, y: 0), options: [])
ctx.restoreGState()

// MARK: AI sparkle

/// A four-pointed star with curved sides.
func sparkle(center c: CGPoint, radius r: CGFloat, pinch: CGFloat = 0.16) -> CGPath {
    let p = CGMutablePath()
    let k = r * pinch
    p.move(to: CGPoint(x: c.x, y: c.y - r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
    p.closeSubpath()
    return p
}

func drawSparkle(_ path: CGPath, colors: [CGColor], glow: Bool) {
    let box = path.boundingBox
    ctx.saveGState()
    if glow {
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 36, color: rgb(0xB45309, 0.45))
    }
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient(colors), start: CGPoint(x: box.minX, y: box.minY),
                           end: CGPoint(x: box.maxX, y: box.maxY), options: [])
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

let sparkleColors: [CGColor] = isTinted
    ? [rgb(0xF2F2F2), rgb(0xBDBDBD)]
    : [rgb(0xFFE57A), rgb(0xFFB443), rgb(0xFF8A3D)]
drawSparkle(sparkle(center: CGPoint(x: 770 + dx, y: 318), radius: 130), colors: sparkleColors, glow: !isTinted)
drawSparkle(sparkle(center: CGPoint(x: 884 + dx, y: 470), radius: 52), colors: sparkleColors, glow: !isTinted)

// MARK: Write PNG

var image = ctx.makeImage()!
if variant != "dark" {
    // The App Store rejects app icons with an alpha channel: flatten to opaque RGB.
    let opaque = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                           bytesPerRow: 0, space: space,
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(image, in: full)
    image = opaque.makeImage()!
}
let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(output.path)")
