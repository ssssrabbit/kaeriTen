import Foundation

/// チュートリアル1問分のデータ。`Resources/tutorial.json` から読み込む（ユーザー指示:
/// 「問題、解答、読み下し文、フレーバーテキストの組はJSONで与えられ変更可能にしておく。
/// チュートリアルの問題数もJSON中のデータの数に対応する」）。
/// marks/hyphens の文字コードは game.sqlite の `marks`/`hyphens` 列と同じ表記
/// （`.`=なし `r`=レ点 `1`〜`4`=一〜四点、hyphensは`0`/`1`）。
struct TutorialEntry: Codable, Identifiable {
    let id: Int
    let kanbun: String
    let marks: String
    let hyphens: String
    let explanation: String
    let kandoku: String
    let flavor: String
}

enum TutorialCatalogError: Error {
    case resourceMissing
}

enum TutorialCatalog {
    static func loadEntries(bundle: Bundle = .main) throws -> [TutorialEntry] {
        guard let url = bundle.url(forResource: "tutorial", withExtension: "json") else {
            throw TutorialCatalogError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TutorialEntry].self, from: data)
    }

    /// `TutorialEntry` を `BoardScene` が扱える `Puzzle` に変換する。answerOrder は
    /// marks/hyphens から `tokenReadingOrder` で機械的に導出する（手入力の順列とズレる
    /// バグを防ぐため。game.sqlite の生成方針と同じ考え方。§ReadingOrder.swift）。
    static func puzzle(from entry: TutorialEntry) -> Puzzle? {
        let tokens = Array(entry.kanbun)
        let marks = entry.marks.compactMap { Mark(rawValue: $0) }
        let hyphens = entry.hyphens.map { $0 == "1" }
        guard marks.count == tokens.count, hyphens.count == max(0, tokens.count - 1) else {
            return nil
        }

        var maxLevel = 1
        for mark in marks {
            switch mark {
            case .ni: maxLevel = max(maxLevel, 2)
            case .san: maxLevel = max(maxLevel, 3)
            case .yon: maxLevel = max(maxLevel, 4)
            default: break
            }
        }

        return Puzzle(
            id: entry.id,
            kanbun: entry.kanbun,
            tokens: tokens,
            kandoku: entry.kandoku,
            flavor: entry.flavor,
            answerMarks: marks,
            answerHyphens: hyphens,
            answerOrder: tokenReadingOrder(marks: marks, hyphens: hyphens),
            stageX: hyphens.contains(true) ? 3 : (maxLevel >= 2 ? 2 : 1),
            stageY: tokens.count,
            maxLevel: maxLevel,
            kandokuOK: true
        )
    }
}
