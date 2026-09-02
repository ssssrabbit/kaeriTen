import SwiftUI

/// ゲームオーバー機能: NavigationStack の path に積むゲームオーバールート。
struct GameOverRoute: Hashable {
    let stage: Stage
    let moves: Int
}

/// ゲームオーバー画面。ライフが尽きたときに表示する（進捗は保存しない＝
/// clearedStages/bestMoves には反映されない）。タップでステージ選択へ戻る。
struct GameOverView: View {
    let route: GameOverRoute
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 28) {
            Text("GAME OVER")
                .font(.system(size: 42, weight: .heavy))
                .foregroundColor(.red)
            Text(route.stage.displayTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Button {
                path = NavigationPath()
                path.append(StageSelectRoute())
            } label: {
                Text("ステージ選択へ戻る")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.cyan))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}
