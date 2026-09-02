import Foundation

/// M8: BGMの割り当て（doc §M8「曲はステージごとに割り当てる（stage_xで決める等、
/// 実装者判断でよい）」）。難易度（stage_x）ごとに1曲、ステージ選択画面に1曲を割り当てる。
/// `resource/bgm/` にある10曲のうち5曲を使用する（残りは未使用。将来イベント等での
/// 追加割り当てに使える）。
enum BGMTrack {
    static let stageSelect = "stageselect"

    private static let byDifficulty: [Int: String] = [
        1: "Clockwork Dumplings",
        2: "Jade Circuit Loop",
        3: "Paper Thin Breath",
        4: "kanbun wars_1", // Stage4（ノーヒント）
    ]

    /// 曲ごとの音量倍率（`AudioEngine.bgmVolume` に掛け合わせる）。
    /// `stageselect` は原曲の音量が大きいため、ユーザー指示で半分未満に下げる。
    private static let volumeMultipliers: [String: Float] = [
        stageSelect: 0.4,
    ]

    static func name(forDifficulty difficulty: Int) -> String {
        byDifficulty[difficulty] ?? byDifficulty[1]!
    }

    static func volumeMultiplier(for name: String) -> Float {
        volumeMultipliers[name] ?? 1.0
    }
}
