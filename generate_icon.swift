#!/usr/bin/swift
import CoreGraphics
import Foundation
import ImageIO

func makeIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // ── Background ───────────────────────────────────────────
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                         cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()
    let grad = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red: 0.14, green: 0.16, blue: 0.28, alpha: 1),
                 CGColor(red: 0.09, green: 0.10, blue: 0.20, alpha: 1)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: s / 2, y: s), end: CGPoint(x: s / 2, y: 0), options: [])
    ctx.resetClip()

    // ── Keyboard body ────────────────────────────────────────
    let kX = s * 0.09, kY = s * 0.27, kW = s * 0.82, kH = s * 0.46
    let pad = s * 0.028, gap = s * 0.016
    let rowH = (kH - pad * 2 - gap * 3) / 4

    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.04,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
    ctx.setFillColor(CGColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: kX, y: kY, width: kW, height: kH),
                        cornerWidth: s * 0.05, cornerHeight: s * 0.05, transform: nil))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // ── Key rows ─────────────────────────────────────────────
    let keyC = CGColor(red: 0.22, green: 0.25, blue: 0.42, alpha: 0.85)

    func drawRow(y: CGFloat, count: Int, leftW: CGFloat = 0) {
        let extra = leftW > 0 ? leftW + gap : 0
        let avail = kW - pad * 2 - extra
        let kw = (avail - gap * CGFloat(count - 1)) / CGFloat(count)
        var x = kX + pad
        if leftW > 0 {
            ctx.setFillColor(keyC)
            ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: leftW, height: rowH),
                                cornerWidth: rowH * 0.25, cornerHeight: rowH * 0.25, transform: nil))
            ctx.fillPath()
            x += leftW + gap
        }
        for _ in 0..<count {
            ctx.setFillColor(keyC)
            ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: kw, height: rowH),
                                cornerWidth: rowH * 0.25, cornerHeight: rowH * 0.25, transform: nil))
            ctx.fillPath()
            x += kw + gap
        }
    }

    drawRow(y: kY + pad,                  count: 10)
    drawRow(y: kY + pad + (rowH + gap),   count: 10)
    drawRow(y: kY + pad + (rowH + gap) * 2, count: 9, leftW: s * 0.10)
    drawRow(y: kY + pad + (rowH + gap) * 3, count: 7, leftW: s * 0.14)

    // ── Orange lock badge ────────────────────────────────────
    let br = s * 0.19, bCX = s * 0.695, bCY = s * 0.695

    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.025,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.setFillColor(CGColor(red: 1.0, green: 0.58, blue: 0.04, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: bCX - br, y: bCY - br, width: br * 2, height: br * 2))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Lock body
    let lBW = br * 0.75, lBH = br * 0.60
    let lBX = bCX - lBW / 2, lBY = bCY - br * 0.50
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: lBX, y: lBY, width: lBW, height: lBH),
                        cornerWidth: lBW * 0.18, cornerHeight: lBW * 0.18, transform: nil))
    ctx.fillPath()

    // Shackle — clockwise=true in CGContext Y-up draws the arch upward (north)
    let shR = lBW * 0.28
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(br * 0.14)
    ctx.setLineCap(.round)
    let shPath = CGMutablePath()
    shPath.addArc(center: CGPoint(x: bCX, y: lBY + lBH),
                  radius: shR, startAngle: .pi, endAngle: 0, clockwise: true)
    ctx.addPath(shPath)
    ctx.strokePath()

    // Keyhole dot
    let khR = lBH * 0.13
    ctx.setFillColor(CGColor(red: 1.0, green: 0.58, blue: 0.04, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: bCX - khR, y: lBY + lBH * 0.25, width: khR * 2, height: khR * 2))

    return ctx.makeImage()
}

func save(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { print("Failed to create destination for \(path)"); return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("✓ \(path)")
}

let iconDir = "/Users/digiman/Developer/keylock/KeyLock/Assets.xcassets/AppIcon.appiconset"

// Generate at 1024, then resize with sips for all other sizes
if let icon1024 = makeIcon(size: 1024) {
    save(icon1024, to: "\(iconDir)/icon_1024.png")
}

let resizeSizes = [16, 32, 64, 128, 256, 512]
for sz in resizeSizes {
    if let img = makeIcon(size: sz) {
        save(img, to: "\(iconDir)/icon_\(sz).png")
    }
}
