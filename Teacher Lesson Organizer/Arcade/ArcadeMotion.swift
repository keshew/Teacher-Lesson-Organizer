import Foundation
import CoreGraphics

struct SnakeBoard {
    enum Tick { case moved, hit, cleared }

    static let grid = SquareGrid(size: 12)
    private(set) var body = [76, 75, 74]
    private(set) var food: Int? = 82
    private(set) var score = 0
    private var direction = GridDirection.right
    private var queued: GridDirection?

    mutating func turn(_ turn: GridDirection) {
        guard turn != direction, turn != direction.opposite, queued == nil else { return }
        queued = turn
    }

    mutating func advance() -> Tick {
        if let queued { direction = queued; self.queued = nil }
        guard let head = body.first,
              let next = Self.grid.neighbor(of: head, row: direction.step.row, column: direction.step.column) else { return .hit }
        let grows = next == food
        guard !(grows ? body : Array(body.dropLast())).contains(next) else { return .hit }
        body.insert(next, at: 0)
        if grows {
            score += 1
            let occupied = Set(body)
            food = (0..<Self.grid.count).filter { !occupied.contains($0) }.randomElement()
            if food == nil { return .cleared }
        } else {
            body.removeLast()
        }
        return .moved
    }
}

struct BreakerTable {
    static let width: CGFloat = 320
    static let height: CGFloat = 376
    static let paddleY: CGFloat = 346
    static let paddleWidth: CGFloat = 66
    static let radius: CGFloat = 5
    static let bricks: [CGRect] = (0..<24).map {
        CGRect(x: 17 + CGFloat($0 % 6) * 48, y: 24 + CGFloat($0 / 6) * 23, width: 44, height: 17)
    }

    private(set) var bricksInPlay = Set(bricks.indices)
    private(set) var ball = CGPoint(x: width / 2, y: paddleY - 7)
    private(set) var paddleX = width / 2
    private(set) var lives = 3
    private(set) var moving = false
    private var velocity = CGVector(dx: 132, dy: -186)

    var score: Int { (Self.bricks.count - bricksInPlay.count) * 100 }
    var finished: Bool { lives == 0 || bricksInPlay.isEmpty }

    mutating func aim(at x: CGFloat) {
        paddleX = min(Self.width - Self.paddleWidth / 2, max(Self.paddleWidth / 2, x))
        if !moving { ball.x = paddleX }
    }

    mutating func serve() {
        guard !finished, !moving else { return }
        moving = true
        velocity = CGVector(dx: lives.isMultiple(of: 2) ? -132 : 132, dy: -186)
    }

    mutating func tick(seconds: CGFloat) {
        guard moving else { return }
        let radius = Self.radius
        let previous = ball
        ball.x += velocity.dx * seconds
        ball.y += velocity.dy * seconds

        if ball.x <= radius || ball.x >= Self.width - radius {
            ball.x = min(Self.width - radius, max(radius, ball.x))
            velocity.dx = ball.x <= radius ? abs(velocity.dx) : -abs(velocity.dx)
        }
        if ball.y <= radius {
            ball.y = radius
            velocity.dy = abs(velocity.dy)
        }

        if velocity.dy > 0, previous.y + radius <= Self.paddleY,
           ball.y + radius >= Self.paddleY,
           abs(ball.x - paddleX) <= Self.paddleWidth / 2 + radius {
            ball.y = Self.paddleY - radius
            let offset = (ball.x - paddleX) / (Self.paddleWidth / 2)
            velocity.dx = min(196, max(-196, offset * 185))
            velocity.dy = -max(155, 215 - abs(velocity.dx) / 4)
        }

        if let hit = bricksInPlay.sorted().first(where: {
            Self.bricks[$0].insetBy(dx: -radius, dy: -radius).contains(ball)
        }) {
            let frame = Self.bricks[hit].insetBy(dx: -radius, dy: -radius)
            if previous.y <= frame.minY || previous.y >= frame.maxY {
                velocity.dy = -velocity.dy
            } else {
                velocity.dx = -velocity.dx
            }
            bricksInPlay.remove(hit)
        }

        if ball.y - radius > Self.height {
            lives -= 1
            moving = false
            ball = CGPoint(x: paddleX, y: Self.paddleY - Self.radius - 2)
        }
        if finished { moving = false }
    }
}
