import Foundation

/// M7: ステージごとの出題選択ロジック（doc §M7「出題のランダム化」）。
/// UIやUserDefaultsに依存しない純粋関数にすることで、ユニットテストで
/// 「連続プレイしても再出題されない」ことを検証できるようにする。
enum PuzzleSelection {
    /// 1ステージあたりの出題数。
    static let puzzlesPerSession = 5

    /// recentlyPlayed の保持数上限（そのステージの在庫の50%、上限200件）。
    static func recentlyPlayedCap(poolSize: Int) -> Int {
        min(200, poolSize / 2)
    }

    /// pool から count 問を、recentlyPlayed に含まれる id を除外して重複なくランダムに選ぶ。
    /// 候補が不足する場合（在庫を一巡した場合）は除外を段階的に緩める。`recentlyPlayed` は
    /// 古い順（先頭が最も古い、末尾が直近出題）なので、末尾（直近）を優先して除外し続け、
    /// count問確保できるようになるまで古い方から除外を外していく。これにより、在庫が少ない
    /// ステージでも「直前にプレイした問題がステージ再挑戦の1問目にまた出る」ような、
    /// 全く同じ問題が連続する事態を避ける（除外を全部諦めて即座に全問から選び直すと、
    /// 直前の5問がそのまま次のセッションの1問目に出うる）。
    static func selectPuzzles(
        from pool: [Puzzle],
        excluding recentlyPlayed: [Int],
        count: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [Puzzle] {
        var excludeCount = recentlyPlayed.count
        while excludeCount > 0 {
            let excludedIDs = Set(recentlyPlayed.suffix(excludeCount))
            let candidates = pool.filter { !excludedIDs.contains($0.id) }
            if candidates.count >= count {
                return Array(candidates.shuffled(using: &generator).prefix(count))
            }
            excludeCount -= 1
        }
        return Array(pool.shuffled(using: &generator).prefix(count))
    }

    /// 新たに出題した id を recentlyPlayed に追記する（FIFO。上限を超えた分は古い方から捨てる）。
    static func updatedRecentlyPlayed(current: [Int], newlyPlayed: [Int], poolSize: Int) -> [Int] {
        var updated = current + newlyPlayed
        let cap = recentlyPlayedCap(poolSize: poolSize)
        if updated.count > cap {
            updated.removeFirst(updated.count - cap)
        }
        return updated
    }
}
