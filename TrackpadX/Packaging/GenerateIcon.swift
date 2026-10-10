import CoreGraphics
import CoreServices
import Foundation
import ImageIO

// 生成 TrackpadX 应用图标: macOS 27 风格圆角底板 + 触控板 + 三指下滑图形
// 用法: swiftc GenerateIcon.swift -o /tmp/genicon && /tmp/genicon <输出目录>

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// MARK: - 底板 (Big Sur 规范: 1024 画布, 824 图形, 圆角 ~185)
let artRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let outer = CGPath(
    roundedRect: artRect,
    cornerWidth: 185,
    cornerHeight: 185,
    transform: nil
)

ctx.saveGState()
ctx.addPath(outer)
ctx.clip()

// 背景渐变: 冷灰白 → 淡雾蓝
let bgColors = [
    CGColor(srgbRed: 0.976, green: 0.980, blue: 0.988, alpha: 1),
    CGColor(srgbRed: 0.878, green: 0.898, blue: 0.941, alpha: 1),
] as CFArray
let bgGradient = CGGradient(
    colorsSpace: space,
    colors: bgColors,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 512, y: 924),
    end: CGPoint(x: 512, y: 100),
    options: []
)
ctx.restoreGState()

// 底板内描边 (高光感)
ctx.saveGState()
ctx.addPath(outer)
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.65))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

// MARK: - 触控板本体 (深板岩底)
let pad = CGRect(x: 262, y: 190, width: 500, height: 480)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: pad, cornerWidth: 56, cornerHeight: 56, transform: nil))
ctx.clip()

let padColors = [
    CGColor(srgbRed: 0.192, green: 0.216, blue: 0.271, alpha: 1),
    CGColor(srgbRed: 0.133, green: 0.149, blue: 0.200, alpha: 1),
] as CFArray
let padGradient = CGGradient(colorsSpace: space, colors: padColors, locations: [0, 1])!
ctx.drawLinearGradient(padGradient, start: CGPoint(x: 512, y: 670), end: CGPoint(x: 512, y: 190), options: [])
ctx.restoreGState()

// 触控板细描边
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: pad, cornerWidth: 56, cornerHeight: 56, transform: nil))
ctx.setStrokeColor(CGColor(srgbRed: 0.45, green: 0.50, blue: 0.60, alpha: 0.55))
ctx.setLineWidth(5)
ctx.strokePath()
ctx.restoreGState()

// MARK: - 三根手指 (蓝色胶囊, 三指呈下滑微错位)
let fingerWidth: CGFloat = 62
let fingerHeight: CGFloat = 150
let fingerRadius: CGFloat = 31
let fingerXs: [CGFloat] = [398, 512, 626]
// 中指略微领先(已在下方), 错落感
let fingerYs: [CGFloat] = [560, 512, 556]   // 中最低(领先下滑)

for (i, fx) in fingerXs.enumerated() {
    let frame = CGRect(x: fx - fingerWidth / 2, y: fingerYs[i], width: fingerWidth, height: fingerHeight)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: frame, cornerWidth: fingerRadius, cornerHeight: fingerRadius, transform: nil))
    ctx.clip()
    let fingerColors = [
        CGColor(srgbRed: 0.055, green: 0.55, blue: 1.0, alpha: 1),
        CGColor(srgbRed: 0.02, green: 0.36, blue: 0.80, alpha: 1),
    ] as CFArray
    let fg = CGGradient(colorsSpace: space, colors: fingerColors, locations: [0, 1])!
    ctx.drawLinearGradient(fg, start: CGPoint(x: fx, y: fingerYs[i] + fingerHeight), end: CGPoint(x: fx, y: fingerYs[i]), options: [])
    ctx.restoreGState()

    // 指尖高光
    let glow = CGRect(x: fx - 16, y: fingerYs[i] + fingerHeight - 22, width: 32, height: 16)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: glow, cornerWidth: 8, cornerHeight: 8, transform: nil))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.fillPath()
    ctx.restoreGState()
}

// MARK: - 下滑箭头 (触控板下部, 白色双弧 chevron)
ctx.saveGState()
let stroke = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85)
ctx.setStrokeColor(stroke)
ctx.setLineWidth(30)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let chevronYs: [CGRect] = [
    CGRect(x: 432, y: 380, width: 160, height: 70),
    CGRect(x: 432, y: 300, width: 160, height: 70),
]
for r in chevronYs {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: r.minX, y: r.maxY))
    path.addLine(to: CGPoint(x: r.midX, y: r.minY))
    path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
    ctx.addPath(path)
}
ctx.strokePath()
ctx.restoreGState()

// MARK: - 输出 PNG
let image = ctx.makeImage()!
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let outURL = URL(fileURLWithPath: outDir).appendingPathComponent("icon_1024.png")

let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("icon written: \(outURL.path)")
