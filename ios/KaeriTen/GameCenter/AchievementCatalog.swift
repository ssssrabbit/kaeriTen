import Foundation

/// Game Center実績の定義（ユーザー指示）。`id` は App Store Connect 側で実績を
/// 作成するときに指定する識別子とそのまま一致させること（設定手順は
/// docs/GAME_CENTER_ACHIEVEMENTS.md 参照）。
struct AchievementDefinition {
    let id: String
    /// デバッグ表示・ドキュメント用の日本語名（App Store Connect側の表示名とは別管理）。
    let title: String
    /// `progress` から見て、この実績の条件を満たしているか判定する。
    let isSatisfied: (Progress) -> Bool
}

enum AchievementCatalog {
    private static let idPrefix = "de.opqrco.kaeriten.achievement."

    /// STAGE4を除く通常10ステージ（STAGE1-3〜3-6）。「全ラウンド」実績の対象。
    private static var regularStages: [Stage] {
        StageCatalog.stages.filter { $0.tier != 4 }
    }

    /// ステージ選択画面のチェックマークと同じ基準（合計6回クリアで完全クリア）。
    private static func isFullyCleared(_ stage: Stage, in progress: Progress) -> Bool {
        let perfect = progress.perfectClearCounts[stage.id] ?? 0
        let miss = progress.missClearCounts[stage.id] ?? 0
        return perfect + miss >= 6
    }

    static let all: [AchievementDefinition] = [
        AchievementDefinition(
            id: idPrefix + "firstClear",
            title: "最初のクリア",
            isSatisfied: { !$0.clearedStages.isEmpty }
        ),
        AchievementDefinition(
            id: idPrefix + "allRounds123",
            title: "STAGE1/2/3の全てのラウンドの1回以上のクリア",
            isSatisfied: { progress in
                regularStages.allSatisfy { progress.clearedStages.contains($0.id) }
            }
        ),
        AchievementDefinition(
            id: idPrefix + "firstPerfect",
            title: "最初のパーフェクト",
            isSatisfied: { progress in
                progress.perfectClearCounts.values.contains { $0 > 0 }
            }
        ),
        AchievementDefinition(
            id: idPrefix + "fullComplete",
            title: "STAGE1/2/3/4フルコンプリート",
            isSatisfied: { progress in
                StageCatalog.stages.allSatisfy { isFullyCleared($0, in: progress) }
            }
        ),
        AchievementDefinition(
            id: idPrefix + "clear100",
            title: "合計100問のクリア",
            isSatisfied: { $0.totalPuzzlesCleared >= 100 }
        ),
        AchievementDefinition(
            id: idPrefix + "clear1000",
            title: "合計1000問のクリア",
            isSatisfied: { $0.totalPuzzlesCleared >= 1000 }
        ),
    ]
}
