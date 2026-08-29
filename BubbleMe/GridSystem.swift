import Foundation
import CoreGraphics

enum BubbleColor: String, CaseIterable, Codable {
    case red, amber, lime, azure, violet, aqua
}

struct GridBubble: Identifiable, Codable {
    var id: Int
    var col: Int
    var row: Int
    var color: BubbleColor
    var face: Bool
}

enum HexGrid {
    static let cols = 8
    static let radius: CGFloat = 19
    static var diameter: CGFloat { radius * 2 }
    static var rowH: CGFloat { diameter * 0.866 }

    static func colCount(_ row: Int) -> Int { row % 2 == 0 ? cols : cols - 1 }

    static func neighbors(col: Int, row: Int) -> [(Int, Int)] {
        if row % 2 == 0 {
            return [(col - 1, row), (col + 1, row), (col - 1, row - 1), (col, row - 1), (col - 1, row + 1), (col, row + 1)]
        }
        return [(col - 1, row), (col + 1, row), (col, row - 1), (col + 1, row - 1), (col, row + 1), (col + 1, row + 1)]
    }
}

final class Board {
    private(set) var cells: [[GridBubble?]]
    var nextId = 1
    let maxRows = 18

    init() {
        cells = (0..<maxRows).map { row in Array(repeating: nil, count: HexGrid.colCount(row)) }
    }

    func inBounds(col: Int, row: Int) -> Bool {
        row >= 0 && row < maxRows && col >= 0 && col < HexGrid.colCount(row)
    }

    func get(col: Int, row: Int) -> GridBubble? {
        guard inBounds(col: col, row: row) else { return nil }
        return cells[row][col]
    }

    @discardableResult
    func spawn(col: Int, row: Int, color: BubbleColor, face: Bool = false) -> GridBubble? {
        guard inBounds(col: col, row: row), cells[row][col] == nil else { return nil }
        let b = GridBubble(id: nextId, col: col, row: row, color: color, face: face)
        nextId += 1
        cells[row][col] = b
        return b
    }

    func remove(col: Int, row: Int) -> GridBubble? {
        guard inBounds(col: col, row: row) else { return nil }
        let b = cells[row][col]
        cells[row][col] = nil
        return b
    }

    func all() -> [GridBubble] {
        cells.flatMap { $0.compactMap { $0 } }
    }

    func clear() {
        for r in 0..<maxRows {
            for c in 0..<cells[r].count { cells[r][c] = nil }
        }
    }

    /// Shift every bubble down one hex row, the way the web game does. Returns bubbles that fell off the bottom.
    @discardableResult
    func shiftDown() -> [GridBubble] {
        var overflow: [GridBubble] = []
        for r in stride(from: maxRows - 1, through: 0, by: -1) {
            for c in 0..<HexGrid.colCount(r) {
                guard var b = cells[r][c] else { continue }
                cells[r][c] = nil
                let nr = r + 1
                if nr >= maxRows {
                    overflow.append(b)
                    continue
                }
                let nc = min(b.col, HexGrid.colCount(nr) - 1)
                b.row = nr
                b.col = nc
                cells[nr][nc] = b
            }
        }
        return overflow
    }

    func cluster(fromCol col: Int, row: Int) -> [GridBubble] {
        guard let start = get(col: col, row: row) else { return [] }
        var seen = Set<Int>()
        var out: [GridBubble] = []
        var stack = [(col, row)]
        while let (c, r) = stack.popLast() {
            guard let b = get(col: c, row: r), b.color == start.color, !seen.contains(b.id) else { continue }
            seen.insert(b.id)
            out.append(b)
            stack.append(contentsOf: HexGrid.neighbors(col: c, row: r))
        }
        return out
    }

    func floating() -> [GridBubble] {
        var connected = Set<Int>()
        var q: [(Int, Int)] = []
        for c in 0..<HexGrid.colCount(0) where get(col: c, row: 0) != nil { q.append((c, 0)) }
        var i = 0
        while i < q.count {
            let (c, r) = q[i]; i += 1
            guard let b = get(col: c, row: r), !connected.contains(b.id) else { continue }
            connected.insert(b.id)
            q.append(contentsOf: HexGrid.neighbors(col: c, row: r))
        }
        return all().filter { !connected.contains($0.id) }
    }
}
