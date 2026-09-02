import Foundation

/// M7: 進捗の永続化（doc §M7「進捗保存」）。UserDefaultsにJSONで保存する。
struct Progress: Codable {
    var clearedStages: Set<String> = []
    var bestMoves: [String: Int] = [:]
    /// ステージ（`Stage.id`）ごとの直近出題id（FIFO、古い順）。
    var recentlyPlayed: [String: [Int]] = [:]
    var bgmVolume: Double = 0.7
    var seVolume: Double = 0.7
    /// ステージ（`Stage.id`）ごとの累計クリア回数のうち、ノーミス（パーフェクト）だった回数。
    /// ステージ選択画面のチェックマーク表示（パーフェクトは check_1 を左側に）と、
    /// Game Center実績「最初のパーフェクト」の判定に使う（ユーザー指示）。
    var perfectClearCounts: [String: Int] = [:]
    /// ステージ（`Stage.id`）ごとの累計クリア回数のうち、ミス（タイムアウト）があった回数。
    /// チェックマーク表示では check_5 として右側に並べる。
    var missClearCounts: [String: Int] = [:]
    /// 全ステージ通算のクリア問題数（チュートリアルは含まない）。Game Center実績
    /// 「合計100問のクリア」「合計1000問のクリア」の判定に使う。
    var totalPuzzlesCleared: Int = 0
    /// 既に解除済み（Game Centerへ報告済み）の実績ID。重複報告を避けるためのローカル記録
    /// （`AchievementCatalog.Achievement.id` と対応）。
    var unlockedAchievements: Set<String> = []

    private static let userDefaultsKey = "de.opqrco.kaeriten.progress"

    private enum CodingKeys: String, CodingKey {
        case clearedStages, bestMoves, recentlyPlayed, bgmVolume, seVolume
        case perfectClearCounts, missClearCounts, totalPuzzlesCleared, unlockedAchievements
    }

    init() {}

    /// 既存インストールの保存済みJSONには新しいフィールドが存在しないことがある。
    /// 素直な自動合成デコードだと欠けているキーでデコード全体が失敗し、
    /// `load()` が既存の進捗を丸ごと空にリセットしてしまうため、フィールドごとに
    /// `decodeIfPresent` でフォールバックする（進捗データを壊さないための対応）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clearedStages = try container.decodeIfPresent(Set<String>.self, forKey: .clearedStages) ?? []
        bestMoves = try container.decodeIfPresent([String: Int].self, forKey: .bestMoves) ?? [:]
        recentlyPlayed = try container.decodeIfPresent([String: [Int]].self, forKey: .recentlyPlayed) ?? [:]
        bgmVolume = try container.decodeIfPresent(Double.self, forKey: .bgmVolume) ?? 0.7
        seVolume = try container.decodeIfPresent(Double.self, forKey: .seVolume) ?? 0.7
        perfectClearCounts = try container.decodeIfPresent([String: Int].self, forKey: .perfectClearCounts) ?? [:]
        missClearCounts = try container.decodeIfPresent([String: Int].self, forKey: .missClearCounts) ?? [:]
        totalPuzzlesCleared = try container.decodeIfPresent(Int.self, forKey: .totalPuzzlesCleared) ?? 0
        unlockedAchievements = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedAchievements) ?? []
    }

    static func load(userDefaults: UserDefaults = .standard) -> Progress {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(Progress.self, from: data) else {
            return Progress()
        }
        return decoded
    }

    func save(userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    /// ステージを1回通してクリアしたときに呼ぶ。手数は最少値を保持し、
    /// `perfect`（ノーミスだったか）に応じてパーフェクト/ミスありのクリア回数を1増やす。
    mutating func recordStageCleared(stageID: String, moves: Int, perfect: Bool) {
        clearedStages.insert(stageID)
        if perfect {
            perfectClearCounts[stageID, default: 0] += 1
        } else {
            missClearCounts[stageID, default: 0] += 1
        }
        if let existing = bestMoves[stageID] {
            bestMoves[stageID] = min(existing, moves)
        } else {
            bestMoves[stageID] = moves
        }
    }

    /// 問題を1問クリアしたときに呼ぶ（チュートリアルを除く）。
    mutating func recordPuzzleCleared() {
        totalPuzzlesCleared += 1
    }
}
