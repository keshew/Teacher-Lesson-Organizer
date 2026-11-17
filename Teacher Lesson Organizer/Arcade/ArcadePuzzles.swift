import Foundation

enum GridDirection: CaseIterable {
    case up, down, left, right

    var step: (row: Int, column: Int) {
        switch self {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
    }

    var opposite: Self {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }
}

struct SquareGrid {
    let size: Int

    var count: Int { size * size }

    func neighbor(of index: Int, row: Int, column: Int) -> Int? {
        let r = index / size + row
        let c = index % size + column
        guard (0..<size).contains(r), (0..<size).contains(c) else { return nil }
        return r * size + c
    }

    func adjacent(to index: Int, diagonals: Bool = false) -> [Int] {
        if diagonals {
            return (-1...1).flatMap { row in
                (-1...1).compactMap { column in
                    row == 0 && column == 0 ? nil : neighbor(of: index, row: row, column: column)
                }
            }
        }
        return GridDirection.allCases.compactMap {
            neighbor(of: index, row: $0.step.row, column: $0.step.column)
        }
    }
}

struct BlackoutBoard {
    static let grid = SquareGrid(size: 4)
    private(set) var lit: Set<Int> = []
    private(set) var moves = 0

    init(shuffle: Bool = true) {
        if shuffle {
            repeat {
                for index in (0..<Self.grid.count).shuffled().prefix(6) { toggle(index) }
            } while lit.isEmpty
        }
        moves = 0
    }

    mutating func toggle(_ index: Int) {
        lit.formSymmetricDifference([index] + Self.grid.adjacent(to: index))
        moves += 1
    }
}

struct SlidingBoard {
    static let grid = SquareGrid(size: 3)
    static let goal = Array(1...8) + [0]
    private(set) var tiles = goal
    private(set) var moves = 0

    init(shuffle: Bool = true) {
        if shuffle {
            repeat {
                var previous = -1
                for _ in 0..<28 {
                    let empty = tiles.firstIndex(of: 0)!
                    let candidates = Self.grid.adjacent(to: empty).filter { $0 != previous }
                    if let index = candidates.randomElement() {
                        _ = slide(index)
                        previous = empty
                    }
                }
            } while tiles == Self.goal
        }
        moves = 0
    }

    mutating func slide(_ index: Int) -> Bool {
        guard let empty = tiles.firstIndex(of: 0), Self.grid.adjacent(to: empty).contains(index) else { return false }
        tiles.swapAt(empty, index)
        moves += 1
        return true
    }
}

struct MergeBoard {
    private(set) var tiles: [Int]
    private(set) var points = 0

    init(tiles: [Int]? = nil) {
        self.tiles = tiles ?? Array(repeating: 0, count: 16)
        if tiles == nil { spawn(); spawn() }
    }

    var canMove: Bool {
        tiles.contains(0) || tiles.indices.contains { index in
            SquareGrid(size: 4).adjacent(to: index).contains { tiles[$0] == tiles[index] }
        }
    }

    mutating func move(_ direction: GridDirection) -> Bool {
        let original = tiles
        var gained = 0
        for line in 0..<4 {
            let indices = (0..<4).map { step in
                switch direction {
                case .left: line * 4 + step
                case .right: line * 4 + (3 - step)
                case .up: step * 4 + line
                case .down: (3 - step) * 4 + line
                }
            }
            let occupied = indices.map { tiles[$0] }.filter { $0 != 0 }
            var merged: [Int] = []
            var cursor = 0
            while cursor < occupied.count {
                if cursor + 1 < occupied.count, occupied[cursor] == occupied[cursor + 1] {
                    let value = occupied[cursor] * 2
                    merged.append(value)
                    gained += value
                    cursor += 2
                } else {
                    merged.append(occupied[cursor])
                    cursor += 1
                }
            }
            for (step, index) in indices.enumerated() {
                tiles[index] = step < merged.count ? merged[step] : 0
            }
        }
        guard original != tiles else { return false }
        points += gained
        spawn()
        return true
    }

    private mutating func spawn() {
        if let index = tiles.indices.filter({ tiles[$0] == 0 }).randomElement() {
            tiles[index] = Int.random(in: 0..<10) == 0 ? 4 : 2
        }
    }
}

struct MineBoard {
    static let grid = SquareGrid(size: 5)
    static let mineCount = 5
    private(set) var mines: Set<Int> = []
    private(set) var revealed: Set<Int> = []
    private(set) var flags: Set<Int> = []

    var cleared: Bool { revealed.count == Self.grid.count - Self.mineCount }

    func countAround(_ index: Int) -> Int {
        Self.grid.adjacent(to: index, diagonals: true).filter(mines.contains).count
    }

    mutating func flag(_ index: Int) {
        if !revealed.contains(index) { flags.formSymmetricDifference([index]) }
    }

    // Returns false only when a mine is opened.
    mutating func reveal(_ index: Int) -> Bool {
        guard !flags.contains(index), !revealed.contains(index) else { return true }
        if mines.isEmpty {
            let safe = Set([index] + Self.grid.adjacent(to: index, diagonals: true))
            mines = Set((0..<Self.grid.count).filter { !safe.contains($0) }.shuffled().prefix(Self.mineCount))
        }
        guard !mines.contains(index) else { return false }
        var pending = [index]
        while let cell = pending.popLast() {
            guard !mines.contains(cell), !flags.contains(cell), revealed.insert(cell).inserted else { continue }
            if countAround(cell) == 0 {
                pending += Self.grid.adjacent(to: cell, diagonals: true)
            }
        }
        return true
    }
}
