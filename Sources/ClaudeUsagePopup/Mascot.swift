import SwiftUI

/// Tok, the little token buddy. Drawn entirely in code so every mood can wiggle differently.
struct MascotView: View {
    let mood: Mood
    @Environment(\.frozenTime) private var frozenTime

    var body: some View {
        if let frozenTime {
            canvas(at: frozenTime)
        } else {
            let schedule = BurstSchedule(for: mood)
            TimelineView(schedule) { context in
                canvas(at: schedule.animationTime(at: context.date))
            }
        }
    }

    private func canvas(at t: Double) -> some View {
        Canvas { context, size in
            MascotPainter(mood: mood, t: t).draw(in: context, size: size)
        }
    }
}

/// Redraws in short bursts when Tok is calm (to keep CPU near zero) and continuously when things get exciting.
struct BurstSchedule: TimelineSchedule {
    let fps: Double
    let active: Double
    let period: Double

    init(for mood: Mood) {
        switch mood {
        case .chill, .confused: (fps, active, period) = (20, 2.5, 12)
        case .busy: (fps, active, period) = (20, 3, 9)
        case .sleeping: (fps, active, period) = (15, 1, 1)
        case .nervous, .panic, .party: (fps, active, period) = (24, 1, 1)
        }
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var t = startDate.timeIntervalSinceReferenceDate
        return AnyIterator {
            defer {
                let phase = t.truncatingRemainder(dividingBy: period)
                t += phase + 1 / fps < active ? 1 / fps : period - phase
            }
            return Date(timeIntervalSinceReferenceDate: t)
        }
    }

    /// Clock time with the resting gaps cut out, so motion picks up where it left off.
    func animationTime(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let phase = t.truncatingRemainder(dividingBy: period)
        return (t - phase) / period * active + min(phase, active)
    }
}

private struct MascotPainter {
    let mood: Mood
    let t: Double

    /// All coordinates below are in a 56×56 design box that gets scaled to fit.
    func draw(in base: GraphicsContext, size: CGSize) {
        var g = base
        let scale = min(size.width, size.height) / 56
        g.translateBy(x: (size.width - 56 * scale) / 2, y: (size.height - 56 * scale) / 2)
        g.scaleBy(x: scale, y: scale)

        let cx = 28.0, ground = 45.0
        var lift = 0.0, jitter = 0.0, squash = 1.0, tilt = 0.0
        switch mood {
        case .chill:    lift = 1.5 + 1.5 * sin(t * 2); squash = 1 + 0.025 * sin(t * 4)
        case .busy:     lift = abs(sin(t * 5)) * 3; squash = 1 + 0.04 * sin(t * 10)
        case .nervous:  lift = 1 + sin(t * 3); jitter = sin(t * 38) * 0.5
        case .panic:    lift = abs(sin(t * 9)) * 2.5; jitter = sin(t * 50) * 1.3
        case .sleeping: squash = 1 + 0.045 * sin(t * 1.4)
        case .party:    lift = abs(sin(t * 6.5)) * 9; squash = 1 + 0.07 * cos(t * 13)
        case .confused: tilt = sin(t * 1.6) * 0.12
        }

        let w = 32 * (2 - squash), h = 27 * squash
        let bottom = ground - lift
        let body = CGRect(x: cx - w / 2 + jitter, y: bottom - h, width: w, height: h)

        // Shadow on the ground shrinks as Tok jumps.
        let shadowWidth = 22 * (1 - lift / 30)
        g.fill(Ellipse().path(in: CGRect(x: cx - shadowWidth / 2, y: ground + 1, width: shadowWidth, height: 3.5)),
               with: .color(.black.opacity(0.14)))

        if tilt != 0 {
            g.translateBy(x: body.midX, y: bottom)
            g.rotate(by: .radians(tilt))
            g.translateBy(x: -body.midX, y: -bottom)
        }

        let (top, bottomColor) = bodyColors
        for dx in [-7.0, 7.0] {
            g.fill(Capsule().path(in: CGRect(x: body.midX + dx - 3, y: bottom - 2.5, width: 6, height: 5)),
                   with: .color(Palette.clayDark))
        }
        drawArms(&g, body: body)
        g.fill(Path(roundedRect: body, cornerRadius: 11, style: .continuous),
               with: .linearGradient(Gradient(colors: [top, bottomColor]),
                                     startPoint: CGPoint(x: body.midX, y: body.minY),
                                     endPoint: CGPoint(x: body.midX, y: body.maxY)))
        g.fill(Ellipse().path(in: CGRect(x: body.minX + 5, y: body.minY + 3, width: 8, height: 4)),
               with: .color(.white.opacity(0.28)))

        let faceY = body.minY + h * 0.46
        drawEyes(&g, x: body.midX, y: faceY)
        for side in [-1.0, 1.0] {
            g.fill(Ellipse().path(in: CGRect(x: body.midX + side * 10.5 - 2.5, y: faceY + 2.5, width: 5, height: 3)),
                   with: .color(Palette.blush.opacity(0.6)))
        }
        drawMouth(&g, x: body.midX, y: faceY + 6)
        drawExtras(&g, body: body)
    }

    private var bodyColors: (Color, Color) {
        switch mood {
        case .panic: return (Color(red: 0.95, green: 0.47, blue: 0.40), Color(red: 0.84, green: 0.32, blue: 0.28))
        case .sleeping: return (Color(red: 0.82, green: 0.58, blue: 0.49), Color(red: 0.71, green: 0.46, blue: 0.38))
        default: return (Palette.clayLight, Palette.clay)
        }
    }

    private func drawArms(_ g: inout GraphicsContext, body: CGRect) {
        for side in [-1.0, 1.0] {
            var armY = body.midY - 1
            var height = 8.0
            switch mood {
            case .party: armY = body.minY - 2 + sin(t * 13 + side) * 1.5; height = 10
            case .panic: armY = body.midY - 5 + sin(t * 22 + side * 2) * 3
            case .busy: armY = body.midY + sin(t * 16 + side * 1.5) * 1.5
            default: break
            }
            let x = side < 0 ? body.minX - 3 : body.maxX - 2
            g.fill(Capsule().path(in: CGRect(x: x, y: armY, width: 5, height: height)), with: .color(Palette.clay))
        }
    }

    private func drawEyes(_ g: inout GraphicsContext, x: Double, y: Double) {
        let spread = 6.5
        for side in [-1.0, 1.0] {
            let ex = x + side * spread
            switch mood {
            case .chill, .busy, .confused:
                let blinking = fmod(t + side * 0.02, 4.2) < 0.14
                let eyeHeight = blinking ? 1.3 : (mood == .busy ? 5 : 6)
                let look = mood == .busy ? sin(t * 0.9) * 1.2 : 0
                g.fill(Capsule().path(in: CGRect(x: ex - 2.2 + look, y: y - eyeHeight / 2, width: 4.4, height: eyeHeight)),
                       with: .color(Palette.ink))
            case .nervous, .panic:
                let r = mood == .panic ? 4.0 : 3.4
                let pupil = mood == .panic ? 1.4 : 1.7
                let dart = mood == .panic ? sin(t * 60) * 0.5 : sin(t * 2.7) * 1.3
                g.fill(Circle().path(in: CGRect(x: ex - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white))
                g.fill(Circle().path(in: CGRect(x: ex - pupil + dart, y: y - pupil, width: pupil * 2, height: pupil * 2)),
                       with: .color(Palette.ink))
            case .sleeping:
                var p = Path()
                p.move(to: CGPoint(x: ex - 2.6, y: y - 0.5))
                p.addQuadCurve(to: CGPoint(x: ex + 2.6, y: y - 0.5), control: CGPoint(x: ex, y: y + 2.4))
                g.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            case .party:
                var p = Path()
                p.move(to: CGPoint(x: ex - 2.6, y: y + 1.2))
                p.addLine(to: CGPoint(x: ex, y: y - 1.8))
                p.addLine(to: CGPoint(x: ex + 2.6, y: y + 1.2))
                g.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func drawMouth(_ g: inout GraphicsContext, x: Double, y: Double) {
        let line = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        var p = Path()
        switch mood {
        case .chill:
            p.move(to: CGPoint(x: x - 3, y: y - 1))
            p.addQuadCurve(to: CGPoint(x: x + 3, y: y - 1), control: CGPoint(x: x, y: y + 2.5))
            g.stroke(p, with: .color(Palette.ink), style: line)
        case .busy:
            p.move(to: CGPoint(x: x - 2.5, y: y))
            p.addLine(to: CGPoint(x: x + 2.5, y: y))
            g.stroke(p, with: .color(Palette.ink), style: line)
        case .nervous:
            p.move(to: CGPoint(x: x - 4, y: y))
            p.addQuadCurve(to: CGPoint(x: x - 1.3, y: y), control: CGPoint(x: x - 2.7, y: y - 1.8))
            p.addQuadCurve(to: CGPoint(x: x + 1.3, y: y), control: CGPoint(x: x, y: y + 1.8))
            p.addQuadCurve(to: CGPoint(x: x + 4, y: y), control: CGPoint(x: x + 2.7, y: y - 1.8))
            g.stroke(p, with: .color(Palette.ink), style: line)
        case .panic:
            let open = 5 + sin(t * 18) * 0.8
            g.fill(Ellipse().path(in: CGRect(x: x - 2.3, y: y - 1.5, width: 4.6, height: open)), with: .color(Palette.ink))
        case .sleeping:
            let r = 1.2 + 0.3 * sin(t * 1.4)
            g.fill(Circle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                   with: .color(Palette.ink.opacity(0.8)))
        case .party:
            p.move(to: CGPoint(x: x - 4.5, y: y - 1.5))
            p.addLine(to: CGPoint(x: x + 4.5, y: y - 1.5))
            p.addQuadCurve(to: CGPoint(x: x - 4.5, y: y - 1.5), control: CGPoint(x: x, y: y + 7))
            p.closeSubpath()
            g.fill(p, with: .color(Palette.ink))
            g.fill(Ellipse().path(in: CGRect(x: x - 2, y: y + 0.6, width: 4, height: 2.2)), with: .color(Palette.blush))
        case .confused:
            p.move(to: CGPoint(x: x - 2, y: y + 0.6))
            p.addLine(to: CGPoint(x: x + 3, y: y - 0.8))
            g.stroke(p, with: .color(Palette.ink), style: line)
        }
    }

    private func drawExtras(_ g: inout GraphicsContext, body: CGRect) {
        switch mood {
        case .nervous, .panic:
            let speeds = mood == .panic ? [1.1, 0.9] : [0.7]
            for (i, speed) in speeds.enumerated() {
                let phase = fmod(t * speed + Double(i) * 0.5, 1)
                let x = i == 0 ? body.maxX - 3 : body.minX + 3
                drawDrop(&g, at: CGPoint(x: x, y: body.minY + 4 + phase * 9), opacity: 1 - phase)
            }
            if mood == .panic, sin(t * 10) > -0.3 {
                g.draw(Text("!").font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(Palette.cherry),
                       at: CGPoint(x: body.maxX + 3, y: body.minY - 3))
            }
        case .sleeping:
            for i in 0..<3 {
                let phase = fmod(t * 0.35 + Double(i) / 3, 1)
                var z = g
                z.opacity = sin(phase * .pi)
                z.draw(Text("z").font(.system(size: 6 + phase * 5, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.55, green: 0.6, blue: 0.85)),
                       at: CGPoint(x: body.maxX - 3 + phase * 10, y: body.minY - 1 - phase * 15))
            }
        case .party:
            let spots = [CGPoint(x: 7, y: 12), CGPoint(x: 49, y: 9), CGPoint(x: 51, y: 30), CGPoint(x: 5, y: 33)]
            for (i, spot) in spots.enumerated() {
                let s = max(0, sin(t * 5 + Double(i) * 1.7)) * 3.5
                drawSparkle(&g, at: spot, size: s)
            }
        case .confused:
            g.draw(Text("?").font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(.secondary),
                   at: CGPoint(x: body.maxX + 2, y: body.minY - 4 + sin(t * 2) * 1.5))
        case .chill, .busy:
            break
        }
    }

    private func drawDrop(_ g: inout GraphicsContext, at c: CGPoint, opacity: Double) {
        var tip = Path()
        tip.move(to: CGPoint(x: c.x - 1.8, y: c.y - 0.9))
        tip.addLine(to: CGPoint(x: c.x, y: c.y - 4.3))
        tip.addLine(to: CGPoint(x: c.x + 1.8, y: c.y - 0.9))
        tip.closeSubpath()
        var d = g
        d.opacity = opacity
        d.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(Palette.sweat))
        d.fill(tip, with: .color(Palette.sweat))
    }

    private func drawSparkle(_ g: inout GraphicsContext, at c: CGPoint, size s: Double) {
        guard s > 0.2 else { return }
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: c)
        g.fill(p, with: .color(Palette.gold))
    }
}

// MARK: - Environment hooks used when rendering still images / GIFs

private struct FrozenTimeKey: EnvironmentKey { static let defaultValue: Double? = nil }
private struct FrozenConfettiKey: EnvironmentKey { static let defaultValue: Double? = nil }
private struct SnapshotModeKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// When set, animations draw this exact moment instead of following the clock.
    var frozenTime: Double? {
        get { self[FrozenTimeKey.self] }
        set { self[FrozenTimeKey.self] = newValue }
    }
    /// Seconds since a confetti burst, for rendering confetti into still frames.
    var frozenConfetti: Double? {
        get { self[FrozenConfettiKey.self] }
        set { self[FrozenConfettiKey.self] = newValue }
    }
    /// Swaps live blur for a solid background, since image renderers can't capture blur.
    var snapshotMode: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}
