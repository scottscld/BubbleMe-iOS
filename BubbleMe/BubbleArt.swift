import SpriteKit
import UIKit

enum BubbleArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(for color: BubbleColor, diameter: CGFloat, palette: ColorPack = .classic, style: BubbleStyle = .solid) -> SKTexture {
        let key = "\(palette.rawValue)-\(style.rawValue)-\(color.rawValue)-\(Int(diameter))"
        if let hit = cache[key] { return hit }
        let tex = SKTexture(image: render(color: palette.uiColor(color), size: diameter, style: style))
        cache[key] = tex
        return tex
    }

    static func uiColor(_ c: BubbleColor) -> UIColor { ColorPack.classic.uiColor(c) }

    static func render(color: UIColor, size: CGFloat, photo: UIImage? = nil, style: BubbleStyle = .solid) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let space = CGColorSpaceCreateDeviceRGB()
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let light: UIColor
            let dark: UIColor
            let shine: CGFloat
            switch style {
            case .solid:
                light = UIColor(red: min(1, r + 0.35), green: min(1, g + 0.28), blue: min(1, b + 0.22), alpha: 1)
                dark = UIColor(red: r * 0.55, green: g * 0.55, blue: b * 0.62, alpha: 1)
                shine = 0.45
            case .matte:
                light = UIColor(red: min(1, r + 0.08), green: min(1, g + 0.08), blue: min(1, b + 0.08), alpha: 1)
                dark = UIColor(red: r * 0.78, green: g * 0.78, blue: b * 0.8, alpha: 1)
                shine = 0.08
            case .chrome:
                light = UIColor(red: min(1, 0.85 + r * 0.15), green: min(1, 0.85 + g * 0.15), blue: min(1, 0.88 + b * 0.12), alpha: 1)
                dark = UIColor(red: 0.22 + r * 0.25, green: 0.22 + g * 0.25, blue: 0.26 + b * 0.25, alpha: 1)
                shine = 0.7
            }
            if let gradient = CGGradient(colorsSpace: space, colors: [
                UIColor.white.withAlphaComponent(style == .matte ? 0.12 : 0.55).cgColor,
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
            let hi = CGRect(x: size * 0.18, y: size * 0.14, width: size * 0.34, height: size * 0.22)
            cg.setFillColor(UIColor.white.withAlphaComponent(shine).cgColor)
            cg.fillEllipse(in: hi)
            if style == .chrome {
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.55).cgColor)
                cg.setLineWidth(max(1.4, size * 0.045))
            } else {
                cg.setStrokeColor(UIColor.white.withAlphaComponent(style == .matte ? 0.12 : 0.35).cgColor)
                cg.setLineWidth(max(1.2, size * 0.035))
            }
            cg.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
        }
    }

    static func sprite(color: BubbleColor, diameter: CGFloat, name: String = "cell", palette: ColorPack = .classic, style: BubbleStyle = .solid) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(for: color, diameter: diameter * UIScreen.main.scale, palette: palette, style: style))
        node.size = CGSize(width: diameter, height: diameter)
        node.name = name
        return node
    }

    static func shooterNode(kind: ShooterKind, color: SKColor) -> SKNode {
        let root = SKNode()
        root.name = "barrel"
        func tube(width: CGFloat, height: CGFloat, x: CGFloat = 0) -> SKShapeNode {
            let n = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 6)
            n.fillColor = SKColor(red: 0.14, green: 0.18, blue: 0.28, alpha: 1)
            n.strokeColor = SKColor.white.withAlphaComponent(0.22)
            n.position = CGPoint(x: x, y: height / 2)
            return n
        }
        switch kind {
        case .cannon:
            root.addChild(tube(width: 22, height: 52))
        case .twin:
            root.addChild(tube(width: 14, height: 46, x: -10))
            root.addChild(tube(width: 14, height: 46, x: 10))
        case .laser:
            let n = SKShapeNode(rectOf: CGSize(width: 10, height: 58), cornerRadius: 4)
            n.fillColor = SKColor(red: 0.2, green: 0.85, blue: 1, alpha: 0.9)
            n.strokeColor = .white
            n.glowWidth = 4
            n.position = CGPoint(x: 0, y: 30)
            root.addChild(n)
        case .rocket:
            root.addChild(tube(width: 26, height: 48))
            let finL = SKShapeNode(rectOf: CGSize(width: 8, height: 16), cornerRadius: 2)
            finL.fillColor = color
            finL.strokeColor = .clear
            finL.position = CGPoint(x: -16, y: 10)
            let finR = finL.copy() as! SKShapeNode
            finR.position = CGPoint(x: 16, y: 10)
            root.addChild(finL)
            root.addChild(finR)
        case .wand:
            let stick = SKShapeNode(rectOf: CGSize(width: 8, height: 44), cornerRadius: 3)
            stick.fillColor = SKColor(red: 0.72, green: 0.55, blue: 0.22, alpha: 1)
            stick.strokeColor = .clear
            stick.position = CGPoint(x: 0, y: 24)
            let orb = SKShapeNode(circleOfRadius: 10)
            orb.fillColor = color
            orb.strokeColor = .white
            orb.glowWidth = 3
            orb.position = CGPoint(x: 0, y: 52)
            root.addChild(stick)
            root.addChild(orb)
        case .star:
            let star = SKLabelNode(text: "★")
            star.fontSize = 36
            star.fontName = "AvenirNext-Bold"
            star.fontColor = color
            star.position = CGPoint(x: 0, y: 18)
            root.addChild(star)
        }
        return root
    }
}
