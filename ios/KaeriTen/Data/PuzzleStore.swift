import Foundation
import SQLite3

enum PuzzleStoreError: Error {
    case cannotOpenDatabase(String)
    case queryFailed(String)
    case bundleResourceMissing
}

/// game.sqlite（M1 で生成した軽量問題DB）への薄い読み取り専用アクセス。
/// 画像は必要になるまで読み込まない（imageData(for:) で遅延取得）。
final class PuzzleStore {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            throw PuzzleStoreError.cannotOpenDatabase(message)
        }
    }

    /// アプリ本体では既定の `.main` を、テストターゲットでは
    /// `Bundle(for: SomeTestClass.self)` を渡す。
    convenience init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "game", withExtension: "sqlite") else {
            throw PuzzleStoreError.bundleResourceMissing
        }
        try self.init(path: url.path)
    }

    deinit {
        sqlite3_close(db)
    }

    private static func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let cstr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: cstr)
    }

    func loadAllPuzzles() throws -> [Puzzle] {
        let sql = """
        SELECT id, kanbun, kandoku, flavor, marks, hyphens, reading_order,
               token_count, stage_x, stage_y, max_level, kandoku_ok
        FROM puzzles
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PuzzleStoreError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        var puzzles: [Puzzle] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let kanbun = Self.columnText(stmt, 1)
            let kandoku = Self.columnText(stmt, 2)
            let flavor = Self.columnText(stmt, 3)
            let marksStr = Self.columnText(stmt, 4)
            let hyphensStr = Self.columnText(stmt, 5)
            let readingOrderStr = Self.columnText(stmt, 6)
            let stageX = Int(sqlite3_column_int(stmt, 8))
            let stageY = Int(sqlite3_column_int(stmt, 9))
            let maxLevel = Int(sqlite3_column_int(stmt, 10))
            let kandokuOK = sqlite3_column_int(stmt, 11) != 0

            let tokens = Array(kanbun)
            let marks = marksStr.compactMap { Mark(rawValue: $0) }
            let hyphens = hyphensStr.map { $0 == "1" }
            let order = readingOrderStr.compactMap { Int(String($0)) }.map { $0 - 1 }

            // game.sqlite は M1 で自己検証済みだが、念のため形式が壊れた行は読み飛ばす
            // （クラッシュさせない。§4 の安全策方針）。
            guard marks.count == tokens.count,
                  hyphens.count == max(0, tokens.count - 1),
                  order.count == tokens.count else {
                continue
            }

            // 返り点が1つも必要ない問題（marksが全て.none）は、何も操作しなくても
            // 最初から正解と一致してしまい、プレイヤーが何もしないままクリアになる。
            // ゲームとして成立しないため出題しない（ユーザーフィードバック）。
            guard marks.contains(where: { $0 != .none }) else {
                continue
            }

            puzzles.append(
                Puzzle(
                    id: id,
                    kanbun: kanbun,
                    tokens: tokens,
                    kandoku: kandoku,
                    flavor: flavor,
                    answerMarks: marks,
                    answerHyphens: hyphens,
                    answerOrder: order,
                    stageX: stageX,
                    stageY: stageY,
                    maxLevel: maxLevel,
                    kandokuOK: kandokuOK
                )
            )
        }
        return puzzles
    }

    func imageData(for id: Int) throws -> Data? {
        let sql = "SELECT image FROM puzzles WHERE id = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PuzzleStoreError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let blob = sqlite3_column_blob(stmt, 0) else { return nil }
        let size = Int(sqlite3_column_bytes(stmt, 0))
        return Data(bytes: blob, count: size)
    }
}
