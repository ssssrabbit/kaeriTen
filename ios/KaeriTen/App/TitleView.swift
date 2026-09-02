import SwiftUI
import SpriteKit

/// アプリの実際のルート画面（ユーザー指示: 「ステージ選択」「チュートリアル」「設定」を
/// 選べる開始画面を追加）。アプリ全体で唯一の `NavigationStack` をここが持ち、
/// 他の画面（StageSelectView・GameFlowView・TutorialFlowView・StageClearView・
/// GameOverView・SettingsView）はすべて `@Binding var path` を受け取って
/// この1本のスタックを共有する（doc §M7の設計を踏襲）。
/// オープニングでは `OpeningScene`（アプリアイコンの構成要素が動いて組み上がる
/// モーショングラフィックス）を表示し、完了後にメニューボタンをフェードインする。
struct TitleView: View {
    @State private var path = NavigationPath()
    @State private var openingScene = OpeningScene(size: CGSize(width: 400, height: 874))
    @State private var showMenu = false
    @State private var openingStarted = false

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()
                    SpriteView(scene: openingScene)
                        .ignoresSafeArea()
                        // アプリ起動直後、NavigationStackの直下に置いたGeometryReaderは
                        // 最初の1回 size=(0,0) で.onAppearが発火することがある
                        // （NavigationStack自身のレイアウトがまだ確定していないため）。
                        // .onAppearではなく、実際のサイズが確定してから発火する
                        // .onChange(of: geo.size)でオープニングを開始する。
                        .onChange(of: geo.size) { _, newSize in
                            guard !openingStarted, newSize.width > 0, newSize.height > 0 else { return }
                            openingStarted = true
                            openingScene.size = newSize
                            openingScene.scaleMode = .resizeFill
                            openingScene.play { showMenu = true }
                        }

                    VStack(spacing: 20) {
                        Text("kaeriTen")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(.cyan)
                            .padding(.bottom, 8)
                        menuButton(title: "ステージ選択") { path.append(StageSelectRoute()) }
                        menuButton(title: "チュートリアル") { path.append(TutorialRoute()) }
                        menuButton(title: "設定") { path.append(SettingsRoute()) }
                    }
                    .padding(.top, geo.size.height * 0.32)
                    .opacity(showMenu ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: showMenu)
                }
                // Game Centerサインインはアプリ起動時に1回だけ行う
                // （docs/GAME_CENTER_ACHIEVEMENTS.md 参照）。
                .task { AchievementManager.authenticate() }
            }
            .navigationDestination(for: StageSelectRoute.self) { _ in
                StageSelectView(path: $path)
            }
            .navigationDestination(for: TutorialRoute.self) { _ in
                TutorialFlowView(path: $path)
            }
            .navigationDestination(for: Stage.self) { stage in
                GameFlowView(stage: stage, path: $path)
            }
            .navigationDestination(for: StageClearRoute.self) { route in
                StageClearView(route: route, path: $path)
            }
            .navigationDestination(for: GameOverRoute.self) { route in
                GameOverView(route: route, path: $path)
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView()
            }
        }
    }

    private func menuButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 220)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.cyan))
        }
    }
}

#Preview {
    TitleView()
}
