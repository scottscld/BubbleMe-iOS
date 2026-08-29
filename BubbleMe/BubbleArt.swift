import SpriteKit
import UIKit

enum BubbleArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(for color: BubbleColor, diameter: CGFloat) -> SKTexture {
        let key = "\(color.rawValue)-\(Int(diameter))"
        if let hit = cache[key] { return hit }
        let tex = SKTexture(image: render(color: uiColor(color), size: diameter))
        cache[key] = tex
        return tex
    }

    static func uiColor(_ c: BubbleColor) -> UIColor {
        switch c {
        case .red: return UIColor(red: 1, green: 0.35, blue: 0.48, alpha: 1)
        case .amber: return UIColor(red: 1, green: 0.69, blue: 0.13, alpha: 1)
        case .lime: return UIColor(red: 0.35, green: 0.84, blue: 0.29, alpha: 1)
        case .azure: return UIColor(red: 0.23, green: 0.63, blue: 1, alpha: 1)
        case .violet: return UIColor(red: 0.61, green: 0.42, blue: 1, alpha: 1)
        case .aqua: return UIColor(red: 0.18, green: 0.90, blue: 0.77, alpha: 1)
        }
    }

    static func render(color: UIColor, size: CGFloat, photo: UIImage? = nil) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let space = CGColorSpaceCreateDeviceRGB()
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let light = UIColor(red: min(1, r + 0.35), green: min(1, g + 0.28), blue: min(1, b + 0.22), alpha: 1)
            let dark = UIColor(red: r * 0.55, green: g * 0.55, blue: b * 0.62, alpha: 1)
            if let gradient = CGGradient(colorsSpace: space, colors: [
                UIColor.white.withAlphaComponent(0.55).cgColor,
                light.cgColor,
                color.cgColor,
                dark.cgColor,
            ] as CFArray, locations: [0, 0.22, 0.62, 1]) {
                cg.saveGState()
                cg.addEllipse(in: rect)
                cg.clip()
                cg.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: size * 0.32, y: size * 0.28),
                    startRadius: 0,
                    endCenter: CGPoint(x: size * 0.5, y: size * 0.55),
                    endRadius: size * 0.62,
                    options: [.drawsAfterEndLocation]
                )
                cg.restoreGState()
            }
            if let photo {
                cg.saveGState()
                cg.addEllipse(in: rect.insetBy(dx: size * 0.08, dy: size * 0.08))
                cg.clip()
                photo.draw(in: rect)
                cg.restoreGState()
            }
            // specular
            let hi = CGRect(x: size * 0.18, y: size * 0.14, width: size * 0.34, height: size * 0.22)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            cg.fillEllipse(in: hi)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(max(1.2, size * 0.035))
            cg.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
        }
    }

    static func sprite(color: BubbleColor, diameter: CGFloat, name: String = "cell") -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(for: color, diameter: diameter * UIScreen.main.scale))
        node.size = CGSize(width: diameter, height: diameter)
        node.name = name
        return node
    }
}
