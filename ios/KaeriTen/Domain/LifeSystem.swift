import Foundation

/// ゲームオーバー機能（ユーザー指示: 制限時間内にクリアできないとミス、ミスでライフ減少、
/// 正解でライフ増加、ライフ0でゲームオーバー）の数値パラメータ。
enum LifeSystem {
    /// 1問あたりの制限時間（秒）。
    static let timeLimit: TimeInterval = 30.0
    /// ライフの初期値・最大値（1.0 = 満タン）。
    static let initialLife: Double = 1.0
    /// ミス（タイムアウト）1回あたりのライフ減少量。
    static let missPenalty: Double = 1.0 / 3.0
    /// 正解（制限時間内クリア）1回あたりのライフ回復量。
    static let clearBonus: Double = 1.0 / 9.0

    static func applyMiss(to life: Double) -> Double {
        max(0, life - missPenalty)
    }

    static func applyClear(to life: Double) -> Double {
        min(initialLife, life + clearBonus)
    }
}

/// ステージクリア時、残りライフに応じて表示する評価（ユーザー指示）。
/// missPenalty(1/3) 刻みのライフ残量を境界にする: 満タン=PERFECT、
/// ミス1回分以内の消費まで=GREAT、ミス2回分以内=GOOD、それ以外（生き残った）=NOT BAD。
enum StageGrade: String, Hashable {
    case perfect = "PERFECT"
    case great = "GREAT"
    case good = "GOOD"
    case notBad = "NOT BAD"

    static func from(life: Double) -> StageGrade {
        if life >= LifeSystem.initialLife { return .perfect }
        if life >= LifeSystem.initialLife - LifeSystem.missPenalty { return .great }
        if life >= LifeSystem.initialLife - LifeSystem.missPenalty * 2 { return .good }
        return .notBad
    }
}
