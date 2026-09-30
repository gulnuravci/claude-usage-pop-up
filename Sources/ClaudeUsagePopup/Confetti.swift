import SwiftUI

/// A burst of confetti that fires whenever `trigger` changes.
struct ConfettiView: View {
    let trigger: Int
    /// Where the burst starts, given the view's size.
    var origin: (CGSize) -> CGPoint

    @Environment(\.frozenConfetti) private var frozenElapsed
    @State private var burstStart: Date?
    @State private var pieces = Piece.burst()

    static let duration = 2.6

    var body: some View {
        Group {
            if let frozenElapsed {
                canvas(elapsed: frozenElapsed)
            } else if let burstStart {
                TimelineView(.animation) { context in
                    canvas(elapsed: context.date.timeIntervalSince(burstStart))
                }
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _ in
            let start = Date()
            pieces = Piece.burst()
            burstStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration) {
                if burstStart == start { burstStart = nil }
            }
        }
    }

    private func canvas(elapsed t: Double) -> some View {
        Canvas { context, size in
            guard t >= 0, t < Self.duration else { return }
            let o = origin(size)
            let fade = min(1, (Self.duration - t) / 0.8)
            for piece in pieces {
                var c = context
                c.opacity = fade
                c.translateBy(x: o.x + piece.vx * t, y: o.y + piece.vy * t + 260 * t * t)
                c.rotate(by: .radians(piece.spin * t))
                c.scaleBy(x: max(0.2, abs(cos(t * piece.flutter))), y: 1)
                let shape = piece.round
                    ? Path(ellipseIn: CGRect(x: -2.5, y: -2.5, width: 5, height: 5))
                    : Path(roundedRect: CGRect(x: -3.5, y: -1.8, width: 7, height: 3.6), cornerRadius: 1)
                c.fill(shape, with: .color(piece.color))
            }
        }
    }

    struct Piece {
        let vx, vy, spin, flutter: Double
        let color: Color
        let round: Bool

        static let colors = [Palette.clayLight, Palette.gold, Palette.blush, Palette.sage,
                             Color(red: 0.55, green: 0.72, blue: 1.0), Color(red: 0.78, green: 0.6, blue: 1.0)]

        static func burst(count: Int = 48) -> [Piece] {
            (0..<count).map { _ in
                // Fan upward and to the right (the card sits to the mascot's right).
                let angle = Double.random(in: -2.4 ... -0.25)
                let speed = Double.random(in: 140 ... 330)
                return Piece(vx: cos(angle) * speed, vy: sin(angle) * speed,
                             spin: .random(in: -9 ... 9), flutter: .random(in: 4 ... 11),
                             color: colors.randomElement()!, round: Bool.random() && Bool.random())
            }
        }
    }
}
