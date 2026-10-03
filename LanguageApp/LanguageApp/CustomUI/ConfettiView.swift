//
//  ConfettiView.swift
//  LanguageApp
//
//  Lightweight confetti burst (Canvas + TimelineView, no assets) for celebrations.
//  Plays once for `duration` seconds; ignores touches. Respects Reduce Motion.
//

import SwiftUI

struct ConfettiView: View {
    var colors: [Color] = [.orange, .yellow, .pink, .mint, .blue, .purple]
    var count = 90
    var duration: TimeInterval = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var pieces: [Piece] = []
    @State private var isFinished = false

    private struct Piece {
        let x: Double          // 0…1 of the width
        let delay: Double      // seconds
        let speed: Double      // fraction of the height per second
        let drift: Double      // horizontal sway in points
        let spin: Double       // radians per second
        let size: CGSize
        let colorIndex: Int
    }

    var body: some View {
        Group {
            if reduceMotion || isFinished {
                EmptyView()
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(start)
                        for piece in pieces {
                            let t = elapsed - piece.delay
                            guard t > 0 else { continue }
                            let y = -20 + t * piece.speed * size.height
                            guard y < size.height + 20 else { continue }
                            let x = piece.x * size.width + sin(t * 3 + piece.x * 10) * piece.drift
                            let fade = max(0, min(1, (duration + 0.5 - t) / 0.5))
                            var copy = context
                            copy.opacity = fade
                            copy.translateBy(x: x, y: y)
                            copy.rotate(by: .radians(t * piece.spin))
                            let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                              width: piece.size.width, height: piece.size.height)
                            copy.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                                      with: .color(colors[piece.colorIndex % colors.count]))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            start = .now
            pieces = (0..<count).map { _ in
                Piece(x: .random(in: 0...1),
                      delay: .random(in: 0...0.8),
                      speed: .random(in: 0.35...0.7),
                      drift: .random(in: 8...30),
                      spin: .random(in: -6...6),
                      size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
                      colorIndex: .random(in: 0..<colors.count))
            }
        }
        .task {
            // Stop redrawing once every piece has fallen.
            try? await Task.sleep(for: .seconds(duration + 1))
            isFinished = true
        }
    }
}

#Preview {
    ConfettiView()
}
