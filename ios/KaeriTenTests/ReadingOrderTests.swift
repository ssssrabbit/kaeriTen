import XCTest
@testable import KaeriTen

final class ReadingOrderTests: XCTestCase {

    private func loadPuzzles() throws -> [Puzzle] {
        // KaeriTenTests は KaeriTen.app にホストされて実行されるため、
        // Bundle.main はアプリ本体のバンドル（game.sqlite 同梱）を指す。
        let store = try PuzzleStore(bundle: .main)
        return try store.loadAllPuzzles()
    }

    /// game.sqlite の全問題について、answerMarks/answerHyphens から
    /// tokenReadingOrder を計算した結果が answerOrder と完全一致することを検証する。
    /// tools/build_game_db.py が書き出し時に行った自己検証と同じ内容を
    /// Swift 側の実装でも再現する（doc §M2 の受け入れ条件）。
    func testAllPuzzlesReproduceAnswerOrder() throws {
        let puzzles = try loadPuzzles()
        // PuzzleStore.loadAllPuzzles() は返り点が1つも必要ない問題（marksが全て.none、
        // 全5213問中366問）を出題対象から除外している（ユーザーフィードバック。
        // 何も操作しなくてもクリアになってしまいゲームとして成立しないため）。
        XCTAssertGreaterThan(puzzles.count, 4500, "game.sqlite から十分な数の問題が読み込めていない")

        var mismatches: [Int] = []
        for puzzle in puzzles {
            let computed = tokenReadingOrder(marks: puzzle.answerMarks, hyphens: puzzle.answerHyphens)
            if computed != puzzle.answerOrder {
                mismatches.append(puzzle.id)
            }
        }
        XCTAssertTrue(
            mismatches.isEmpty,
            "\(mismatches.count)件で読み順が一致しなかった: \(mismatches.prefix(20))"
        )
    }

    // MARK: - 手計算ケース（tools/build_game_db.py が生成した game.sqlite の実値。自己検証済み）

    private func marks(_ s: String) -> [Mark] {
        s.compactMap { Mark(rawValue: $0) }
    }

    private func hyphens(_ s: String) -> [Bool] {
        s.map { $0 == "1" }
    }

    private func order(_ s: String) -> [Int] {
        s.compactMap { Int(String($0)) }.map { $0 - 1 }
    }

    func testID1_ReTen() {
        // 猶走賎 marks=".r." hyphens="00" → 1,3,2
        let result = tokenReadingOrder(marks: marks(".r."), hyphens: hyphens("00"))
        XCTAssertEqual(result, order("132"))
    }

    func testID3_ReTenPlusIchiNi() {
        // 勿食異例 marks="r2.1" hyphens="000" → 3,4,2,1
        let result = tokenReadingOrder(marks: marks("r2.1"), hyphens: hyphens("000"))
        XCTAssertEqual(result, order("3421"))
    }

    func testID524_ReTenChain() {
        // 蛭無聞山間 marks=".r2.1" hyphens="0000" → 1,4,5,3,2
        let result = tokenReadingOrder(marks: marks(".r2.1"), hyphens: hyphens("0000"))
        XCTAssertEqual(result, order("14532"))
    }

    func testID331_IchiNiPlusReTen() {
        // 暈飲山間而買 marks=".2.1r." hyphens="00000" → 1,3,4,2,6,5
        let result = tokenReadingOrder(marks: marks(".2.1r."), hyphens: hyphens("00000"))
        XCTAssertEqual(result, order("134265"))
    }

    func testID10_IchiNiSanYonFullLevel() {
        // 極飲於国籍 marks="342.1" hyphens="0000" → 4,5,3,1,2
        // 一二三四点をフル活用する例。ハイフンなしで足りる（救済の要）。
        let result = tokenReadingOrder(marks: marks("342.1"), hyphens: hyphens("0000"))
        XCTAssertEqual(result, order("45312"))
    }

    func testID963_NiSanPlusIchi() {
        // 魚介寝座書房 marks="..23.1" hyphens="00000" → 1,2,5,6,3,4
        let result = tokenReadingOrder(marks: marks("..23.1"), hyphens: hyphens("00000"))
        XCTAssertEqual(result, order("125634"))
    }

    func testID180_HyphenBlock() {
        // 書用品於廟 marks="r.231" hyphens="0100" → 5,2,3,1,4
        // 用‐品 を1ブロックとして扱う。ハイフンを無視する実装ではここで落ちる。
        let result = tokenReadingOrder(marks: marks("r.231"), hyphens: hyphens("0100"))
        XCTAssertEqual(result, order("52314"))
    }

    func testID1136_HyphenBlockWithReTen() {
        // 略買竿自螢 marks=".r231" hyphens="1000" → 5,3,1,2,4
        // 略‐買 を1ブロックとして扱う。レ点とも併用。
        let result = tokenReadingOrder(marks: marks(".r231"), hyphens: hyphens("1000"))
        XCTAssertEqual(result, order("53124"))
    }

    /// ブロックの返り点は末尾トークンに置く、という規約そのものを検証する。
    /// id=180 の「用‐品」ブロックでは、mark '2' はブロック先頭の「用」ではなく
    /// 末尾の「品」（トークン単位 marks 文字列の3文字目）に付いている。
    func testBlockMarkIsPlacedOnLastToken() {
        let tokenMarks = marks("r.231") // 書用品於廟
        XCTAssertEqual(tokenMarks[0], .re)   // 書
        XCTAssertEqual(tokenMarks[1], .none) // 用（ブロック先頭。無印）
        XCTAssertEqual(tokenMarks[2], .ni)   // 品（ブロック末尾。ここに '2' が付く）
        XCTAssertEqual(tokenMarks[3], .san)  // 於
        XCTAssertEqual(tokenMarks[4], .ichi) // 廟
    }

    // MARK: - 不完全な配置でもクラッシュしないこと（§M4）

    func testIncompleteMarksNeverCrashes() {
        // '一' はあるが対応する '二' がない、レ点も未配置 —
        // プレイ中に頻繁に起こる不完全な状態を模す。
        let incomplete = marks("..1..")
        let result = tokenReadingOrder(marks: incomplete, hyphens: [false, false, false, false])
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(Set(result), Set(0..<5), "常に完全な順列を返すこと")
    }

    func testEmptyPuzzleDoesNotCrash() {
        XCTAssertEqual(tokenReadingOrder(marks: [], hyphens: []), [])
        XCTAssertEqual(readingOrder(marks: []), [])
    }
}
