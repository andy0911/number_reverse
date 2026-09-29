// アプリアイコン生成（1024×1024、アルファなし）。駒（チップ）を左右で先行=橙/後攻=緑に塗り分け、中央に「十」
// 使い方: swift scripts/make_icon.swift App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
import AppKit

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }

// 背景: 盤の濃紺グラデーション
let bg = CGGradient(colorsSpace: cs, colors: [c(0.10, 0.18, 0.34), c(0.04, 0.07, 0.15)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

let center = CGPoint(x: S / 2, y: S / 2 - 6)
let R: CGFloat = 360
let orange = c(0.95, 0.68, 0.10), green = c(0.10, 0.55, 0.40)

// 影
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 40, color: c(0, 0, 0, 0.55))
ctx.setFillColor(c(0, 0, 0)); ctx.fillEllipse(in: CGRect(x: center.x - R, y: center.y - R, width: 2 * R, height: 2 * R))
ctx.restoreGState()

// 左右塗り分け（表と裏＝先行と後攻）
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: center.x - R, y: center.y - R, width: 2 * R, height: 2 * R)); ctx.clip()
ctx.setFillColor(orange); ctx.fill(CGRect(x: 0, y: 0, width: center.x, height: S))
ctx.setFillColor(green); ctx.fill(CGRect(x: center.x, y: 0, width: S - center.x, height: S))
// 縁の刻み（カジノチップ）
ctx.setFillColor(c(1, 1, 1, 0.92))
for i in 0..<8 {
    let a = CGFloat(i) * .pi / 4 + .pi / 8
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: a)
    ctx.fill(CGRect(x: R - 70, y: -34, width: 80, height: 68))
    ctx.restoreGState()
}
// 光沢
let sheen = CGGradient(colorsSpace: cs, colors: [c(1, 1, 1, 0.28), c(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: center.x, y: center.y + R), end: CGPoint(x: center.x, y: center.y), options: [])
ctx.restoreGState()

// 中央の窪み
let r2: CGFloat = 212
ctx.setFillColor(c(0.99, 0.97, 0.93))
ctx.fillEllipse(in: CGRect(x: center.x - r2, y: center.y - r2, width: 2 * r2, height: 2 * r2))
ctx.setStrokeColor(c(0, 0, 0, 0.18)); ctx.setLineWidth(10)
ctx.strokeEllipse(in: CGRect(x: center.x - r2 + 5, y: center.y - r2 + 5, width: 2 * r2 - 10, height: 2 * r2 - 10))

// 「十」
let font = NSFont(name: "HiraginoSans-W8", size: 300) ?? NSFont.boldSystemFont(ofSize: 300)
let text = NSAttributedString(string: "十", attributes: [.font: font, .foregroundColor: NSColor(srgbRed: 0.10, green: 0.16, blue: 0.30, alpha: 1)])
let line = CTLineCreateWithAttributedString(text)
let b = CTLineGetImageBounds(line, ctx)
ctx.textPosition = CGPoint(x: center.x - b.midX, y: center.y - b.midY)
CTLineDraw(line, ctx)

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
