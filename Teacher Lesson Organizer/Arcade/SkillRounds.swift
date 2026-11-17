import SwiftUI

struct SnakeRunRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var board = SnakeBoard()
    @State private var moving = false

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Dots eaten", value: String(board.score))
            Canvas { context, size in
                let width = size.width / CGFloat(SnakeBoard.grid.size)
                let tint = ArcadePalette.tint(for: .snake)
                for index in 0..<SnakeBoard.grid.count {
                    let column = index % SnakeBoard.grid.size
                    let row = index / SnakeBoard.grid.size
                    let rect = CGRect(x: CGFloat(column) * width + 1, y: CGFloat(row) * width + 1,
                                      width: width - 2, height: width - 2)
                    if index == board.food {
                        context.fill(Path(ellipseIn: rect.insetBy(dx: 3, dy: 3)), with: .color(ArcadePalette.brass))
                    } else {
                        let color = index == board.body.first ? tint : board.body.contains(index) ? tint.opacity(0.59) : .white.opacity(0.055)
                        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 15).onEnded { turn(direction(from: $0.translation)) })
            .accessibilityLabel("Snake board, \(board.score) dots eaten")
            if moving {
                ArrowControls(action: turn)
            } else {
                ArcadeAction(title: "Go", tint: ArcadePalette.tint(for: .snake)) { moving = true }
            }
        }
        .padding(14)
        .arcadePanel()
        .sensoryFeedback(.impact, trigger: board.score)
        .task(id: moving) {
            guard moving else { return }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(max(85, 240 - board.score * 11)))
                    try Task.checkCancellation()
                    switch board.advance() {
                    case .moved: break
                    case .hit:
                        finish(ArcadeResult(score: board.score, message: "The snake hit an obstacle."))
                        return
                    case .cleared:
                        finish(ArcadeResult(score: board.score, message: "Board cleared."))
                        return
                    }
                }
            } catch { }
        }
    }

    private func turn(_ direction: GridDirection) {
        guard moving else { return }
        board.turn(direction)
    }
}

struct BrickBreakerRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var table = BreakerTable()

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Score", value: table.score.formatted())
            RoundMetric(label: "Balls left", value: String(table.lives))
            Canvas { context, size in
                let scaleX = size.width / BreakerTable.width
                let scaleY = size.height / BreakerTable.height
                let colors = [ArcadePalette.brass, ArcadePalette.tint(for: .breaker),
                              ArcadePalette.tint(for: .stack), ArcadePalette.tint(for: .memory)]
                for index in table.bricksInPlay {
                    let frame = BreakerTable.bricks[index]
                    let rect = CGRect(x: frame.minX * scaleX, y: frame.minY * scaleY,
                                      width: frame.width * scaleX, height: frame.height * scaleY)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(colors[index / 6]))
                }
                let paddle = CGRect(x: (table.paddleX - BreakerTable.paddleWidth / 2) * scaleX,
                                    y: BreakerTable.paddleY * scaleY,
                                    width: BreakerTable.paddleWidth * scaleX, height: 8 * scaleY)
                context.fill(Path(roundedRect: paddle, cornerRadius: 4), with: .color(ArcadePalette.brass))
                let radius = BreakerTable.radius
                context.fill(Path(ellipseIn: CGRect(x: (table.ball.x - radius) * scaleX,
                                                   y: (table.ball.y - radius) * scaleY,
                                                   width: radius * 2 * scaleX, height: radius * 2 * scaleY)),
                             with: .color(ArcadePalette.cream))
            }
            .aspectRatio(BreakerTable.width / BreakerTable.height, contentMode: .fit)
            .background(.black.opacity(0.31), in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottom) {
                if !table.moving {
                    Text("Drag here to aim")
                        .font(.caption)
                        .foregroundStyle(ArcadePalette.muted)
                        .padding(5)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged {
                            guard geometry.size.width > 0 else { return }
                            table.aim(at: $0.location.x * BreakerTable.width / geometry.size.width)
                        })
                }
            }
            .accessibilityLabel("Brick breaker board")
            .accessibilityAdjustableAction { move in
                switch move {
                case .increment: table.aim(at: table.paddleX + 28)
                case .decrement: table.aim(at: table.paddleX - 28)
                @unknown default: break
                }
            }
            if !table.moving {
                ArcadeAction(title: "Serve", tint: ArcadePalette.tint(for: .breaker)) { table.serve() }
            }
        }
        .padding(14)
        .arcadePanel()
        .task(id: table.moving) {
            guard table.moving else { return }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(20))
                    try Task.checkCancellation()
                    table.tick(seconds: 0.02)
                    if table.finished {
                        let summary = table.bricksInPlay.isEmpty ? "All bricks cleared." : "Out of balls."
                        finish(ArcadeResult(score: table.score, message: summary))
                        return
                    }
                    if !table.moving { return }
                }
            } catch { }
        }
    }
}
