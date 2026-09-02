import Foundation
import Observation

/// 現在プレイ中の1問の盤面状態（返り点・ハイフンの配置）。
/// BoardScene（タッチ入力）と SwiftUI 側（残数表示など）で共有する。
@Observable
final class GameState {
    let puzzle: Puzzle
    private(set) var marks: [Mark]
    private(set) var hyphens: [Bool]

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.marks = [Mark](repeating: .none, count: puzzle.tokenCount)
        self.hyphens = [Bool](repeating: false, count: max(0, puzzle.tokenCount - 1))
    }

    /// mark をこの問題であと何個置けるか（`index` に既に置かれている分は除いて数える）。
    func remainingCount(for mark: Mark, excludingTokenAt index: Int? = nil) -> Int {
        guard mark != .none else { return .max }
        let need = puzzle.answerMarks.filter { $0 == mark }.count
        var used = 0
        for (i, m) in marks.enumerated() where m == mark {
            if i == index { continue }
            used += 1
        }
        return max(0, need - used)
    }

    func remainingHyphenCount(excludingGapAt gapIndex: Int? = nil) -> Int {
        let need = puzzle.answerHyphens.filter { $0 }.count
        var used = 0
        for (i, h) in hyphens.enumerated() where h {
            if i == gapIndex { continue }
            used += 1
        }
        return max(0, need - used)
    }

    /// token の位置 index に mark を置けるか（在庫が尽きていないか）。
    func canPlace(_ mark: Mark, at index: Int) -> Bool {
        guard index >= 0, index < marks.count else { return false }
        if mark == .none { return true }
        if marks[index] == mark { return true }
        return remainingCount(for: mark, excludingTokenAt: index) > 0
    }

    @discardableResult
    func setMark(_ mark: Mark, at index: Int) -> Bool {
        guard canPlace(mark, at: index) else { return false }
        marks[index] = mark
        return true
    }

    /// gapIndex は「トークン gapIndex とトークン gapIndex+1 の間」を指す（0始まり）。
    func canToggleHyphen(at gapIndex: Int) -> Bool {
        guard gapIndex >= 0, gapIndex < hyphens.count else { return false }
        if hyphens[gapIndex] { return true } // OFFにするのは常に可能
        return remainingHyphenCount(excludingGapAt: gapIndex) > 0
    }

    @discardableResult
    func toggleHyphen(at gapIndex: Int) -> Bool {
        guard canToggleHyphen(at: gapIndex) else { return false }
        hyphens[gapIndex].toggle()
        return true
    }

    func reset() {
        marks = [Mark](repeating: .none, count: puzzle.tokenCount)
        hyphens = [Bool](repeating: false, count: max(0, puzzle.tokenCount - 1))
    }
}
