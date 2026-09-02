import SwiftUI
import SpriteKit

/// チュートリアルへのルート用マーカー。
struct TutorialRoute: Hashable {}

/// チュートリアル（練習）モード。`tutorial.json` の問題を順番に出題する。
/// 制限時間・ライフのプレッシャーは掛けず（`timeLimitEnabled: false`）、各問題の説明文を
/// 画面下部に常時表示する（ユーザー指示: 「入力フィールドをタップすると返点を選択できる」
/// 等の操作説明を見せながら解かせる）。BoardScene はステージ攻略時と同じものを使い回し、
/// クリア時の書き下し文・フレーバーテキスト表示もそのまま流用する。
struct TutorialFlowView: View {
    @Binding var path: NavigationPath

    @State private var entries: [TutorialEntry] = []
    @State private var currentIndex = 0
    @State private var boardScene: BoardScene?
    @State private var loadError: String?

    private var currentExplanation: String? {
        guard entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex].explanation
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                if let boardScene {
                    SpriteView(scene: boardScene)
                        .ignoresSafeArea()
                } else if let loadError {
                    Text(loadError)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ProgressView().tint(.cyan)
                }
                if let currentExplanation {
                    Text(currentExplanation)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.cyan.opacity(0.92))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        .transition(.opacity)
                        .id(currentIndex)
                }
            }
            .task { start(size: geo.size) }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func start(size: CGSize) {
        AudioEngine.shared.playBGM(BGMTrack.stageSelect)
        do {
            let loaded = try TutorialCatalog.loadEntries()
            guard !loaded.isEmpty else {
                loadError = "チュートリアルの問題が見つかりません"
                return
            }
            entries = loaded
            currentIndex = 0
            presentPuzzle(at: 0, size: size)
        } catch {
            loadError = "読み込み失敗: \(error)"
        }
    }

    private func presentPuzzle(at index: Int, size: CGSize) {
        guard let puzzle = TutorialCatalog.puzzle(from: entries[index]) else {
            loadError = "問題データが不正です"
            return
        }
        if let boardScene {
            boardScene.loadPuzzle(puzzle)
        } else {
            let scene = BoardScene(
                gameState: GameState(puzzle: puzzle),
                size: size,
                showHintStock: true,
                timeLimitEnabled: false,
                stageHeadingOverride: "チュートリアル",
                onPuzzleFinished: { _, _ in }
            )
            scene.onResultAdvance = { advance(size: size) }
            boardScene = scene
        }
    }

    /// 結果パネルが閉じられたときに呼ばれる。次の問題があれば進み、なければ開始画面へ戻る。
    private func advance(size: CGSize) {
        let next = currentIndex + 1
        guard next < entries.count else {
            path = NavigationPath()
            return
        }
        currentIndex = next
        presentPuzzle(at: next, size: size)
    }
}
