import SwiftUI

/// 開始画面（`TitleView`）から遷移するルート用マーカー。
struct StageSelectRoute: Hashable {}

/// M7: 11ステージをグリッド表示し、タップで `GameFlowView` へ push する画面。
/// アプリのルートは `TitleView` が持つ1つの `NavigationStack` に一本化されているため、
/// この画面自身は `NavigationStack` を持たず、`@Binding var path` を受け取って
/// 共有する（doc §M7「画面遷移」／開始画面追加に伴う構成変更）。
struct StageSelectView: View {
    @Binding var path: NavigationPath
    @State private var progress = Progress.load()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    /// STAGE1/2/3/4ごとにグループ分けする（ユーザー指示: 「STAGE1, 2, 3, 4の間に
    /// 少しスペースを入れてステージの違いを視覚的にわかりやすくする」）。
    /// `Dictionary(grouping:)` はグループ内の元の順序を保つため、各グループ内の
    /// ステージ順は `StageCatalog.stages` の並びのまま。
    private var groupedStages: [[Stage]] {
        Dictionary(grouping: StageCatalog.stages, by: \.tier)
            .sorted { $0.key < $1.key }
            .map(\.value)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ForEach(groupedStages, id: \.self) { group in
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(group) { stage in
                            NavigationLink(value: stage) {
                                StageCell(
                                    stage: stage,
                                    perfectCount: progress.perfectClearCounts[stage.id] ?? 0,
                                    missCount: progress.missClearCounts[stage.id] ?? 0
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("返り点")
        .onAppear {
            progress = Progress.load()
            AudioEngine.shared.bgmVolume = Float(progress.bgmVolume)
            AudioEngine.shared.seVolume = Float(progress.seVolume)
            AudioEngine.shared.playBGM(BGMTrack.stageSelect)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(SettingsRoute())
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}

private struct StageCell: View {
    let stage: Stage
    let perfectCount: Int
    let missCount: Int

    /// クリア回数に応じたチェック表示（ユーザー指示）:
    /// パーフェクト（ノーミス）クリアは check_1、ミスがあったクリアは check_5。
    /// 常に1段で、パーフェクトのマークを左、ミスありのマークを右に並べる
    /// （2段だとセルの高さが揃わなくなるため1段構成にした）。
    /// 合計6回クリアで check_full 1個（完全クリア）にする。
    private static let fullClearThreshold = 6

    private var totalCount: Int { perfectCount + missCount }

    var body: some View {
        VStack(spacing: 8) {
            Text(stage.displayTitle)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.cyan)
            checkRow
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var checkRow: some View {
        if totalCount >= Self.fullClearThreshold {
            checkIcon("check_full")
        } else if totalCount > 0 {
            HStack(spacing: 2) {
                ForEach(0..<perfectCount, id: \.self) { _ in
                    checkIcon("check_1") // パーフェクト（左）
                }
                ForEach(0..<missCount, id: \.self) { _ in
                    checkIcon("check_5") // ミスあり（右）
                }
            }
        } else {
            Color.clear.frame(height: 18)
        }
    }

    private func checkIcon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
    }
}

#Preview {
    NavigationStack {
        StageSelectView(path: .constant(NavigationPath()))
    }
}
