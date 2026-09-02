import Foundation
import GameKit
import UIKit

/// Game Centerへのサインイン・実績報告をまとめて扱う（ユーザー指示: Game Center実績の実装）。
/// 実績の条件判定そのものは `Progress` のデータだけから計算できるため（`AchievementCatalog`）、
/// Game Centerにサインインしていない・報告に失敗した場合でもローカルの進捗記録自体は
/// 正しく積み上がる。次に `evaluate(_:)` が呼ばれたとき（サインイン後を含む）に
/// 未報告分がまとめて報告される。
enum AchievementManager {
    /// アプリ起動時に1回呼ぶ。サインインUIが必要な場合は自動的に表示する。
    static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController {
                presentAuthController(viewController)
                return
            }
            if let error {
                print("Game Center認証エラー: \(error.localizedDescription)")
            }
            // GKLocalPlayer.local.isAuthenticated が true ならサインイン済み。
            // 未サインインのまま進める場合は実績報告が次回サインイン後まで
            // 保留されるだけで、ゲーム自体はそのままプレイできる。
        }
    }

    private static func presentAuthController(_ viewController: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: \.isKeyWindow)?.rootViewController
        else { return }
        root.present(viewController, animated: true)
    }

    /// `progress` を評価し、新たに条件を満たした実績があればGame Centerへ報告する。
    /// 呼び出し側は返り値（`unlockedAchievements` が更新されている）を保存すること。
    /// ステージクリア・問題クリアなど、進捗が変化するたびに呼ぶ想定。
    @discardableResult
    static func evaluate(_ progress: Progress) -> Progress {
        var updated = progress
        let newlySatisfied = AchievementCatalog.all.filter { achievement in
            !updated.unlockedAchievements.contains(achievement.id) && achievement.isSatisfied(updated)
        }
        guard !newlySatisfied.isEmpty else { return updated }

        guard GKLocalPlayer.local.isAuthenticated else {
            // 未サインイン: ローカルでは未解除のまま保持し、サインイン後の次回評価で報告する。
            return updated
        }

        let reports = newlySatisfied.map { achievement -> GKAchievement in
            let a = GKAchievement(identifier: achievement.id)
            a.percentComplete = 100
            a.showsCompletionBanner = true
            return a
        }
        GKAchievement.report(reports) { error in
            if let error {
                print("Game Center実績報告エラー: \(error.localizedDescription)")
            }
        }
        // 報告はネットワーク経由で非同期に失敗しうるが、GKAchievementの報告はSDK側で
        // 再送されるため、ここでローカルの解除済みとして先に記録して二重報告を避ける。
        for achievement in newlySatisfied {
            updated.unlockedAchievements.insert(achievement.id)
        }
        return updated
    }
}
