import SwiftUI

struct ArcadeGrid<Cell: View>: View {
    let columns: Int
    let count: Int
    let cell: (Int) -> Cell

    init(columns: Int, count: Int, @ViewBuilder cell: @escaping (Int) -> Cell) {
        self.columns = columns
        self.count = count
        self.cell = cell
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(0..<count, id: \.self, content: cell)
        }
    }
}

struct ArcadeCell: View {
    var text = ""
    var symbol: String?
    var tint = ArcadePalette.cream
    var fill = Color.white.opacity(0.075)

    var body: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(fill)
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(.headline).weight(.semibold))
                        .foregroundStyle(tint)
                } else {
                    Text(text)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .padding(4)
                        .foregroundStyle(tint)
                }
            }
            .aspectRatio(1, contentMode: .fit)
    }
}

struct RoundMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(ArcadePalette.muted)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.headline)
    }
}

struct BlackoutRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var board = BlackoutBoard()

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Lights on", value: String(board.lit.count))
            ArcadeGrid(columns: 4, count: 16) { index in
                let on = board.lit.contains(index)
                Button {
                    board.toggle(index)
                    if board.lit.isEmpty {
                        finish(ArcadeResult(score: board.moves, message: "Every light is off."))
                    }
                } label: {
                    ArcadeCell(symbol: on ? "lightbulb.fill" : "lightbulb.slash",
                               tint: on ? ArcadePalette.backdrop : ArcadePalette.muted,
                               fill: on ? ArcadePalette.tint(for: .lights) : .white.opacity(0.075))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Light \(index + 1), \(on ? "on" : "off")")
            }
            RoundMetric(label: "Moves", value: String(board.moves))
        }
        .padding(14)
        .arcadePanel()
    }
}

struct SlidingNineRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var board = SlidingBoard()

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Moves", value: String(board.moves))
            ArcadeGrid(columns: 3, count: 9) { index in
                let value = board.tiles[index]
                let ordered = value == index + 1
                if value == 0 {
                    ArcadeCell(fill: .black.opacity(0.30)).accessibilityLabel("Empty tile")
                } else {
                    Button {
                        guard board.slide(index) else { return }
                        if board.tiles == SlidingBoard.goal {
                            finish(ArcadeResult(score: board.moves, message: "Puzzle solved."))
                        }
                    } label: {
                        ArcadeCell(text: String(value), tint: ordered ? ArcadePalette.brass : ArcadePalette.cream,
                                   fill: ordered ? ArcadePalette.brass.opacity(0.21) : .white.opacity(0.075))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tile \(value)")
                }
            }
        }
        .padding(14)
        .arcadePanel()
    }
}

struct ArrowControls: View {
    let action: (GridDirection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            arrow("Left", icon: "arrow.left", direction: .left)
            arrow("Up", icon: "arrow.up", direction: .up)
            arrow("Down", icon: "arrow.down", direction: .down)
            arrow("Right", icon: "arrow.right", direction: .right)
        }
    }

    private func arrow(_ title: String, icon: String, direction: GridDirection) -> some View {
        Button(title, systemImage: icon) { action(direction) }
            .labelStyle(.iconOnly)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            .buttonStyle(.plain)
            .accessibilityLabel(title)
    }
}

func direction(from translation: CGSize) -> GridDirection {
    if abs(translation.width) >= abs(translation.height) {
        translation.width < 0 ? .left : .right
    } else {
        translation.height < 0 ? .up : .down
    }
}

struct MergeTilesRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var board = MergeBoard()

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Score", value: board.points.formatted())
            ArcadeGrid(columns: 4, count: 16) { index in
                let value = board.tiles[index]
                ArcadeCell(text: value == 0 ? "" : String(value),
                           tint: value >= 32 ? ArcadePalette.backdrop : ArcadePalette.cream,
                           fill: tileColor(value))
                    .accessibilityLabel(value == 0 ? "Empty" : String(value))
            }
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 17).onEnded { move(direction(from: $0.translation)) })
            ArrowControls(action: move)
        }
        .padding(14)
        .arcadePanel()
    }

    private func move(_ direction: GridDirection) {
        _ = board.move(direction)
        if !board.canMove { finish(ArcadeResult(score: board.points, message: "No more moves.")) }
    }

    private func tileColor(_ value: Int) -> Color {
        switch value {
        case 0: .black.opacity(0.25)
        case 2: .white.opacity(0.10)
        case 4: ArcadePalette.brass.opacity(0.25)
        case 8: ArcadePalette.tint(for: .merge).opacity(0.35)
        case 16: ArcadePalette.velvet
        case 32, 64: ArcadePalette.tint(for: .lights).opacity(0.86)
        default: ArcadePalette.brass
        }
    }
}

struct MineRoomRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var board = MineBoard()
    @State private var flags = false
    @State private var started = ContinuousClock.now

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Safe tiles", value: "\(board.revealed.count) / \(MineBoard.grid.count - MineBoard.mineCount)")
            Picker("Tile action", selection: $flags) {
                Text("Reveal").tag(false)
                Text("Flag").tag(true)
            }
            .pickerStyle(.segmented)
            ArcadeGrid(columns: 5, count: 25) { index in
                let open = board.revealed.contains(index)
                let flagged = board.flags.contains(index)
                let count = open ? board.countAround(index) : 0
                Button {
                    if flags {
                        board.flag(index)
                    } else if !board.reveal(index) {
                        finish(ArcadeResult(score: 0, message: "You opened a mine."))
                    } else if board.cleared {
                        let time = max(1, Int((elapsedSeconds(since: started) * 10).rounded()))
                        finish(ArcadeResult(score: time, message: "All safe tiles cleared."))
                    }
                } label: {
                    ArcadeCell(text: count == 0 ? "" : String(count), symbol: flagged ? "flag.fill" : nil,
                               tint: flagged ? ArcadePalette.brass : ArcadePalette.cream,
                               fill: open ? .black.opacity(0.33) : .white.opacity(0.10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tileLabel(index, open: open, flagged: flagged, count: count))
            }
        }
        .padding(14)
        .arcadePanel()
        .onAppear { started = .now }
    }

    private func tileLabel(_ index: Int, open: Bool, flagged: Bool, count: Int) -> String {
        let name = "Tile \(index + 1)"
        if flagged { return name + ", flagged" }
        if open { return name + ", \(count) nearby mines" }
        return name + ", hidden"
    }
}

struct PairHouseRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var cards = (Array(0..<8) + Array(0..<8)).shuffled()
    @State private var first: Int?
    @State private var second: Int?
    @State private var matched: Set<Int> = []
    @State private var attempts = 0

    private let marks = ["moon.stars.fill", "drop.fill", "flame.fill", "leaf.fill",
                         "sparkles", "heart.fill", "key.fill", "sun.max.fill"]

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Pairs", value: "\(matched.count / 2) / 8")
            ArcadeGrid(columns: 4, count: 16) { index in
                let open = first == index || second == index || matched.contains(index)
                Button {
                    turn(index)
                } label: {
                    ArcadeCell(symbol: open ? marks[cards[index]] : "diamond",
                               tint: open ? ArcadePalette.brass : ArcadePalette.muted,
                               fill: matched.contains(index) ? ArcadePalette.brass.opacity(0.18) : .white.opacity(0.075))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Card \(index + 1), \(marks[cards[index]])" : "Card \(index + 1), face down")
            }
            RoundMetric(label: "Attempts", value: String(attempts))
        }
        .padding(14)
        .arcadePanel()
        .task(id: second) {
            guard second != nil else { return }
            do {
                try await Task.sleep(for: .milliseconds(720))
                try Task.checkCancellation()
                first = nil
                second = nil
            } catch { }
        }
    }

    private func turn(_ index: Int) {
        guard second == nil, !matched.contains(index), first != index else { return }
        guard let first else { first = index; return }
        attempts += 1
        if cards[first] == cards[index] {
            matched.formUnion([first, index])
            self.first = nil
            if matched.count == cards.count {
                finish(ArcadeResult(score: attempts, message: "All pairs matched."))
            }
        } else {
            second = index
        }
    }
}

struct NumberRushRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var tiles = Array(1...16).shuffled()
    @State private var next = 1
    @State private var penalty = 0
    @State private var started = ContinuousClock.now

    var body: some View {
        VStack(spacing: 13) {
            RoundMetric(label: "Find", value: String(next))
            ArcadeGrid(columns: 4, count: 16) { index in
                let value = tiles[index]
                Button { tap(value) } label: {
                    ArcadeCell(text: value < next ? "" : String(value),
                               tint: ArcadePalette.cream,
                               fill: value < next ? .black.opacity(0.24) : ArcadePalette.brass.opacity(0.17))
                }
                .buttonStyle(.plain)
                .disabled(value < next)
                .accessibilityLabel("Number \(value)")
            }
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                RoundMetric(label: "Time", value: ArcadeGame.numbers.format(max(0, Int(elapsedSeconds(since: started) * 10) + penalty)))
            }
            if penalty > 0 {
                Text("Penalty: +\(penalty / 10)s")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(ArcadePalette.brass)
            }
        }
        .padding(14)
        .arcadePanel()
        .onAppear { started = .now }
    }

    private func tap(_ value: Int) {
        guard value >= next else { return }
        if value != next {
            penalty += 10
        } else if next == 16 {
            let score = max(1, Int((elapsedSeconds(since: started) * 10).rounded()) + penalty)
            finish(ArcadeResult(score: score, message: "All sixteen in order."))
        } else {
            next += 1
        }
    }
}
