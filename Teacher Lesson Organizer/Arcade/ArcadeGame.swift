import Foundation

enum ArcadeGenre: String, CaseIterable, Identifiable {
    case reflex = "Reflex"
    case puzzle = "Puzzle"
    case memory = "Memory"
    case skill = "Skill"

    var id: String { rawValue }
}

enum ArcadeGame: String, CaseIterable, Identifiable {
    case reaction, memory, colors, stack
    case lights, sliding, merge, mines, pairs, snake, numbers, breaker

    var id: String { rawValue }

    private var details: (title: String, genre: ArcadeGenre, symbol: String, instructions: String) {
        switch self {
        case .reaction:
            ("Quick Draw", .reflex, "bolt.fill", "Wait for the signal, then tap. Your score is the average of five reactions.")
        case .memory:
            ("Memory Grid", .memory, "square.grid.3x3.fill", "Watch the tiles, then tap them in the same order. Each round adds one tile.")
        case .colors:
            ("Color Switch", .reflex, "circle.lefthalf.filled", "Tap the ink color, even when the word says something else. Correct answers add a point and misses subtract one. You have 30 seconds.")
        case .stack:
            ("Stack Rush", .skill, "square.stack.3d.up.fill", "Tap to drop the moving block. The part past the edge falls away. A complete miss ends the run.")
        case .lights:
            ("Blackout", .puzzle, "lightbulb.slash.fill", "Switch off all the lights. Tapping a tile toggles it and the tiles directly next to it. Fewer moves is better.")
        case .sliding:
            ("Sliding Nine", .puzzle, "square.grid.3x3", "Slide tiles into the empty space. Put 1 through 8 in order with the space in the lower right.")
        case .merge:
            ("Merge Tiles", .puzzle, "square.on.square", "Swipe to slide the board. Matching tiles merge and add their new value to your score. Play until the board runs out of moves.")
        case .mines:
            ("Mine Room", .puzzle, "flag.fill", "Reveal every safe tile. Numbers tell you how many mines touch that tile. Switch to Flag mode to mark a mine.")
        case .pairs:
            ("Pair House", .memory, "rectangle.on.rectangle.angled", "Turn over two cards at a time and find all eight matching pairs. Fewer attempts is better.")
        case .snake:
            ("Snake Run", .skill, "point.topleft.down.to.point.bottomright.curvepath", "Use the arrows or swipe to turn. Eat the dots and avoid hitting the wall or your tail.")
        case .numbers:
            ("Number Rush", .reflex, "number", "Tap 1 through 16 in order as quickly as you can. A wrong tile adds a one-second penalty.")
        case .breaker:
            ("Brick Breaker", .skill, "rectangle.split.3x1.fill", "Drag the paddle to keep the ball in play. Clear all bricks before you lose three balls.")
        }
    }

    var title: String { details.title }
    var genre: ArcadeGenre { details.genre }
    var symbol: String { details.symbol }
    var instructions: String { details.instructions }

    var recordLabel: String {
        switch self {
        case .reaction, .mines, .numbers: "Fastest time"
        case .lights, .sliding: "Fewest moves"
        case .pairs: "Fewest attempts"
        case .memory: "Longest pattern"
        case .stack: "Tallest stack"
        default: "High score"
        }
    }

    func format(_ score: Int) -> String {
        switch self {
        case .reaction: "\(score) ms"
        case .mines, .numbers: String(format: "%.1f s", Double(score) / 10)
        case .memory: "\(score) \(score == 1 ? "tile" : "tiles")"
        case .stack: "\(score) \(score == 1 ? "block" : "blocks")"
        case .lights, .sliding: "\(score) \(score == 1 ? "move" : "moves")"
        case .pairs: "\(score) \(score == 1 ? "attempt" : "attempts")"
        case .snake: "\(score) \(score == 1 ? "dot" : "dots")"
        default: "\(score) \(score == 1 ? "point" : "points")"
        }
    }

    func beats(_ best: Int?, with score: Int) -> Bool {
        guard score > 0 else { return false }
        guard let best else { return true }
        return switch self {
        case .reaction, .lights, .sliding, .mines, .pairs, .numbers: score < best
        default: score > best
        }
    }
}

struct ArcadeRecords {
    private let defaults: UserDefaults
    private let prefix = "teacherLessonOrganizer.arcade."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var recentGame: ArcadeGame? {
        defaults.string(forKey: prefix + "recent").flatMap(ArcadeGame.init(rawValue:))
    }

    subscript(game: ArcadeGame) -> Int? {
        let score = defaults.integer(forKey: prefix + "best." + game.rawValue)
        return score > 0 ? score : nil
    }

    func rounds(for game: ArcadeGame) -> Int {
        defaults.integer(forKey: prefix + "rounds." + game.rawValue)
    }

    @discardableResult
    func record(_ score: Int, for game: ArcadeGame) -> Bool {
        let roundsKey = prefix + "rounds." + game.rawValue
        defaults.set(rounds(for: game) + 1, forKey: roundsKey)
        defaults.set(game.rawValue, forKey: prefix + "recent")
        guard game.beats(self[game], with: score) else { return false }
        defaults.set(score, forKey: prefix + "best." + game.rawValue)
        return true
    }
}

struct StackBlock: Equatable {
    let left: Double
    let width: Double

    static let base = StackBlock(left: 0.18, width: 0.64)

    func overlap(with support: Self) -> Self? {
        let left = max(left, support.left)
        let right = min(self.left + width, support.left + support.width)
        guard right - left >= 0.01 else { return nil }
        return Self(left: left, width: right - left)
    }

    static func moving(width: Double, elapsed: Double, level: Int) -> Self {
        let frequency = min(1.25, 0.44 + Double(level) * 0.055)
        let fraction = (1 - cos(elapsed * frequency * 2 * .pi)) / 2
        return Self(left: fraction * (1 - width), width: width)
    }
}
