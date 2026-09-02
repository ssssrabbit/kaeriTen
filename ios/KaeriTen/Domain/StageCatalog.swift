import Foundation

/// M7: ステージ定義（doc §M7 準拠）。
/// Stage1-3〜6・Stage2-3〜6・Stage3-5〜6 の計10ステージに加え、Stage4（ノーヒント）を追加する。
/// Stage4はStage1〜3の全問題からランダムに出題する「総合力を試す」最終ステージという位置づけ
/// （ユーザー判断。§M7実装時に確認済み）。
struct Stage: Identifiable, Hashable {
    /// 進捗保存・recentlyPlayed のキーにも使う（例: "1-3"、Stage4は "4"）。
    let id: String
    /// StageSelectView・盤面見出しに表示するラベル。
    let displayTitle: String
    /// 画面下部の残り返り点在庫表示を出すかどうか（Stage4のみ false）。
    let showHintStock: Bool
    /// 出題プールを絞り込む stage_x の範囲。通常ステージは X...X、Stage4は 1...3。
    let difficultyRange: ClosedRange<Int>
    /// 出題プールを絞り込むトークン数（stage_y）。Stage4はnil（トークン数を問わない）。
    let tokenCount: Int?

    /// 盤面見出しに問題自身のstage_x/stage_yではなく固定文字列を出すかどうか（doc §M7）。
    /// Stage4はStage1〜3の問題をそのまま流用するため、出題ごとにstage_x/stage_yが
    /// バラバラになる。見出しには常にこのステージ自身のdisplayTitleを出す。
    var headingOverride: String? {
        tokenCount == nil ? displayTitle : nil
    }

    /// このステージ再生中に流すBGM（doc §M8）。難易度（stage_x）ごとに1曲割り当てる。
    /// Stage4（tokenCount == nil）はdifficultyRangeが1...3のため、専用に4番として扱う。
    var bgmTrackName: String {
        BGMTrack.name(forDifficulty: tokenCount == nil ? 4 : difficultyRange.lowerBound)
    }

    /// ステージ選択画面でのグループ分け単位（1〜4）。STAGE1/2/3/4の間に余白を入れて
    /// 視覚的に区切るために使う（ユーザー指示）。
    var tier: Int {
        tokenCount == nil ? 4 : difficultyRange.lowerBound
    }

    func matches(_ puzzle: Puzzle) -> Bool {
        guard difficultyRange.contains(puzzle.stageX) else { return false }
        if let tokenCount {
            return puzzle.stageY == tokenCount
        }
        return true
    }
}

enum StageCatalog {
    static let stages: [Stage] = {
        var result: [Stage] = []
        for y in 3...6 {
            result.append(Stage(id: "1-\(y)", displayTitle: "STAGE1-\(y)", showHintStock: true, difficultyRange: 1...1, tokenCount: y))
        }
        for y in 3...6 {
            result.append(Stage(id: "2-\(y)", displayTitle: "STAGE2-\(y)", showHintStock: true, difficultyRange: 2...2, tokenCount: y))
        }
        for y in [5, 6] {
            result.append(Stage(id: "3-\(y)", displayTitle: "STAGE3-\(y)", showHintStock: true, difficultyRange: 3...3, tokenCount: y))
        }
        result.append(Stage(id: "4", displayTitle: "STAGE4", showHintStock: false, difficultyRange: 1...3, tokenCount: nil))
        return result
    }()
}
