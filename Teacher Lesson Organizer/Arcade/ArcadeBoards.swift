import SwiftUI

struct QuickDrawRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var phase = Signal.waiting
    @State private var signalTime: ContinuousClock.Instant?
    @State private var times: [Int] = []

    private enum Signal { case waiting, go, between }
    private let rounds = 5

    var body: some View {
        VStack(spacing: 16) {
            Text("Reaction \(times.count + 1) of \(rounds)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ArcadePalette.muted)
            Button(action: takeShot) {
                VStack(spacing: 14) {
                    Image(systemName: phase == .go ? "bolt.fill" : "hourglass")
                        .font(.largeTitle)
                    Text(prompt)
                        .font(.system(.title, design: .serif).weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(phase == .go ? ArcadePalette.brass : ArcadePalette.velvet, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(phase == .go ? ArcadePalette.backdrop : ArcadePalette.cream)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("arcade.reaction.signal")
            Text(times.last.map { "Last reaction: \($0) ms" } ?? "Wait for TAP NOW.")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ArcadePalette.muted)
        }
        .task(id: phase) {
            guard phase == .waiting else { return }
            do {
                try await Task.sleep(for: .milliseconds(Int.random(in: 900...2500)))
                try Task.checkCancellation()
                signalTime = .now
                phase = .go
            } catch { }
        }
        .sensoryFeedback(.impact, trigger: phase == .go) { _, ready in ready }
    }

    private var prompt: String {
        switch phase {
        case .waiting: "Hold…"
        case .go: "TAP NOW"
        case .between: "Next reaction"
        }
    }

    private func takeShot() {
        switch phase {
        case .waiting:
            finish(ArcadeResult(score: 0, message: "False start. Wait for the signal."))
        case .go:
            guard let signalTime else { return }
            let reaction = max(1, Int((elapsedSeconds(since: signalTime) * 1000).rounded()))
            times.append(reaction)
            if times.count == rounds {
                let average = Double(times.reduce(0, +)) / Double(rounds)
                finish(ArcadeResult(score: Int(average.rounded()), message: nil))
            } else {
                phase = .between
            }
        case .between:
            phase = .waiting
        }
    }
}

struct MemoryGridRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var sequence = [Int.random(in: 0..<9), Int.random(in: 0..<9)]
    @State private var inputIndex = 0
    @State private var best = 0
    @State private var lighting: Int?
    @State private var isShowing = true
    @State private var cleared = false

    private let mint = ArcadePalette.tint(for: .memory)

    var body: some View {
        VStack(spacing: 18) {
            Text(cleared ? "Pattern cleared" : isShowing ? "Watch the pattern" : "Repeat the pattern")
                .font(.system(.title2, design: .serif).weight(.semibold))
            Text("Pattern: \(sequence.count)  •  Cleared: \(best)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ArcadePalette.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<9) { index in
                    Button {
                        tap(index)
                    } label: {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(lighting == index ? mint : mint.opacity(0.12))
                            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(mint.opacity(lighting == index ? 0.9 : 0.30)) }
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                    .disabled(isShowing || cleared)
                    .accessibilityLabel("Tile \(index + 1)")
                    .accessibilityAddTraits(lighting == index ? [.isSelected] : [])
                }
            }
            if cleared {
                ArcadeAction(title: "Next pattern", tint: mint) {
                    inputIndex = 0
                    isShowing = true
                    cleared = false
                    sequence.append(Int.random(in: 0..<9))
                }
            }
        }
        .padding(18)
        .arcadePanel()
        .task(id: sequence.count) {
            do {
                try await Task.sleep(for: .milliseconds(700))
                for tile in sequence {
                    try Task.checkCancellation()
                    lighting = tile
                    try await Task.sleep(for: .milliseconds(420))
                    lighting = nil
                    try await Task.sleep(for: .milliseconds(170))
                }
                try Task.checkCancellation()
                isShowing = false
            } catch { }
        }
    }

    private func tap(_ tile: Int) {
        guard !isShowing, !cleared, sequence.indices.contains(inputIndex) else { return }
        guard sequence[inputIndex] == tile else {
            finish(ArcadeResult(score: best, message: "That tile was out of order."))
            return
        }
        inputIndex += 1
        if inputIndex == sequence.count {
            best = sequence.count
            cleared = true
        }
    }
}

struct ColorSwitchRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var ink = Ink.allCases.randomElement() ?? .gold
    @State private var word = Ink.allCases.randomElement() ?? .jade
    @State private var score = 0
    @State private var remaining = 30
    @State private var started: ContinuousClock.Instant?

    private enum Ink: String, CaseIterable {
        case gold = "Gold", rose = "Rose", jade = "Jade", lilac = "Lilac"

        var tint: Color {
            switch self {
            case .gold: ArcadePalette.brass
            case .rose: ArcadePalette.tint(for: .colors)
            case .jade: ArcadePalette.tint(for: .memory)
            case .lilac: ArcadePalette.tint(for: .stack)
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Score \(score)")
                Spacer()
                Text("\(remaining)s")
            }
            .font(.headline.monospacedDigit())
            .foregroundStyle(ArcadePalette.muted)
            Text("Match the ink")
                .font(.subheadline)
            Text(word.rawValue.uppercased())
                .font(.system(.largeTitle, design: .monospaced).weight(.black))
                .foregroundStyle(ink.tint)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityLabel("Word: \(word.rawValue). Ink: \(ink.rawValue).")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(Ink.allCases, id: \.self) { choice in
                    ArcadeAction(title: choice.rawValue, tint: choice.tint) { choose(choice) }
                }
            }
        }
        .padding(18)
        .arcadePanel()
        .task {
            let start = ContinuousClock.now
            started = start
            do {
                while !Task.isCancelled {
                    let seconds = elapsedSeconds(since: start)
                    if seconds >= 30 {
                        finish(ArcadeResult(score: score, message: nil))
                        return
                    }
                    remaining = Int(ceil(30 - seconds))
                    try await Task.sleep(for: .milliseconds(150))
                }
            } catch { }
        }
    }

    private func choose(_ choice: Ink) {
        guard let started, elapsedSeconds(since: started) < 30 else { return }
        score = max(0, score + (choice == ink ? 1 : -1))
        let nextInk = Ink.allCases.filter { $0 != ink }.randomElement() ?? ink
        ink = nextInk
        word = Ink.allCases.filter { $0 != ink }.randomElement() ?? word
    }
}

struct StackRushRound: View {
    let finish: (ArcadeResult) -> Void
    @State private var tower = [StackBlock.base]
    @State private var sweepStart = ContinuousClock.now
    private let color = ArcadePalette.tint(for: .stack)

    var body: some View {
        VStack(spacing: 17) {
            Text("Placed: \(tower.count - 1)")
                .font(.headline.monospacedDigit())
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let visible = Array(tower.suffix(8))
                    let row: CGFloat = 23
                    ZStack(alignment: .bottomLeading) {
                        ForEach(visible.indices, id: \.self) { index in
                            block(visible[index], width: width, row: row, level: index, moving: false)
                        }
                        block(currentBlock, width: width, row: row, level: visible.count, moving: true)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(height: 222)
            .padding(.horizontal, 12)
            .background(.black.opacity(0.23), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)

            ArcadeAction(title: "Drop block", tint: color, action: drop)
                .accessibilityIdentifier("arcade.stack.drop")
        }
        .padding(18)
        .arcadePanel()
        .sensoryFeedback(.impact, trigger: tower.count)
    }

    private var currentBlock: StackBlock {
        StackBlock.moving(width: tower.last?.width ?? StackBlock.base.width,
                          elapsed: elapsedSeconds(since: sweepStart), level: tower.count - 1)
    }

    private func block(_ model: StackBlock, width: CGFloat, row: CGFloat, level: Int, moving: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(moving ? ArcadePalette.brass : color.opacity(level.isMultiple(of: 2) ? 0.88 : 0.65))
            .frame(width: width * model.width, height: row - 2)
            .offset(x: width * model.left, y: -CGFloat(level) * row - 3)
    }

    private func drop() {
        guard let support = tower.last, let fitted = currentBlock.overlap(with: support) else {
            finish(ArcadeResult(score: tower.count - 1, message: "The block missed the tower."))
            return
        }
        tower.append(fitted)
        sweepStart = .now
    }
}
