import SwiftUI

struct ArcadeResult {
    let score: Int
    let message: String?
}

struct ArcadeRound: View {
    let game: ArcadeGame
    let records: ArcadeRecords

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var state = RoundState.ready

    private enum RoundState {
        case ready
        case playing
        case interrupted
        case finished(ArcadeResult, newBest: Bool)
    }

    private var tint: Color { ArcadePalette.tint(for: game) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to games")
                Text(game.title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 22) {
                    switch state {
                    case .ready:
                        readyCard(interrupted: false)
                    case .interrupted:
                        readyCard(interrupted: true)
                    case .playing:
                        gameBoard
                    case let .finished(result, newBest):
                        resultCard(result, newBest: newBest)
                    }
                }
                .padding(20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(ArcadePalette.cream)
        .background {
            RadialGradient(colors: [ArcadePalette.velvet, ArcadePalette.backdrop], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onChange(of: phase) { _, value in
            if value == .background, case .playing = state {
                state = .interrupted
            }
        }
    }

    @ViewBuilder private var gameBoard: some View {
        switch game {
        case .reaction: QuickDrawRound(finish: finish)
        case .memory: MemoryGridRound(finish: finish)
        case .colors: ColorSwitchRound(finish: finish)
        case .stack: StackRushRound(finish: finish)
        case .lights: BlackoutRound(finish: finish)
        case .sliding: SlidingNineRound(finish: finish)
        case .merge: MergeTilesRound(finish: finish)
        case .mines: MineRoomRound(finish: finish)
        case .pairs: PairHouseRound(finish: finish)
        case .snake: SnakeRunRound(finish: finish)
        case .numbers: NumberRushRound(finish: finish)
        case .breaker: BrickBreakerRound(finish: finish)
        }
    }

    private func readyCard(interrupted: Bool) -> some View {
        VStack(spacing: 18) {
            Image(systemName: game.symbol)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 112, height: 112)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 28))
                .accessibilityHidden(true)
            Text(interrupted ? "Round interrupted" : game.genre.rawValue)
                .font(.system(.title2, design: .serif).weight(.semibold))
            Text(interrupted ? "Start a fresh round when you're ready." : game.instructions)
                .foregroundStyle(ArcadePalette.muted)
                .multilineTextAlignment(.center)
            if let best = records[game] {
                Text(game.recordLabel + " · " + game.format(best))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(tint)
            }
            ArcadeAction(title: "Start round", tint: tint) { state = .playing }
                .accessibilityIdentifier("arcade.start")
        }
        .padding(22)
        .arcadePanel()
    }

    private func resultCard(_ result: ArcadeResult, newBest: Bool) -> some View {
        VStack(spacing: 16) {
            Text(newBest ? "Personal best" : "Round over")
                .font(.system(.title2, design: .serif).weight(.semibold))
            if result.score > 0 || result.message == nil {
                Text(game.format(result.score))
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityIdentifier("arcade.result")
            }
            if let message = result.message {
                Text(message).foregroundStyle(ArcadePalette.muted).multilineTextAlignment(.center)
            }
            if let best = records[game], !newBest {
                Text(game.recordLabel + " · " + game.format(best)).font(.subheadline).foregroundStyle(ArcadePalette.muted)
            }
            ArcadeAction(title: "Play again", tint: tint) { state = .playing }
            Button("Back to games") { dismiss() }
                .buttonStyle(.borderless)
                .tint(ArcadePalette.cream)
                .padding(.top, 4)
        }
        .padding(22)
        .arcadePanel()
    }

    private func finish(_ result: ArcadeResult) {
        guard case .playing = state else { return }
        state = .finished(result, newBest: records.record(result.score, for: game))
    }
}

struct ArcadeAction: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(ArcadePalette.backdrop)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func arcadePanel() -> some View {
        frame(maxWidth: .infinity)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 19))
            .overlay { RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.12)).allowsHitTesting(false) }
    }
}

func elapsedSeconds(since start: ContinuousClock.Instant, at end: ContinuousClock.Instant = .now) -> Double {
    let interval = start.duration(to: end).components
    return Double(interval.seconds) + Double(interval.attoseconds) / 1e18
}
