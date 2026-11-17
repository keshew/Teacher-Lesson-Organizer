import SwiftUI
import UIKit

enum ArcadePalette {
    static let backdrop = Color(red: 0.080, green: 0.047, blue: 0.069)
    static let velvet = Color(red: 0.235, green: 0.074, blue: 0.13)
    static let brass = Color(red: 0.96, green: 0.76, blue: 0.47)
    static let cream = Color(red: 1, green: 0.95, blue: 0.88)
    static let muted = Color(red: 0.77, green: 0.69, blue: 0.73)
    static let panel = Color(red: 0.14, green: 0.095, blue: 0.128)

    static func tint(for game: ArcadeGame) -> Color {
        switch game {
        case .reaction, .pairs, .numbers: brass
        case .memory, .snake, .lights: Color(red: 0.51, green: 0.84, blue: 0.69)
        case .colors, .mines, .breaker: Color(red: 1, green: 0.50, blue: 0.53)
        case .stack, .sliding, .merge: Color(red: 0.74, green: 0.65, blue: 1)
        }
    }
}

struct ArcadeLobby: View {
    let openOrganizer: () -> Void
    @Binding var selected: ArcadeGame?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var tab = Tab.arcade
    @State private var scores: [ArcadeGame: Int] = [:]
    @State private var rounds: [ArcadeGame: Int] = [:]
    @State private var recent: ArcadeGame?
    @State private var search = ""
    @State private var genre: ArcadeGenre?
    private let records = ArcadeRecords()

    private enum Tab: String, CaseIterable {
        case arcade = "Arcade"
        case games = "Games"
        case records = "Records"

        var symbol: String {
            switch self {
            case .arcade: "gamecontroller.fill"
            case .games: "square.grid.2x2.fill"
            case .records: "trophy.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                switch tab {
                case .arcade: arcade
                case .games: catalog
                case .records: scoreboard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .id(tab)
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .background {
            RadialGradient(colors: [ArcadePalette.velvet.opacity(0.70), ArcadePalette.backdrop],
                           center: .topTrailing, startRadius: 12, endRadius: 420)
                .ignoresSafeArea()
        }
        .foregroundStyle(ArcadePalette.cream)
        .preferredColorScheme(.dark)
        .onAppear(perform: readRecords)
        .fullScreenCover(item: $selected, onDismiss: readRecords) { game in
            ArcadeRound(game: game, records: records)
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "diamond.fill")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(ArcadePalette.brass)
                .frame(width: 37, height: 37)
                .background(ArcadePalette.brass.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            Text(tab == .arcade ? "Vegas Rush" : tab.rawValue)
                .font(.system(.title, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: openOrganizer) {
                Image(systemName: "books.vertical")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.11)) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open lesson organizer")
        }
    }

    @ViewBuilder private var arcade: some View {
        featuredCard(featuredGame)
        if let recent {
            Button {
                selected = recent
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: recent.symbol)
                        .font(.headline)
                        .foregroundStyle(ArcadePalette.tint(for: recent))
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Play again").font(.caption).foregroundStyle(ArcadePalette.muted)
                        Text(recent.title).font(.headline)
                    }
                    Spacer()
                    Image(systemName: "arrow.clockwise").foregroundStyle(ArcadePalette.brass)
                }
                .padding(12)
                .background(ArcadePalette.panel, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Pick a game")
                Spacer()
                Button {
                    genre = nil
                    search = ""
                    tab = .games
                } label: {
                    Label("All games", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ArcadePalette.brass)
                }
                .buttonStyle(.plain)
            }
            gameGrid(ArcadeGame.allCases.filter { $0 != featuredGame }.prefix(4).map { $0 })
        }
    }

    @ViewBuilder private var catalog: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ArcadePalette.muted)
                TextField("Search games", text: $search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("arcade.search")
                if !search.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                }
            }
            .padding(13)
            .background(ArcadePalette.panel, in: RoundedRectangle(cornerRadius: 13))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    filter("All", value: nil)
                    ForEach(ArcadeGenre.allCases) { filter($0.rawValue, value: $0) }
                }
            }
            .scrollIndicators(.hidden)
        }

        if filteredGames.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("No games found")
                Text("Try a different title or category.").foregroundStyle(ArcadePalette.muted)
            }
            .padding(.vertical, 12)
        } else {
            Text("\(filteredGames.count) \(filteredGames.count == 1 ? "game" : "games")")
                .font(.subheadline)
                .foregroundStyle(ArcadePalette.muted)
            gameGrid(filteredGames)
        }
    }

    @ViewBuilder private var scoreboard: some View {
        HStack(spacing: 10) {
            stat(value: rounds.values.reduce(0, +), label: "Rounds played", icon: "play.circle.fill")
            stat(value: scores.count, label: "Games with records", icon: "trophy.fill")
        }
        if scores.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Your first record")
                Text("Finish a round to start your record book.")
                    .foregroundStyle(ArcadePalette.muted)
                Button("Find a game") { tab = .games }
                    .buttonStyle(.borderless)
                    .tint(ArcadePalette.brass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .arcadePanel()
        }
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Personal bests")
            VStack(spacing: 0) {
                ForEach(ArcadeGame.allCases) { game in
                    if game != ArcadeGame.allCases.first {
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 57)
                    }
                    Button {
                        selected = game
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: game.symbol)
                                .foregroundStyle(ArcadePalette.tint(for: game))
                                .frame(width: 35, height: 35)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(game.title).font(.subheadline.weight(.semibold))
                                Text(game.recordLabel).font(.caption).foregroundStyle(ArcadePalette.muted)
                            }
                            Spacer()
                            Text(scores[game].map(game.format) ?? "—")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(scores[game] != nil ? ArcadePalette.brass : ArcadePalette.muted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(ArcadePalette.panel, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var featuredGame: ArcadeGame {
        let games: [ArcadeGame] = [.breaker, .snake, .merge, .reaction, .numbers, .stack, .pairs]
        let index = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return games[(index - 1) % games.count]
    }

    private var filteredGames: [ArcadeGame] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return ArcadeGame.allCases.filter { game in
            (genre == nil || genre == game.genre) && (term.isEmpty || game.title.localizedCaseInsensitiveContains(term))
        }
    }

    private func featuredCard(_ game: ArcadeGame) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GAME OF THE DAY")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(2)
                .foregroundStyle(ArcadePalette.brass)
            Text(game.title)
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(game.genre.rawValue)
                .font(.subheadline)
                .foregroundStyle(ArcadePalette.muted)
            Button {
                selected = game
            } label: {
                Label("Play now", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 15)
                    .frame(minHeight: 44)
                    .background(ArcadePalette.brass, in: Capsule())
                    .foregroundStyle(ArcadePalette.backdrop)
            }
            .buttonStyle(.plain)
            .padding(.top, 5)
            .accessibilityIdentifier("arcade.featured")
        }
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .bottomLeading)
        .padding(18)
        .background {
            GeometryReader { geometry in
                ZStack {
                    Rectangle().fill(ArcadePalette.velvet)
                    if let art = UIImage(named: "Arcade Cabinet") {
                        Image(uiImage: art)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                    } else {
                        ArcadeTileArt(game: game, large: true)
                    }
                    LinearGradient(stops: [
                        .init(color: ArcadePalette.backdrop.opacity(0.95), location: 0),
                        .init(color: ArcadePalette.backdrop.opacity(0.64), location: 0.48),
                        .init(color: ArcadePalette.backdrop.opacity(0.04), location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                }
                .clipped()
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .overlay { RoundedRectangle(cornerRadius: 21).strokeBorder(ArcadePalette.brass.opacity(0.32)).allowsHitTesting(false) }
    }

    private func gameGrid(_ games: [ArcadeGame]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 278 : 140), spacing: 11)], spacing: 12) {
            ForEach(games) { game in
                Button {
                    selected = game
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        ArcadeTileArt(game: game)
                            .frame(height: 76)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.title).font(.system(.headline, design: .serif).weight(.semibold))
                            Text(scores[game].map { "Best: " + game.format($0) } ?? game.genre.rawValue)
                                .font(.caption)
                                .foregroundStyle(ArcadePalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .background(ArcadePalette.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.10)) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("arcade.\(game.id)")
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.headline)
                        Text(item.rawValue).font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 47)
                    .foregroundStyle(tab == item ? ArcadePalette.brass : ArcadePalette.muted)
                    .background {
                        if tab == item {
                            RoundedRectangle(cornerRadius: 10).fill(ArcadePalette.brass.opacity(0.11))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
                .accessibilityIdentifier("arcade.tab.\(item.rawValue)")
            }
        }
        .padding(6)
        .background(ArcadePalette.panel, in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.12)) }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background { ArcadePalette.backdrop.ignoresSafeArea(edges: .bottom) }
    }

    private func filter(_ label: String, value: ArcadeGenre?) -> some View {
        Button {
            genre = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(minHeight: 37)
                .foregroundStyle(genre == value ? ArcadePalette.backdrop : ArcadePalette.cream)
                .background(genre == value ? ArcadePalette.brass : ArcadePalette.panel, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(genre == value ? [.isSelected] : [])
    }

    private func stat(value: Int, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).foregroundStyle(ArcadePalette.brass)
            Text(value.formatted()).font(.system(.title, design: .monospaced).weight(.semibold))
            Text(label).font(.caption).foregroundStyle(ArcadePalette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .background(ArcadePalette.panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.title2, design: .serif).weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }

    private func readRecords() {
        scores = Dictionary(uniqueKeysWithValues: ArcadeGame.allCases.compactMap { game in
            records[game].map { (game, $0) }
        })
        rounds = Dictionary(uniqueKeysWithValues: ArcadeGame.allCases.map { ($0, records.rounds(for: $0)) })
        recent = records.recentGame
    }
}

private struct ArcadeTileArt: View {
    let game: ArcadeGame
    var large = false

    var body: some View {
        let tint = ArcadePalette.tint(for: game)
        ZStack(alignment: .trailing) {
            LinearGradient(colors: [ArcadePalette.backdrop, tint.opacity(0.25)], startPoint: .bottomLeading, endPoint: .topTrailing)
            Canvas { context, size in
                let step = 11.0
                var path = Path()
                for x in stride(from: 4.0, to: size.width, by: step) {
                    for y in stride(from: 4.0, to: size.height, by: step) {
                        let radius = x > size.width / 2 ? 1.0 : 0.6
                        path.addEllipse(in: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
                    }
                }
                context.fill(path, with: .color(tint.opacity(0.23)))
            }
            Circle()
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                .frame(width: large ? 164 : 80)
                .offset(x: 10)
            Image(systemName: game.symbol)
                .font(.system(size: large ? 96 : 37, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: tint.opacity(0.38), radius: 13, y: 4)
                .rotationEffect(.degrees(game.genre == .puzzle ? -8 : 6))
                .padding(.trailing, large ? 19 : 15)
        }
        .clipped()
    }
}
