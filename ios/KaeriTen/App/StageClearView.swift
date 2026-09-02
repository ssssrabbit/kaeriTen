import SwiftUI

/// M7: NavigationStack の path に積む結果ルート（Stageだけでは手数を運べないため）。
/// `grade` はゲームオーバー機能: クリア時点の残りライフから算出した評価。
struct StageClearRoute: Hashable {
    let stage: Stage
    let moves: Int
    let grade: StageGrade
}

/// M7: ステージクリア画面（doc §M7）。「STAGE CLEAR」と手数を表示し、
/// タップでステージ選択へ戻る（NavigationPathを空にした上でStageSelectRouteを積み直す。
/// アプリのルートは開始画面`TitleView`のため、単に空にするだけだと開始画面に戻ってしまう）。
struct StageClearView: View {
    let route: StageClearRoute
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 28) {
            Text("STAGE CLEAR")
                .font(.system(size: 42, weight: .heavy))
                .foregroundColor(.cyan)
            Text(route.grade.rawValue)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(gradeColor)
            Text(route.stage.displayTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("\(route.moves) 手")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.yellow)
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

    private var gradeColor: Color {
        switch route.grade {
        case .perfect: return .yellow
        case .great: return .cyan
        case .good: return .green
        case .notBad: return .gray
        }
    }
}
