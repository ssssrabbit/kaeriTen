import XCTest
@testable import KaeriTen

final class PuzzleSelectionTests: XCTestCase {

    /// doc §M7 受け入れ条件: 「同じステージを10回連続でプレイしても同じ問題が再出題されない」。
    /// Stage2-3（202問。doc本文が「最小のステージ」として挙げている実例）で検証する。
    /// recentlyPlayedCap は在庫の50%（このステージでは101件）なので、10回×5問=50件の
    /// 出題は cap 内に収まり、重複が起きないことが保証される。
    func testStageRandomizationNoRepeatsOverTenDraws() throws {
        let store = try PuzzleStore(bundle: .main)
        let all = try store.loadAllPuzzles()
        let stage = try XCTUnwrap(StageCatalog.stages.first(where: { $0.id == "2-3" }))
        let pool = all.filter { stage.matches($0) }
        XCTAssertGreaterThanOrEqual(pool.count, 200, "Stage2-3の在庫が想定より少ない")

        var recentlyPlayed: [Int] = []
        var allPicked: [Int] = []
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<10 {
            let picked = PuzzleSelection.selectPuzzles(
                from: pool,
                excluding: recentlyPlayed,
                count: PuzzleSelection.puzzlesPerSession,
                using: &rng
            )
            XCTAssertEqual(picked.count, PuzzleSelection.puzzlesPerSession)
            allPicked.append(contentsOf: picked.map(\.id))
            recentlyPlayed = PuzzleSelection.updatedRecentlyPlayed(
                current: recentlyPlayed,
                newlyPlayed: picked.map(\.id),
                poolSize: pool.count
            )
        }
        XCTAssertEqual(Set(allPicked).count, allPicked.count, "10回のステージプレイで同じ問題が再出題された")
    }

    /// updatedRecentlyPlayed が FIFO（古い順に捨てる）で上限を守ることを検証する。
    func testUpdatedRecentlyPlayedFIFOEviction() {
        let poolSize = 20 // cap = min(200, 10) = 10
        var current: [Int] = []

        current = PuzzleSelection.updatedRecentlyPlayed(current: current, newlyPlayed: [1, 2, 3, 4, 5], poolSize: poolSize)
        XCTAssertEqual(current, [1, 2, 3, 4, 5])

        current = PuzzleSelection.updatedRecentlyPlayed(current: current, newlyPlayed: [6, 7, 8, 9, 10], poolSize: poolSize)
        XCTAssertEqual(current, Array(1...10))

        current = PuzzleSelection.updatedRecentlyPlayed(current: current, newlyPlayed: [11, 12], poolSize: poolSize)
        XCTAssertEqual(current, Array(3...12), "上限超過分は古い方（1, 2）から捨てられるべき")
    }

    /// 候補が recentlyPlayed の除外により count 未満になった場合（在庫を一巡した場合）は、
    /// recentlyPlayed を無視して全問から選び直すことを検証する。
    func testSelectPuzzlesFallsBackWhenCandidatesExhausted() throws {
        let store = try PuzzleStore(bundle: .main)
        let all = try store.loadAllPuzzles()
        let stage = try XCTUnwrap(StageCatalog.stages.first(where: { $0.id == "2-3" }))
        let pool = all.filter { stage.matches($0) }

        // pool のほぼ全IDを recentlyPlayed に入れて候補を枯渇させる。
        let almostAllIDs = Array(pool.dropLast(2).map(\.id))
        var rng = SystemRandomNumberGenerator()
        let picked = PuzzleSelection.selectPuzzles(
            from: pool,
            excluding: almostAllIDs,
            count: PuzzleSelection.puzzlesPerSession,
            using: &rng
        )
        XCTAssertEqual(picked.count, PuzzleSelection.puzzlesPerSession, "候補不足時は全問から選び直して必ずcount件返すべき")
    }

    /// ユーザー報告: 在庫が少ないステージで「全く同じ並びの問題が連続する」ことがあった。
    /// 原因は、候補不足時に recentlyPlayed の除外を全部諦めて全問から選び直していたため、
    /// 直前のセッションの問題がそのまま次のセッションの1問目に出うる実装になっていたこと。
    /// 除外を段階的に緩める（直近優先で除外し続ける）ことで、少なくとも直前にプレイした
    /// 問題は次のセッションの出題から除外され続けることを検証する。
    func testSelectPuzzlesAvoidsImmediateRepeatWhenPoolIsSmall() throws {
        let store = try PuzzleStore(bundle: .main)
        let all = try store.loadAllPuzzles()
        let stage = try XCTUnwrap(StageCatalog.stages.first(where: { $0.id == "2-3" }))
        let fullPool = all.filter { stage.matches($0) }
        // 在庫を強制的に小さくして（7問）候補不足を頻発させる。
        let smallPool = Array(fullPool.prefix(7))
        XCTAssertGreaterThan(smallPool.count, PuzzleSelection.puzzlesPerSession)

        var recentlyPlayed: [Int] = []
        var rng = SystemRandomNumberGenerator()
        var previousLastPlayedID: Int?
        for _ in 0..<20 {
            let picked = PuzzleSelection.selectPuzzles(
                from: smallPool,
                excluding: recentlyPlayed,
                count: PuzzleSelection.puzzlesPerSession,
                using: &rng
            )
            XCTAssertEqual(picked.count, PuzzleSelection.puzzlesPerSession)
            if let previousLastPlayedID {
                XCTAssertFalse(
                    picked.map(\.id).contains(previousLastPlayedID),
                    "直前のセッション最後にプレイした問題が、次のセッションで即座に再出題された"
                )
            }
            previousLastPlayedID = picked.last?.id
            recentlyPlayed = PuzzleSelection.updatedRecentlyPlayed(
                current: recentlyPlayed,
                newlyPlayed: picked.map(\.id),
                poolSize: smallPool.count
            )
        }
    }
}
