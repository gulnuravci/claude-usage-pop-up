import SwiftUI

/// Hats, props, and drifting bits Tok wears for holidays and seasons.
/// Uses the mascot's 56×56 design box; `body` is Tok's body rect for this frame.
struct OutfitPainter {
    let occasion: Occasion
    let mood: Mood
    let t: Double

    // MARK: Behind Tok: particles and hanging ornaments

    func drawBackdrop(_ base: GraphicsContext) {
        var g = base
        g.clip(to: Path(ellipseIn: CGRect(x: 1.5, y: 1.5, width: 53, height: 53)))
        switch occasion {
        case .autumn, .thanksgiving:
            drift(&g, count: 5, speed: 0.13) { c, i in fill(&c, leaf(length: 5), OutfitColors.leaves[i % 3]) }
        case .winter, .christmas:
            drift(&g, count: 9, speed: 0.11) { c, i in
                let r = 0.8 + Double(i % 3) * 0.35
                c.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(OutfitColors.snow))
            }
        case .spring:
            drift(&g, count: 5, speed: 0.12) { c, _ in
                c.fill(Path(ellipseIn: CGRect(x: -1.4, y: -0.9, width: 2.8, height: 1.8)), with: .color(OutfitColors.petal))
            }
        case .valentines:
            drift(&g, count: 4, speed: 0.16, rising: true) { c, i in
                c.fill(heart(size: 3.6), with: .color(i % 2 == 0 ? Palette.blush : Palette.cherry))
            }
        case .piDay:
            drift(&g, count: 3, speed: 0.14, rising: true) { c, _ in
                c.draw(Text("π").font(.system(size: 6, weight: .heavy, design: .serif)).foregroundColor(Palette.clay), at: .zero)
            }
        case .newYear, .tokBirthday:
            drift(&g, count: 8, speed: 0.17) { c, i in
                c.fill(Path(roundedRect: CGRect(x: -1.2, y: -0.6, width: 2.4, height: 1.2), cornerRadius: 0.3),
                       with: .color(ConfettiView.Piece.colors[i % ConfettiView.Piece.colors.count]))
            }
        case .halloween:
            drawBats(&g)
        case .independenceDay:
            drawFireworks(&g)
        case .summer:
            drawSun(&g, at: CGPoint(x: 12, y: 12))
        case .ramadan:
            twinkle(&g, color: OutfitColors.paleGold, star: true)
            drawCrescent(&g)
        case .eidAlFitr, .eidAlAdha:
            twinkle(&g, color: Palette.gold)
            drawCrescent(&g)
        case .lunarNewYear:
            twinkle(&g, color: Palette.gold)
            drawLantern(&g, at: CGPoint(x: 15, y: 12), swing: 0)
            drawLantern(&g, at: CGPoint(x: 42, y: 10), swing: 1.7)
        case .diwali, .stPatricks:
            twinkle(&g, color: Palette.gold)
        case .hanukkah:
            twinkle(&g, color: OutfitColors.hanukkahBlue, star: true)
        case .easter, .earthDay:
            break
        }
    }

    // MARK: On the ground beside Tok (doesn't tilt with Tok)

    func drawProps(_ g: inout GraphicsContext, ground: Double) {
        let spot = CGPoint(x: 10.5, y: ground - 4)
        switch occasion {
        case .halloween: drawPumpkin(&g, at: spot)
        case .easter: drawEgg(&g, at: spot)
        case .ramadan: drawFanous(&g, at: spot)
        case .diwali:
            drawDiya(&g, at: CGPoint(x: 9.5, y: ground - 1), phase: 0)
            drawDiya(&g, at: CGPoint(x: 46.5, y: ground - 1), phase: 2.1)
        case .hanukkah: drawDreidel(&g, tip: CGPoint(x: 10.5, y: ground))
        case .piDay: drawPie(&g, at: CGPoint(x: 11, y: ground - 3))
        case .tokBirthday: drawCake(&g, at: CGPoint(x: 10.5, y: ground - 3))
        default: break
        }
    }

    // MARK: On Tok's head (tilts and bounces with Tok)

    func drawHat(_ g: inout GraphicsContext, body: CGRect, face: CGPoint) {
        let crown = CGPoint(x: body.midX, y: body.minY + 1)
        switch occasion {
        case .halloween: drawWitchHat(&g, at: crown)
        case .christmas: drawSantaHat(&g, at: crown)
        case .winter: drawBeanie(&g, at: crown)
        case .autumn: drawLeaves(&g, at: crown)
        case .spring: drawFlower(&g, at: CGPoint(x: crown.x + 7, y: crown.y))
        case .summer: drawSunglasses(&g, face: face, onHead: ![.chill, .busy, .party, .confused].contains(mood), top: body.minY)
        case .newYear: drawPartyHat(&g, at: crown, colors: (Palette.gold, OutfitColors.navy), pom: Palette.gold)
        case .tokBirthday: drawPartyHat(&g, at: crown, colors: (OutfitColors.sky, Palette.blush), pom: Palette.blush)
        case .valentines: drawHeartBoppers(&g, at: crown)
        case .easter: drawBunnyEars(&g, at: crown)
        case .earthDay: drawSprout(&g, at: crown)
        case .stPatricks:
            drawTopHat(&g, at: crown, crown: OutfitColors.clover, brim: OutfitColors.cloverDark, band: Palette.ink) { c in
                drawBuckle(&c, size: 3)
                for k in 0..<3 {
                    var leaf = c
                    leaf.translateBy(x: 3.6, y: -8)
                    leaf.rotate(by: .degrees(Double(k) * 120))
                    leaf.fill(Path(ellipseIn: CGRect(x: -0.9, y: -2.2, width: 1.8, height: 2.2)), with: .color(OutfitColors.cloverLight))
                }
            }
        case .independenceDay:
            drawTopHat(&g, at: crown, crown: OutfitColors.flagWhite, brim: OutfitColors.flagBlue, band: OutfitColors.flagBlue) { c in
                for x in stride(from: -7.0, to: 7, by: 2.8) {
                    c.fill(Path(CGRect(x: x, y: -12, width: 1.4, height: 7)), with: .color(OutfitColors.flagRed))
                }
                for x in [-3.0, 0, 3] {
                    c.fill(star(size: 0.9).offsetBy(dx: x, dy: -3.2), with: .color(OutfitColors.flagWhite))
                }
            }
        case .thanksgiving:
            drawTopHat(&g, at: crown, crown: OutfitColors.pilgrim, brim: OutfitColors.pilgrim, band: Palette.ink) { c in
                drawBuckle(&c, size: 4)
            }
        case .lunarNewYear, .ramadan, .eidAlFitr, .eidAlAdha, .diwali, .hanukkah, .piDay:
            break
        }
    }

    // MARK: Particles

    /// Bits that fall (or rise) across the ring, swaying, each on its own loop.
    private func drift(_ g: inout GraphicsContext, count: Int, speed: Double, rising: Bool = false,
                       draw: (inout GraphicsContext, Int) -> Void) {
        for i in 0..<count {
            let seed = Double(i) + 1
            let phase = frac(t * speed * (0.8 + 0.4 * frac(seed * 0.37)) + frac(seed * 0.618))
            let y = rising ? 56 - phase * 60 : -2 + phase * 60
            var c = g
            c.translateBy(x: 5 + 46 * frac(seed * 0.7549) + sin(t * 1.3 + seed * 2) * 2.5, y: y)
            c.rotate(by: .radians(sin(t * 1.7 + seed * 2) * 0.8))
            c.opacity = 0.85 * min(1, phase * 6, (1 - phase) * 6)
            draw(&c, i)
        }
    }

    /// Sparkles that pop in and out around Tok.
    private func twinkle(_ g: inout GraphicsContext, color: Color, star useStar: Bool = false) {
        let spots = [CGPoint(x: 8, y: 14), CGPoint(x: 47, y: 25), CGPoint(x: 6, y: 30), CGPoint(x: 21, y: 6), CGPoint(x: 50, y: 37)]
        for (i, spot) in spots.enumerated() {
            let s = max(0, sin(t * 2.6 + Double(i) * 2.3)) * 2.4
            guard s > 0.2 else { continue }
            let shape = useStar ? star(size: s) : sparkle(size: s)
            g.fill(shape.offsetBy(dx: spot.x, dy: spot.y), with: .color(color))
        }
    }

    private func drawBats(_ g: inout GraphicsContext) {
        for i in 0..<2 {
            let seed = Double(i)
            let phase = frac(t * 0.09 + seed * 0.5)
            var c = g
            c.translateBy(x: -6 + phase * 68, y: 9 + seed * 9 + sin(t * 3 + seed * 2) * 2)
            c.scaleBy(x: i == 0 ? 1 : 0.8, y: i == 0 ? 1 : 0.8)
            let flap = sin(t * 16 + seed) * 1.6
            var wings = Path()
            for side in [-1.0, 1.0] {
                wings.move(to: CGPoint(x: side * 0.8, y: 0))
                wings.addQuadCurve(to: CGPoint(x: side * 4.6, y: -flap), control: CGPoint(x: side * 2.4, y: -2 - flap))
                wings.addQuadCurve(to: CGPoint(x: side * 0.8, y: 1), control: CGPoint(x: side * 2.6, y: 0.4 - flap * 0.3))
            }
            c.fill(wings, with: .color(OutfitColors.bat))
            c.fill(Path(ellipseIn: CGRect(x: -1.2, y: -1.2, width: 2.4, height: 2.6)), with: .color(OutfitColors.bat))
        }
    }

    private func drawFireworks(_ g: inout GraphicsContext) {
        let period = 2.4
        let colors = [OutfitColors.flagRed, OutfitColors.flagBlue, Palette.gold]
        for i in 0..<3 {
            let clock = t / period + Double(i) / 3
            let cycle = floor(clock)
            let local = clock - cycle
            let center = CGPoint(x: 10 + 36 * frac(cycle * 0.371 + Double(i) * 0.53), y: 9 + 12 * frac(cycle * 0.727 + Double(i) * 0.31))
            let radius = 1 + 7 * (1 - pow(1 - local, 2))
            var c = g
            c.opacity = 1 - local
            for k in 0..<8 {
                let angle = Double(k) / 8 * 2 * .pi
                let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius + local * local * 3)
                c.fill(Path(ellipseIn: CGRect(x: p.x - 0.7, y: p.y - 0.7, width: 1.4, height: 1.4)), with: .color(colors[i]))
            }
        }
    }

    private func drawSun(_ g: inout GraphicsContext, at center: CGPoint) {
        var c = g
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .radians(t * 0.4))
        for k in 0..<8 {
            var ray = c
            ray.rotate(by: .degrees(Double(k) * 45))
            ray.fill(Path(roundedRect: CGRect(x: -0.6, y: -6.2, width: 1.2, height: 2.2), cornerRadius: 0.6), with: .color(Palette.gold))
        }
        c.fill(Path(ellipseIn: CGRect(x: -3.2, y: -3.2, width: 6.4, height: 6.4)), with: .color(Palette.gold))
    }

    // MARK: Hanging ornaments

    private func drawCrescent(_ g: inout GraphicsContext) {
        var c = g
        let hook = CGPoint(x: 41, y: 1)
        c.translateBy(x: hook.x, y: hook.y)
        c.rotate(by: .radians(sin(t * 1.4) * 0.12))
        string(&c, length: 6)
        var moon = c
        moon.translateBy(x: 0, y: 10)
        moon.clip(to: Path(ellipseIn: CGRect(x: -1.6, y: -4.4, width: 7, height: 7)), options: .inverse)
        moon.fill(Path(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8)), with: .color(Palette.gold))

        var small = g
        small.translateBy(x: 33.5, y: 2)
        small.rotate(by: .radians(sin(t * 1.7 + 1) * 0.15))
        string(&small, length: 4)
        small.fill(star(size: 2.2).offsetBy(dx: 0, dy: 6), with: .color(Palette.gold))
    }

    private func drawLantern(_ g: inout GraphicsContext, at center: CGPoint, swing: Double) {
        var c = g
        c.translateBy(x: center.x, y: center.y - 8)
        c.rotate(by: .radians(sin(t * 1.5 + swing) * 0.12))
        string(&c, length: 4.5)
        c.translateBy(x: 0, y: 8)
        c.fill(Path(ellipseIn: CGRect(x: -4.2, y: -3.6, width: 8.4, height: 7.2)), with: .color(OutfitColors.lanternRed))
        c.stroke(Path(ellipseIn: CGRect(x: -1.8, y: -3.6, width: 3.6, height: 7.2)), with: .color(Palette.gold.opacity(0.7)), lineWidth: 0.5)
        c.fill(Path(roundedRect: CGRect(x: -2.2, y: -4.4, width: 4.4, height: 1.4), cornerRadius: 0.4), with: .color(Palette.gold))
        c.fill(Path(roundedRect: CGRect(x: -2.2, y: 3, width: 4.4, height: 1.4), cornerRadius: 0.4), with: .color(Palette.gold))
        var tassel = Path()
        tassel.move(to: CGPoint(x: 0, y: 4.4))
        tassel.addLine(to: CGPoint(x: 0, y: 7.5))
        c.stroke(tassel, with: .color(OutfitColors.lanternRed), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }

    private func string(_ c: inout GraphicsContext, length: Double) {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: 0, y: length))
        c.stroke(p, with: .color(Color.primary.opacity(0.35)), lineWidth: 0.5)
    }

    // MARK: Props

    private func drawPumpkin(_ g: inout GraphicsContext, at p: CGPoint) {
        g.fill(Path(roundedRect: CGRect(x: p.x - 0.6, y: p.y - 5, width: 1.4, height: 2.5), cornerRadius: 0.5), with: .color(OutfitColors.stem))
        for (dx, w) in [(-2.2, 5.2), (2.2, 5.2), (0.0, 5.4)] {
            g.fill(Path(ellipseIn: CGRect(x: p.x + dx - w / 2, y: p.y - 3.6, width: w, height: 7.4)),
                   with: .color(dx == 0 ? OutfitColors.pumpkin : OutfitColors.pumpkinDark))
        }
        let glow = OutfitColors.candle.opacity(0.75 + 0.25 * sin(t * 9))
        for side in [-1.0, 1.0] {
            var eye = Path()
            eye.move(to: CGPoint(x: p.x + side * 1.9 - 0.9, y: p.y - 0.3))
            eye.addLine(to: CGPoint(x: p.x + side * 1.9, y: p.y - 1.8))
            eye.addLine(to: CGPoint(x: p.x + side * 1.9 + 0.9, y: p.y - 0.3))
            eye.closeSubpath()
            g.fill(eye, with: .color(glow))
        }
        var grin = Path()
        grin.move(to: CGPoint(x: p.x - 2.4, y: p.y + 1))
        grin.addQuadCurve(to: CGPoint(x: p.x + 2.4, y: p.y + 1), control: CGPoint(x: p.x, y: p.y + 3.6))
        grin.addQuadCurve(to: CGPoint(x: p.x - 2.4, y: p.y + 1), control: CGPoint(x: p.x, y: p.y + 2))
        g.fill(grin, with: .color(glow))
    }

    private func drawEgg(_ g: inout GraphicsContext, at p: CGPoint) {
        let shell = Path(ellipseIn: CGRect(x: p.x - 3.3, y: p.y - 4.6, width: 6.6, height: 8.6))
        var c = g
        c.fill(shell, with: .color(OutfitColors.eggBlue))
        c.clip(to: shell)
        var zigzag = Path()
        zigzag.move(to: CGPoint(x: p.x - 4, y: p.y))
        for k in 0..<6 {
            zigzag.addLine(to: CGPoint(x: p.x - 3 + Double(k) * 1.4, y: p.y + (k % 2 == 0 ? -1.2 : 0.4)))
        }
        c.stroke(zigzag, with: .color(Palette.blush), lineWidth: 1.1)
        for (dx, dy) in [(-1.3, -2.6), (1.4, -2.4), (0.0, 2.2)] {
            c.fill(Path(ellipseIn: CGRect(x: p.x + dx - 0.6, y: p.y + dy - 0.6, width: 1.2, height: 1.2)), with: .color(Palette.gold))
        }
    }

    /// The fanous, a Ramadan lantern.
    private func drawFanous(_ g: inout GraphicsContext, at p: CGPoint) {
        let glow = OutfitColors.candle.opacity(0.75 + 0.2 * sin(t * 7))
        g.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 4, width: 10, height: 10)), with: .color(OutfitColors.candle.opacity(0.18)))
        g.stroke(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 9.4, width: 2, height: 2)), with: .color(OutfitColors.brass), lineWidth: 0.6)
        var cap = Path()
        cap.move(to: CGPoint(x: p.x - 3.2, y: p.y - 4.4))
        cap.addLine(to: CGPoint(x: p.x, y: p.y - 7.6))
        cap.addLine(to: CGPoint(x: p.x + 3.2, y: p.y - 4.4))
        cap.closeSubpath()
        g.fill(cap, with: .color(OutfitColors.brass))
        var body = Path()
        body.move(to: CGPoint(x: p.x - 3, y: p.y - 4.4))
        body.addLine(to: CGPoint(x: p.x + 3, y: p.y - 4.4))
        body.addLine(to: CGPoint(x: p.x + 2, y: p.y + 2.6))
        body.addLine(to: CGPoint(x: p.x - 2, y: p.y + 2.6))
        body.closeSubpath()
        g.fill(body, with: .color(glow))
        g.stroke(body, with: .color(OutfitColors.brass), lineWidth: 0.8)
        g.fill(Path(roundedRect: CGRect(x: p.x - 2.8, y: p.y + 2.4, width: 5.6, height: 1.6), cornerRadius: 0.5), with: .color(OutfitColors.brass))
    }

    /// A little clay oil lamp with a flickering flame.
    private func drawDiya(_ g: inout GraphicsContext, at p: CGPoint, phase: Double) {
        let flicker = 1 + 0.12 * sin(t * 11 + phase) + 0.06 * sin(t * 23 + phase)
        g.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 9, width: 9, height: 9)),
               with: .color(OutfitColors.candle.opacity(0.16 * flicker)))
        var flame = Path()
        let top = p.y - 2 - 4.2 * flicker
        flame.move(to: CGPoint(x: p.x, y: top))
        flame.addQuadCurve(to: CGPoint(x: p.x, y: p.y - 1.6), control: CGPoint(x: p.x + 2.4, y: p.y - 2.4))
        flame.addQuadCurve(to: CGPoint(x: p.x, y: top), control: CGPoint(x: p.x - 2.4, y: p.y - 2.4))
        g.fill(flame, with: .linearGradient(Gradient(colors: [OutfitColors.candle, Palette.tangerine]),
                                            startPoint: CGPoint(x: p.x, y: top), endPoint: CGPoint(x: p.x, y: p.y - 1.6)))
        var bowl = Path()
        bowl.move(to: CGPoint(x: p.x - 4, y: p.y - 1.8))
        bowl.addQuadCurve(to: CGPoint(x: p.x + 4, y: p.y - 1.8), control: CGPoint(x: p.x, y: p.y + 3.4))
        bowl.closeSubpath()
        g.fill(bowl, with: .color(OutfitColors.terracotta))
        var rim = Path()
        rim.move(to: CGPoint(x: p.x - 4, y: p.y - 1.8))
        rim.addLine(to: CGPoint(x: p.x + 4, y: p.y - 1.8))
        g.stroke(rim, with: .color(Palette.gold), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    private func drawDreidel(_ g: inout GraphicsContext, tip: CGPoint) {
        var c = g
        c.translateBy(x: tip.x, y: tip.y)
        c.rotate(by: .radians(sin(t * 6) * 0.18))
        c.fill(Path(roundedRect: CGRect(x: -0.8, y: -11, width: 1.6, height: 3), cornerRadius: 0.5), with: .color(OutfitColors.hanukkahBlue))
        c.fill(Path(roundedRect: CGRect(x: -3.6, y: -8.6, width: 7.2, height: 6.2), cornerRadius: 1.2), with: .color(OutfitColors.hanukkahBlue))
        var point = Path()
        point.move(to: CGPoint(x: -3.6, y: -3))
        point.addLine(to: CGPoint(x: 0, y: 0))
        point.addLine(to: CGPoint(x: 3.6, y: -3))
        point.closeSubpath()
        c.fill(point, with: .color(OutfitColors.hanukkahBlueDark))
        c.draw(Text("ש").font(.system(size: 5.5, weight: .bold)).foregroundColor(.white), at: CGPoint(x: 0, y: -5.6))
    }

    private func drawPie(_ g: inout GraphicsContext, at p: CGPoint) {
        var tin = Path()
        tin.move(to: CGPoint(x: p.x - 5.4, y: p.y))
        tin.addLine(to: CGPoint(x: p.x + 5.4, y: p.y))
        tin.addLine(to: CGPoint(x: p.x + 4.4, y: p.y + 3))
        tin.addLine(to: CGPoint(x: p.x - 4.4, y: p.y + 3))
        tin.closeSubpath()
        g.fill(tin, with: .color(Color(white: 0.7)))
        g.fill(Path(ellipseIn: CGRect(x: p.x - 5.4, y: p.y - 2, width: 10.8, height: 4)), with: .color(OutfitColors.crust))
        g.draw(Text("π").font(.system(size: 4.5, weight: .heavy, design: .serif)).foregroundColor(OutfitColors.crustDark),
               at: CGPoint(x: p.x, y: p.y - 0.2))
    }

    private func drawCake(_ g: inout GraphicsContext, at p: CGPoint) {
        g.fill(Path(roundedRect: CGRect(x: p.x - 4.6, y: p.y - 2.6, width: 9.2, height: 5.6), cornerRadius: 1), with: .color(Palette.blush))
        g.fill(Path(roundedRect: CGRect(x: p.x - 4.8, y: p.y - 3.2, width: 9.6, height: 2.2), cornerRadius: 1.1), with: .color(OutfitColors.frosting))
        g.fill(Path(CGRect(x: p.x - 0.5, y: p.y - 7, width: 1, height: 3.8)), with: .color(OutfitColors.sky))
        let flicker = 1 + 0.15 * sin(t * 12)
        g.fill(Path(ellipseIn: CGRect(x: p.x - 0.9, y: p.y - 7.2 - 2.4 * flicker, width: 1.8, height: 2.4 * flicker)), with: .color(OutfitColors.candle))
    }

    // MARK: Hats

    /// Runs `draw` with the origin at the crown of Tok's head, turned by `tilt`.
    private func atCrown(_ g: GraphicsContext, _ crown: CGPoint, tilt: Double, draw: (inout GraphicsContext) -> Void) {
        var c = g
        c.translateBy(x: crown.x, y: crown.y)
        c.rotate(by: .radians(tilt))
        draw(&c)
    }

    private func drawWitchHat(_ g: inout GraphicsContext, at crown: CGPoint) {
        atCrown(g, crown, tilt: -0.08 + sin(t * 1.6) * 0.03) { c in
            c.fill(Path(ellipseIn: CGRect(x: -12, y: -2.6, width: 24, height: 4.6)), with: .color(OutfitColors.witchDark))
            var cone = Path()
            cone.move(to: CGPoint(x: -7, y: -1))
            cone.addQuadCurve(to: CGPoint(x: 6, y: -14), control: CGPoint(x: -3, y: -9))
            cone.addQuadCurve(to: CGPoint(x: 7, y: -1), control: CGPoint(x: 3.5, y: -6))
            cone.closeSubpath()
            c.fill(cone, with: .linearGradient(Gradient(colors: [OutfitColors.witch, OutfitColors.witchDark]),
                                               startPoint: CGPoint(x: 0, y: -14), endPoint: CGPoint(x: 0, y: -1)))
            var band = c
            band.clip(to: cone)
            band.fill(Path(CGRect(x: -8, y: -4.4, width: 16, height: 2.4)), with: .color(Palette.tangerine))
        }
    }

    private func drawSantaHat(_ g: inout GraphicsContext, at crown: CGPoint) {
        atCrown(g, crown, tilt: -0.05) { c in
            var cone = Path()
            cone.move(to: CGPoint(x: -10, y: 0))
            cone.addQuadCurve(to: CGPoint(x: 1, y: -11), control: CGPoint(x: -8, y: -10))
            cone.addQuadCurve(to: CGPoint(x: 12, y: -5 + sin(t * 2) * 0.6), control: CGPoint(x: 9, y: -12))
            cone.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 7, y: -6))
            cone.closeSubpath()
            c.fill(cone, with: .color(OutfitColors.santaRed))
            fluff(&c, Path(roundedRect: CGRect(x: -11.5, y: -2.6, width: 23, height: 5), cornerRadius: 2.5))
            fluff(&c, Path(ellipseIn: CGRect(x: 10, y: -7.6 + sin(t * 2) * 0.6, width: 5.2, height: 5.2)))
        }
    }

    private func drawBeanie(_ g: inout GraphicsContext, at crown: CGPoint) {
        atCrown(g, crown, tilt: 0.06) { c in
            var dome = Path()
            dome.addArc(center: CGPoint(x: 0, y: -0.5), radius: 10.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            dome.closeSubpath()
            c.fill(dome, with: .color(OutfitColors.beanie))
            var stripe = c
            stripe.clip(to: dome)
            stripe.fill(Path(CGRect(x: -11, y: -6.5, width: 22, height: 2)), with: .color(OutfitColors.frosting))
            c.fill(Path(roundedRect: CGRect(x: -11.5, y: -2.8, width: 23, height: 4.8), cornerRadius: 2), with: .color(OutfitColors.beanieDark))
            for x in stride(from: -9.0, through: 9, by: 2.25) {
                c.fill(Path(CGRect(x: x - 0.25, y: -2.2, width: 0.5, height: 3.6)), with: .color(Color.black.opacity(0.12)))
            }
            fluff(&c, Path(ellipseIn: CGRect(x: -3, y: -14.5, width: 6, height: 6)))
        }
    }

    private func drawLeaves(_ g: inout GraphicsContext, at crown: CGPoint) {
        for (dx, tilt, color, length) in [(2.5, 0.55, OutfitColors.leaves[0], 9.0), (-0.5, -0.35, OutfitColors.leaves[1], 7.0)] {
            atCrown(g, CGPoint(x: crown.x + dx, y: crown.y), tilt: tilt + sin(t * 1.5 + dx) * 0.05) { c in
                fill(&c, leaf(length: length), color)
                var rib = Path()
                rib.move(to: CGPoint(x: 0, y: 0.5))
                rib.addLine(to: CGPoint(x: 0, y: -length + 1.5))
                c.stroke(rib, with: .color(Color.black.opacity(0.2)), lineWidth: 0.5)
            }
        }
    }

    private func drawFlower(_ g: inout GraphicsContext, at center: CGPoint) {
        atCrown(g, center, tilt: sin(t * 1.5) * 0.15) { c in
            for k in 0..<5 {
                var petal = c
                petal.rotate(by: .degrees(Double(k) * 72))
                petal.fill(Path(ellipseIn: CGRect(x: -1.7, y: -5.4, width: 3.4, height: 4.4)), with: .color(OutfitColors.petal))
            }
            c.fill(Path(ellipseIn: CGRect(x: -1.9, y: -1.9, width: 3.8, height: 3.8)), with: .color(Palette.gold))
        }
    }

    private func drawSunglasses(_ g: inout GraphicsContext, face: CGPoint, onHead: Bool, top: Double) {
        var c = g
        c.translateBy(x: face.x, y: onHead ? top + 3.5 : face.y)
        if onHead { c.scaleBy(x: 0.85, y: 0.85) }
        let line = StrokeStyle(lineWidth: 1.1, lineCap: .round)
        var frame = Path()
        frame.move(to: CGPoint(x: -2.6, y: -1.6))
        frame.addQuadCurve(to: CGPoint(x: 2.6, y: -1.6), control: CGPoint(x: 0, y: -2.8))
        frame.move(to: CGPoint(x: -10.5, y: -2))
        frame.addLine(to: CGPoint(x: -14.5, y: -2.6))
        frame.move(to: CGPoint(x: 10.5, y: -2))
        frame.addLine(to: CGPoint(x: 14.5, y: -2.6))
        c.stroke(frame, with: .color(Palette.ink), style: line)
        for side in [-1.0, 1.0] {
            let lens = Path(roundedRect: CGRect(x: side * 6.5 - 4.2, y: -3.2, width: 8.4, height: 6.2), cornerRadius: 2.4)
            c.fill(lens, with: .color(Palette.ink))
            var shine = Path()
            shine.move(to: CGPoint(x: side * 6.5 - 2.4, y: -0.6))
            shine.addLine(to: CGPoint(x: side * 6.5 - 0.6, y: -2.2))
            c.stroke(shine, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }
    }

    private func drawPartyHat(_ g: inout GraphicsContext, at crown: CGPoint, colors: (Color, Color), pom: Color) {
        atCrown(g, CGPoint(x: crown.x - 3, y: crown.y), tilt: -0.22 + sin(t * 2) * 0.04) { c in
            var cone = Path()
            cone.move(to: CGPoint(x: -5.6, y: 0))
            cone.addLine(to: CGPoint(x: 0, y: -13))
            cone.addLine(to: CGPoint(x: 5.6, y: 0))
            cone.closeSubpath()
            c.fill(cone, with: .color(colors.0))
            var stripes = c
            stripes.clip(to: cone)
            for y in stride(from: -11.0, to: 0, by: 4) {
                var band = Path()
                band.move(to: CGPoint(x: -7, y: y + 2))
                band.addLine(to: CGPoint(x: 7, y: y - 1))
                stripes.stroke(band, with: .color(colors.1), lineWidth: 1.3)
            }
            c.fill(Path(ellipseIn: CGRect(x: -2, y: -15, width: 4, height: 4)), with: .color(pom))
        }
    }

    /// A headband with two hearts bobbing on springs.
    private func drawHeartBoppers(_ g: inout GraphicsContext, at crown: CGPoint) {
        for side in [-1.0, 1.0] {
            let base = CGPoint(x: crown.x + side * 4.5, y: crown.y)
            let tip = CGPoint(x: crown.x + side * (7.5 + sin(t * 4 + side) * 0.8), y: crown.y - 10 + cos(t * 5 + side) * 0.8)
            var spring = Path()
            spring.move(to: base)
            spring.addQuadCurve(to: tip, control: CGPoint(x: base.x - side * 1.5, y: (base.y + tip.y) / 2))
            g.stroke(spring, with: .color(Palette.ink), lineWidth: 0.8)
            g.fill(heart(size: 5).offsetBy(dx: tip.x, dy: tip.y), with: .color(side < 0 ? Palette.cherry : Palette.blush))
        }
    }

    private func drawBunnyEars(_ g: inout GraphicsContext, at crown: CGPoint) {
        for side in [-1.0, 1.0] {
            let flop = side > 0 ? 0.18 + sin(t * 2) * 0.06 : 0
            atCrown(g, CGPoint(x: crown.x + side * 5, y: crown.y + 1), tilt: side * 0.22 + flop) { c in
                let outer = Path(roundedRect: CGRect(x: -2.8, y: -14, width: 5.6, height: 15), cornerRadius: 2.8)
                fluff(&c, outer)
                c.fill(Path(roundedRect: CGRect(x: -1.4, y: -12, width: 2.8, height: 10), cornerRadius: 1.4),
                       with: .color(Palette.blush.opacity(0.75)))
            }
        }
    }

    private func drawSprout(_ g: inout GraphicsContext, at crown: CGPoint) {
        atCrown(g, crown, tilt: sin(t * 1.8) * 0.12) { c in
            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: 0.5))
            stem.addQuadCurve(to: CGPoint(x: 0.5, y: -6), control: CGPoint(x: -1.2, y: -3))
            c.stroke(stem, with: .color(OutfitColors.stem), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            for (tilt, color) in [(-1.0, OutfitColors.stem), (1.0, OutfitColors.cloverLight)] {
                var leafContext = c
                leafContext.translateBy(x: 0.5, y: -6)
                leafContext.rotate(by: .radians(tilt))
                fill(&leafContext, leaf(length: 5.5), color)
            }
        }
    }

    private func drawTopHat(_ g: inout GraphicsContext, at crown: CGPoint, crown crownColor: Color, brim: Color, band: Color,
                            decorate: (inout GraphicsContext) -> Void) {
        atCrown(g, crown, tilt: -0.12) { c in
            var top = Path()
            top.move(to: CGPoint(x: -5.6, y: -1))
            top.addLine(to: CGPoint(x: -6.6, y: -12))
            top.addLine(to: CGPoint(x: 6.6, y: -12))
            top.addLine(to: CGPoint(x: 5.6, y: -1))
            top.closeSubpath()
            c.fill(top, with: .color(crownColor))
            var inside = c
            inside.clip(to: top)
            inside.fill(Path(CGRect(x: -7, y: -5, width: 14, height: 2.6)), with: .color(band))
            decorate(&inside)
            c.stroke(top, with: .color(Color.black.opacity(0.15)), lineWidth: 0.4)
            c.fill(Path(roundedRect: CGRect(x: -10, y: -2, width: 20, height: 3), cornerRadius: 1.5), with: .color(brim))
        }
    }

    private func drawBuckle(_ c: inout GraphicsContext, size: Double) {
        c.stroke(Path(CGRect(x: -size / 2, y: -3.7 - size / 2 + 0.2, width: size, height: size - 0.4)), with: .color(Palette.gold), lineWidth: 0.7)
    }

    // MARK: Shapes

    /// Soft white with a faint edge, so it still shows up on a light card.
    private func fluff(_ c: inout GraphicsContext, _ shape: Path) {
        c.fill(shape, with: .color(OutfitColors.frosting))
        c.stroke(shape, with: .color(Palette.ink.opacity(0.15)), lineWidth: 0.4)
    }

    private func fill(_ c: inout GraphicsContext, _ shape: Path, _ color: Color) { c.fill(shape, with: .color(color)) }

    /// A leaf from the origin pointing up.
    private func leaf(length: Double) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: length * 0.5, y: -length * 0.45))
        p.addQuadCurve(to: .zero, control: CGPoint(x: -length * 0.5, y: -length * 0.45))
        return p
    }

    private func heart(size s: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.35))
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.2), control1: CGPoint(x: -s * 0.75, y: -s * 0.1), control2: CGPoint(x: -s * 0.35, y: -s * 0.6))
        p.addCurve(to: CGPoint(x: 0, y: s * 0.35), control1: CGPoint(x: s * 0.35, y: -s * 0.6), control2: CGPoint(x: s * 0.75, y: -s * 0.1))
        return p
    }

    private func star(size s: Double) -> Path {
        var p = Path()
        for k in 0..<10 {
            let r = k % 2 == 0 ? s : s * 0.45
            let angle = Double(k) * .pi / 5 - .pi / 2
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if k == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }

    private func sparkle(size s: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -s))
        p.addQuadCurve(to: CGPoint(x: s, y: 0), control: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: s), control: .zero)
        p.addQuadCurve(to: CGPoint(x: -s, y: 0), control: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: -s), control: .zero)
        return p
    }

    private func frac(_ x: Double) -> Double { x - floor(x) }
}

private enum OutfitColors {
    static let leaves = [Color(red: 0.93, green: 0.50, blue: 0.16), Color(red: 0.84, green: 0.27, blue: 0.20), Color(red: 0.95, green: 0.72, blue: 0.22)]
    static let snow = Color(red: 0.74, green: 0.85, blue: 0.98)
    static let petal = Color(red: 1.0, green: 0.80, blue: 0.87)
    static let frosting = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let navy = Color(red: 0.17, green: 0.20, blue: 0.38)
    static let sky = Color(red: 0.55, green: 0.72, blue: 1.0)
    static let bat = Color(red: 0.26, green: 0.20, blue: 0.33)
    static let witch = Color(red: 0.42, green: 0.28, blue: 0.58)
    static let witchDark = Color(red: 0.24, green: 0.16, blue: 0.34)
    static let pumpkin = Color(red: 0.97, green: 0.56, blue: 0.15)
    static let pumpkinDark = Color(red: 0.88, green: 0.44, blue: 0.10)
    static let stem = Color(red: 0.36, green: 0.62, blue: 0.30)
    static let candle = Color(red: 1.0, green: 0.86, blue: 0.40)
    static let santaRed = Color(red: 0.87, green: 0.20, blue: 0.22)
    static let beanie = Color(red: 0.30, green: 0.56, blue: 0.78)
    static let beanieDark = Color(red: 0.22, green: 0.44, blue: 0.64)
    static let clover = Color(red: 0.22, green: 0.62, blue: 0.33)
    static let cloverDark = Color(red: 0.15, green: 0.48, blue: 0.25)
    static let cloverLight = Color(red: 0.50, green: 0.80, blue: 0.40)
    static let flagRed = Color(red: 0.85, green: 0.20, blue: 0.24)
    static let flagBlue = Color(red: 0.22, green: 0.33, blue: 0.70)
    static let flagWhite = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let pilgrim = Color(red: 0.20, green: 0.18, blue: 0.19)
    static let paleGold = Color(red: 1.0, green: 0.88, blue: 0.55)
    static let brass = Color(red: 0.80, green: 0.60, blue: 0.22)
    static let lanternRed = Color(red: 0.88, green: 0.18, blue: 0.16)
    static let terracotta = Color(red: 0.78, green: 0.40, blue: 0.22)
    static let hanukkahBlue = Color(red: 0.30, green: 0.50, blue: 0.90)
    static let hanukkahBlueDark = Color(red: 0.20, green: 0.36, blue: 0.72)
    static let eggBlue = Color(red: 0.62, green: 0.82, blue: 0.98)
    static let crust = Color(red: 0.94, green: 0.74, blue: 0.44)
    static let crustDark = Color(red: 0.70, green: 0.45, blue: 0.22)
}
