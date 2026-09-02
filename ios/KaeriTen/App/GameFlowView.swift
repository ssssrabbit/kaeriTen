import SwiftUI
import SpriteKit

/// M7: 1ステージ分（5問）のプレイフロー。
/// BoardScene は画面表示中ずっと使い回し、問題送りは `BoardScene.loadPuzzle(_:)` で行う
/// （SwiftUI 側で scene を差し替えても画面に反映されない現象を回避するため。§M6 実装メモ参照）。
struct GameFlowView: View {
    let stage: Stage
    @Binding var path: NavigationPath

    @State private var store: PuzzleStore?
    @State private var sessionPuzzles: [Puzzle] = []
    @State private var currentPuzzleIndex = 0
    @State private var moveCount = 0
    @State private var boardScene: BoardScene?
    @State private var loadError: String?
    /// ゲームオーバー機能: ステージを通して持ち越すライフ（0〜1）。
    @State private var life: Double = LifeSystem.initialLife
    /// ライフが尽きたことを検知したフラグ。結果パネルを見せ終わった後
    /// （`onResultAdvance`）でゲームオーバー画面へ遷移する。
    @State private var isGameOver = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
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
            }
            .task { await start(size: geo.size) }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 画面表示時に一度だけ呼ばれる。このステージの出題を抽選し、最初の1問を表示する。
    private func start(size: CGSize) async {
        AudioEngine.shared.playBGM(stage.bgmTrackName)
        do {
            let store = try PuzzleStore()
            self.store = store
            let all = try store.loadAllPuzzles()
            let pool = all.filter { stage.matches($0) }
            guard !pool.isEmpty else {
                loadError = "問題が見つかりません"
                return
            }

            var progress = Progress.load()
            let recently = progress.recentlyPlayed[stage.id] ?? []
            var rng = SystemRandomNumberGenerator()
            let selected = PuzzleSelection.selectPuzzles(
                from: pool,
                excluding: recently,
                count: PuzzleSelection.puzzlesPerSession,
                using: &rng
            )
            progress.recentlyPlayed[stage.id] = PuzzleSelection.updatedRecentlyPlayed(
                current: recently,
                newlyPlayed: selected.map(\.id),
                poolSize: pool.count
            )
            progress.save()

            sessionPuzzles = selected
            currentPuzzleIndex = 0
            moveCount = 0
            life = LifeSystem.initialLife
            isGameOver = false
            presentPuzzle(at: 0, size: size)
        } catch {
            loadError = "読み込み失敗: \(error)"
        }
    }

    private func presentPuzzle(at index: Int, size: CGSize) {
        let puzzle = sessionPuzzles[index]
        let scene = BoardScene(
            gameState: GameState(puzzle: puzzle),
            size: size,
            showHintStock: stage.showHintStock,
            stageHeadingOverride: stage.headingOverride,
            onPuzzleFinished: { id, success in handlePuzzleFinished(id: id, success: success) }
        )
        scene.onBoardChanged = { moveCount += 1 }
        scene.onResultAdvance = { advanceOrFinishStage() }
        boardScene = scene
    }

    /// 結果パネルの画像を非同期取得する（doc §M6 実装メモ）。
    private func loadResultImage(for id: Int) {
        guard let store else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? store.imageData(for: id)
            let image = data.flatMap { UIImage(data: $0) }
            guard let image else { return }
            DispatchQueue.main.async {
                boardScene?.updateResultImage(image)
            }
        }
    }

    /// 問題が終了した（クリア or 制限時間切れのミス）ときに BoardScene から呼ばれる
    /// （ゲームオーバー機能）。正解ならライフを1/9回復、ミスなら1/3減少させ、
    /// ライフが尽きたら `isGameOver` を立てる（実際の画面遷移は結果パネルを
    /// 見せ終えた後の `advanceOrFinishStage()` で行う）。
    /// ミス時は結果パネルに正解画像を出さないため、画像取得も行わない（doc §M8.5）。
    private func handlePuzzleFinished(id: Int, success: Bool) {
        if success {
            loadResultImage(for: id)
            var progress = Progress.load()
            progress.recordPuzzleCleared()
            progress = AchievementManager.evaluate(progress)
            progress.save()
        }
        life = success ? LifeSystem.applyClear(to: life) : LifeSystem.applyMiss(to: life)
        boardScene?.updateLife(life)
        if life <= 0 {
            isGameOver = true
        }
    }

    /// 結果パネルが閉じられた（タップ or 4秒経過）ときに BoardScene から呼ばれる。
    /// ライフが尽きていればゲームオーバー画面へ、このステージの5問を出し切っていれば
    /// StageClearView へ、そうでなければ次の問題へ進む。
    private func advanceOrFinishStage() {
        if isGameOver {
            AudioEngine.shared.playSE("gameover")
            path.append(GameOverRoute(stage: stage, moves: moveCount))
            return
        }
        let nextIndex = currentPuzzleIndex + 1
        guard nextIndex < sessionPuzzles.count else {
            let grade = StageGrade.from(life: life)
            var progress = Progress.load()
            progress.recordStageCleared(stageID: stage.id, moves: moveCount, perfect: grade == .perfect)
            progress = AchievementManager.evaluate(progress)
            progress.save()
            AudioEngine.shared.playSE("stageclear")
            path.append(StageClearRoute(stage: stage, moves: moveCount, grade: grade))
            return
        }
        currentPuzzleIndex = nextIndex
        boardScene?.loadPuzzle(sessionPuzzles[nextIndex])
    }
}
