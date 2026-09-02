import SpriteKit
import UIKit

/// KaeriTen パレット（docs/KAERITEN_IOS_BUILD_INSTRUCTIONS.md §3 / §M3 実測値）
enum BoardPalette {
    static let background = SKColor.black
    static let stageHeading = SKColor(red: 0, green: 197 / 255, blue: 255 / 255, alpha: 1)
    static let gridBorder = SKColor(red: 255 / 255, green: 244 / 255, blue: 93 / 255, alpha: 1)
    static let answerLine = SKColor(red: 255 / 255, green: 93 / 255, blue: 223 / 255, alpha: 1)
    /// FAILED表示・不正解バッジの赤丸に使う色（既存のFAILEDラベルと同色で統一する）。
    static let wrongInput = SKColor(red: 1, green: 59 / 255, blue: 59 / 255, alpha: 1)
    static let pipeIdle = SKColor(red: 0, green: 80 / 255, blue: 89 / 255, alpha: 1)
    static let pipeMatched = SKColor(red: 31 / 255, green: 191 / 255, blue: 212 / 255, alpha: 1)
    static let kanjiBoxFill = SKColor(red: 204 / 255, green: 204 / 255, blue: 204 / 255, alpha: 1)
    static let kanjiText = SKColor.black
    static let markSlotEmptyFill = SKColor.black
    static let markSlotFilledFill = SKColor(red: 0.227, green: 0.227, blue: 0.227, alpha: 1)
    static let markSlotFilledText = SKColor.white
    /// メニュー・ハイフントグルの半透明カプセル色（doc §M4 実測 #7FE9F5 が原点）。
    /// alpha は 0.35→0.65→0.55 と調整してきたが、明るい水色に白文字を重ねると
    /// コントラストが弱く読みにくいというフィードバックを受け、色そのものを
    /// 明度を落とした水色に変更した上で不透明度もさらに下げた。
    static let menuCapsule = SKColor(red: 91 / 255, green: 168 / 255, blue: 176 / 255, alpha: 0.45)
    static let menuItemDisabled = SKColor(white: 0.4, alpha: 1)
    static let menuItemEnabled = SKColor(red: 127 / 255, green: 233 / 255, blue: 245 / 255, alpha: 1)
    static let menuItemHighlighted = SKColor.white
    /// メニュー項目の文字色（レ・一・二など）。有効/無効に関わらず常に白・不透明100%で
    /// 表示する（有効/無効の区別は丸枠の色で示す）。パネル背景が半透明でも文字が
    /// はっきり読めるようにするためのフィードバック対応。
    static let menuItemText = SKColor.white
}

/// 盤面レイアウトの相対値（実測画像1320x2868から算出。scene.size に対する比率として使う）
enum BoardLayout {
    static let gridLeft: CGFloat = 0.053
    static let gridRight: CGFloat = 0.946
    static let columnWidthFraction: CGFloat = 0.098
    /// グリッド1行目の上端（画面上端からの距離）。返り点の残数リストを見出しの下・
    /// グリッドの上に表示するため、その分の余白を確保した値になっている
    /// （doc §M8.5後 ユーザー指示）。
    static let rowTop: CGFloat = 0.32
    /// 黄色いボックスの高さ / 列幅（1.0で正方形。画面のアスペクト比に依存せず一定にするため列幅から算出する）
    static let rowHeightToColumnWidthRatio: CGFloat = 1.0
    static let rowPitchFraction: CGFloat = 0.084
    /// グリッド最終行の下端から漢字行上端までの間隔（トークン数によらず一定。グリッドと
    /// はっきり離して見えるようにする）
    static let gapAfterGridFraction: CGFloat = 0.055
    /// 漢字ボックスの一辺 / 黄色いボックスの一辺（中心のX座標は変えずに拡大する）
    static let kanjiBoxScale: CGFloat = 1.3
    /// ステージ見出し・ライフ/残り時間ボトルの中心Y。Dynamic Islandにかかる可能性が
    /// あるため、画面上端とグリッド1行目の中間（rowTop/2）よりも下げて配置する。
    static let stageHeadingCenterY: CGFloat = 0.16
    /// ライフ／残り時間ボトルの表示高さ（見出し文字の高さに合わせる）。
    static let hudBottleHeightFraction: CGFloat = 0.065
    /// ボトル中心のX位置（画面端からの距離）。
    static let hudBottleInsetXFraction: CGFloat = 0.11
    /// 使用する返り点の残数リストの中心Y（見出し/HUDの下・グリッドの上。doc §M8.5後
    /// ユーザー指示: 画面下部だと縦に短い端末（iPhone SE等）で画面から溢れるため上に移動）。
    static let counterRowCenterYFraction: CGFloat = 0.255
    /// グリッド+漢字行+バッジのブロックの下に確保する安全マージン。
    static let bottomMarginFraction: CGFloat = 0.04
    /// 盤面の横幅の上限（画面高さに対する比率）。iPad等、電話よりも横長/正方形に近い
    /// 画面では、この比率を超える分は左右に黒い余白として残し盤面を中央寄せする
    /// （doc §M8.5後 ユーザー指示: iPadでは黒い領域ができてもよいので中央に表示する）。
    /// 実測した端末比率: iPhone SE比 375/667≈0.562・iPhone比 402/874≈0.460（いずれも
    /// この値未満のため通常表示）、iPad縦 768/1024=0.75・iPad横 1024/768≈1.33（いずれも
    /// この値を超えるため中央寄せされる）。
    static let maxContentAspect: CGFloat = 0.6
}

/// ライフ／残り時間ゲージ（doc: ゲームオーバー機能）。
/// `bottle_water.png`（塗りつぶし画像）をクロップして `bottle_empty.png`（ガラスの輪郭。
/// アルファ画像）の下に重ねることで「壺に水がたまる」見た目を作る。
/// ソース画像（256px高）のうちボトル本体として塗りつぶし可能な範囲は y=63〜233
/// （画像編集ソフトの慣例通り上端0のtop-down座標）。水面は底(233)を固定し、
/// fraction に応じて上端(233-170*fraction)を伸縮させることで、下から水がたまって
/// いくように見せる。
private final class BottleGaugeNode: SKNode {
    private static let sourceHeight: CGFloat = 256
    private static let fillTopPx: CGFloat = 63
    private static let fillBottomPx: CGFloat = 233

    private let waterNode: SKSpriteNode
    private let waterFullTexture: SKTexture
    private let displaySize: CGSize

    init?(displayHeight: CGFloat) {
        guard
            let emptyImage = BottleGaugeNode.loadImage(named: "bottle_empty"),
            let waterImage = BottleGaugeNode.loadImage(named: "bottle_water"),
            emptyImage.size.height > 0
        else { return nil }

        let aspect = emptyImage.size.width / emptyImage.size.height
        displaySize = CGSize(width: displayHeight * aspect, height: displayHeight)
        waterFullTexture = SKTexture(image: waterImage)
        waterNode = SKSpriteNode(texture: waterFullTexture)
        waterNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        waterNode.zPosition = 0

        super.init()

        let emptyNode = SKSpriteNode(texture: SKTexture(image: emptyImage))
        emptyNode.size = displaySize
        emptyNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        emptyNode.zPosition = 1

        addChild(waterNode)
        addChild(emptyNode)
        setFraction(0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// fraction: 0(空)〜1(満タン)。
    func setFraction(_ fraction: CGFloat) {
        let clamped = max(0, min(1, fraction))
        let fillRangePx = Self.fillBottomPx - Self.fillTopPx
        let croppedHeightPx = fillRangePx * clamped
        guard croppedHeightPx > 0 else {
            waterNode.texture = nil
            waterNode.size = .zero
            return
        }
        let normBottom = 1 - Self.fillBottomPx / Self.sourceHeight
        let normHeight = croppedHeightPx / Self.sourceHeight
        let rect = CGRect(x: 0, y: normBottom, width: 1, height: normHeight)
        waterNode.texture = SKTexture(rect: rect, in: waterFullTexture)

        let scale = displaySize.height / Self.sourceHeight
        waterNode.size = CGSize(width: displaySize.width, height: croppedHeightPx * scale)
        waterNode.position = CGPoint(x: 0, y: (Self.sourceHeight - Self.fillBottomPx) / Self.sourceHeight * displaySize.height)
    }

    /// xcodegen/Xcodeのリソースコピーでサブディレクトリが保たれない場合があるため、
    /// AudioEngine と同様 subdirectory指定ありで見つからなければフラットな配置でも探す。
    private static func loadImage(named name: String) -> UIImage? {
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "images")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

private struct GridCell: Hashable {
    let row: Int
    let col: Int
}

/// 選択メニューを開いている最中の状態。
private struct ActiveMarkMenu {
    let tokenIndex: Int
    let options: [Mark] // スロットに近い順（下から上）。options[0] は常に .none(×)
    let itemCenters: [CGPoint]
    let itemRadius: CGFloat
    let node: SKNode
    let circleNodes: [SKShapeNode]
    let labelNodes: [SKLabelNode]
    var highlightedIndex: Int?
}

/// ハイフントグルを開いている最中は特に無く、タップで即トグルする（ドラッグ不要）。

/// 返り点パズルの盤面を描画・操作する SpriteKit シーン。
final class BoardScene: SKScene {
    private var gameState: GameState
    private var puzzle: Puzzle { gameState.puzzle }

    /// この問題で使う返り点の残数表示（画面下部の水色アイコン）を出すかどうか。
    /// Stage4（ノーヒント）では false にして非表示にする。
    private let showHintStock: Bool

    /// 盤面上部の見出しに問題自体の stage_x/stage_y の代わりに表示する固定文字列（doc §M7）。
    /// Stage4はStage1〜3の問題をそのまま流用するため、出題される問題ごとにstage_x/stage_yが
    /// バラバラになる（例: 元々Stage2-5の問題が出ることもある）。それをそのまま見出しに出すと
    /// 「今Stage4を遊んでいる」ことが伝わらないため、Stage4選択時はここに"STAGE4"を渡す。
    /// nilの場合は従来通り問題自身のstage_x/stage_yから見出しを組み立てる。
    private let stageHeadingOverride: String?

    /// 制限時間・ライフのプレッシャーを有効にするかどうか。チュートリアル（練習）モードでは
    /// false にして、時間切れによるFAILEDを起こさせず、ライフ/残り時間ボトルも表示しない
    /// （ユーザー指示: チュートリアルは説明を読みながらゆっくり操作できるようにする）。
    private let timeLimitEnabled: Bool

    /// 返り点・ハイフンを変更するたびに呼ばれる（M6以降でカウンタ等に使う想定）。
    var onBoardChanged: (() -> Void)?
    /// 問題が終了した（クリア or 制限時間切れのミス）ときに呼ばれる。
    /// 引数は (終了した問題のid, 成功したか)。呼び出し元はこれをトリガーに結果画像を
    /// 取得し、ライフを増減させる（ゲームオーバー機能）。
    var onPuzzleFinished: ((Int, Bool) -> Void)?

    // MARK: - ライフ・制限時間（ゲームオーバー機能）
    private var lifeBottleNode: BottleGaugeNode?
    private var timeBottleNode: BottleGaugeNode?
    private var currentLifeFraction: Double = LifeSystem.initialLife
    private var currentTimeFraction: Double = 1.0
    /// `update(_:)` は SpriteKit が渡す絶対時刻（アプリ起動からの経過秒ではない）を
    /// 使うため、問題ごとの開始時刻は最初の `update` 呼び出し時に遅延取得する。
    private var puzzleStartTime: TimeInterval?
    private var needsTimerReset = true

    // MARK: - 直近の render() で計算した、中央寄せ後の盤面の横幅・左端X（doc §M8.5後）
    /// iPad等のアスペクト比では `BoardLayout.maxContentAspect` を超えないよう盤面の
    /// 横幅を制限し、余った分を左右の黒い余白として中央寄せする。通常の電話サイズ
    /// では `contentWidth == size.width`・`contentOriginX == 0` のまま変わらない。
    private var contentWidth: CGFloat = 0
    private var contentOriginX: CGFloat = 0

    // MARK: - 直近の render() で計算したヒットテスト用ジオメトリ
    private var badgeCenters: [CGPoint] = []
    private var badgeDiameter: CGFloat = 0
    private var hyphenToggleCenters: [CGPoint] = [] // index = gapIndex (token i-1 と i の間)
    private var hyphenToggleDiameter: CGFloat = 0
    private var hyphenToggleUsable: Bool = false

    private var activeMenu: ActiveMarkMenu?

    // MARK: - クリア演出用（M5）
    private var pipePath: CGPath?
    private var pipeStartPoint: CGPoint?
    private var matchedBoxNodes: [SKShapeNode] = []
    /// 既にクリア演出を再生したか（re-render のたびに再発火しないためのフラグ）。
    private var hasPlayedClearAnimation = false
    /// クリア演出中は入力を受け付けない。
    /// （`SKScene.isUserInteractionEnabled` は独自の touchesBegan オーバーライドを
    /// 抑止しないため、明示的なフラグで守る）
    private var inputLocked = false

    // MARK: - 結果画面（M6）
    //
    // 当初 SwiftUI 側（ResultPanel + fullScreenCover/.overlay）で実装したが、この
    // ビルド環境（iOS 26.5 シミュレータSDK）では SpriteView 上に後から追加した
    // SwiftUI コンテンツの再描画が一切画面に反映されない現象を実機シミュレータで
    // 確認した（state は正しく更新されテキストログでも確認できるのに、overlay /
    // zIndex / fullScreenCover のいずれも視覚的に反映されない）。M3-M5 で実績のある
    // SpriteKit 直接描画に切り替えることで確実に動作させる。
    private var resultPanelNode: SKNode?
    private var resultImageNode: SKSpriteNode?
    /// 結果パネルが閉じられた（タップ or 4秒経過）ときに呼ばれる。次の問題への遷移に使う。
    var onResultAdvance: (() -> Void)?

    /// `onPuzzleFinished` は init 引数として受け取り、`super.init(size:)` より前に設定する。
    /// `super.init(size:)` は内部で `didChangeSize` 経由の同期的な最初の `render()`
    /// （`checkForClear()` を含む）を引き起こすことがあり、その時点で既に手遅れの
    /// `scene.onPuzzleFinished = { ... }` という construction 後の代入では、常に返り点なしで
    /// 最初から正解と一致する問題（例: id=1491, marks="..."）で onPuzzleFinished が nil のまま
    /// クリア演出が発火してしまい、結果画面に進めなくなるバグがあった。
    init(gameState: GameState, size: CGSize, showHintStock: Bool = true, timeLimitEnabled: Bool = true, stageHeadingOverride: String? = nil, onPuzzleFinished: ((Int, Bool) -> Void)? = nil) {
        self.gameState = gameState
        self.showHintStock = showHintStock
        self.timeLimitEnabled = timeLimitEnabled
        self.stageHeadingOverride = stageHeadingOverride
        self.onPuzzleFinished = onPuzzleFinished
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = BoardPalette.background
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 別の問題を読み込む。BoardScene のインスタンスは使い回し、GameState だけ差し替える。
    /// （このビルド環境では、SwiftUI 側で `SpriteView(scene:)` の scene を初回表示後に
    /// 差し替えても画面に反映されない現象を確認したため、インスタンスを使い回して
    /// SpriteKit 内部の `render()` だけで完結させる設計にした。§M6 実装メモ参照）
    /// ライフ（`currentLifeFraction`）はステージを通して持ち越すため、ここではリセット
    /// しない。制限時間だけ問題ごとにリセットする。
    func loadPuzzle(_ puzzle: Puzzle) {
        gameState = GameState(puzzle: puzzle)
        hasPlayedClearAnimation = false
        inputLocked = false
        needsTimerReset = true
        currentTimeFraction = 1.0
        resultPanelNode?.removeFromParent()
        resultPanelNode = nil
        resultImageNode = nil
        removeAction(forKey: "resultAutoAdvance")
        render()
    }

    /// ライフの現在値（0〜1）を外部（GameFlowView）から反映する。
    func updateLife(_ fraction: Double) {
        currentLifeFraction = fraction
        lifeBottleNode?.setFraction(CGFloat(fraction))
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        render()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        dismissMenu()
        render()
    }

    /// 制限時間のカウントダウン（doc: ゲームオーバー機能）。結果パネル表示中や
    /// メニュー選択中は `inputLocked` により止まる想定はしていない
    /// （制限時間はメニュー操作中も進む。`inputLocked` は問題終了後のみ true になる）。
    /// `timeBottleNode.setFraction` は呼ぶたびに `SKTexture(rect:in:)` で新しいテクスチャを
    /// 生成する。毎フレーム（60回/秒）呼び続けると不要なテクスチャ生成が積み重なるため、
    /// 見た目のなめらかさを保てる範囲（約10回/秒）に間引く。
    private var lastTimeBottleUpdateAt: TimeInterval = 0
    override func update(_ currentTime: TimeInterval) {
        guard !inputLocked, timeLimitEnabled else { return }
        if needsTimerReset {
            puzzleStartTime = currentTime
            needsTimerReset = false
            lastTimeBottleUpdateAt = 0
        }
        guard let startTime = puzzleStartTime else { return }
        let remaining = max(0, LifeSystem.timeLimit - (currentTime - startTime))
        currentTimeFraction = remaining / LifeSystem.timeLimit
        if remaining <= 0 {
            timeBottleNode?.setFraction(0)
            finishPuzzle(success: false)
            return
        }
        if currentTime - lastTimeBottleUpdateAt >= 0.1 {
            lastTimeBottleUpdateAt = currentTime
            timeBottleNode?.setFraction(CGFloat(currentTimeFraction))
        }
    }

    // MARK: - 描画

    private func render() {
        removeAllChildren()
        badgeCenters = []
        hyphenToggleCenters = []
        matchedBoxNodes = []
        pipePath = nil
        pipeStartPoint = nil
        guard size.width > 0, size.height > 0 else { return }

        let n = puzzle.tokenCount
        guard n > 0 else { return }

        // iPad等、電話よりも横長/正方形に近いアスペクト比では盤面の横幅を制限し、
        // 左右に黒い余白を残して中央寄せする（doc §M8.5後 ユーザー指示）。
        contentWidth = min(size.width, size.height * BoardLayout.maxContentAspect)
        contentOriginX = (size.width - contentWidth) / 2

        // まず「自然な」（未調整の）ボックスサイズを求める。
        let naturalColWidth = contentWidth * BoardLayout.columnWidthFraction
        let naturalRowHeight = naturalColWidth * BoardLayout.rowHeightToColumnWidthRatio
        let naturalRowPitch = size.height * BoardLayout.rowPitchFraction
        let naturalKanjiBoxSize = naturalRowHeight * BoardLayout.kanjiBoxScale
        let naturalGapAfterGrid = size.height * BoardLayout.gapAfterGridFraction

        // グリッド(n行)+漢字行+バッジ余白の合計高さが、実際に使える高さ（見出し/HUD/
        // 返り点残数リストの下から画面下端の安全マージンまで）を超える場合、
        // iPhone SEのような縦に短い端末で画面から溢れないよう、ボックスサイズを
        // 縮小する（doc §M8.5後 ユーザー指示）。
        let naturalGridHeight = naturalRowPitch * CGFloat(n - 1) + naturalRowHeight
        let bottomAllowance = naturalKanjiBoxSize * 0.9 // バッジ・ハイフントグルが漢字行の下にはみ出す分
        let naturalBlockHeight = naturalGridHeight + naturalGapAfterGrid + naturalKanjiBoxSize + bottomAllowance
        let availableHeight = size.height * (1 - BoardLayout.rowTop - BoardLayout.bottomMarginFraction)
        let boxScale: CGFloat = naturalBlockHeight > availableHeight && naturalBlockHeight > 0
            ? max(0.4, availableHeight / naturalBlockHeight)
            : 1.0

        let colWidth = naturalColWidth * boxScale
        // 黄色いボックスを正方形に近づける: 高さを（画面比とは無関係に）列幅から直接求める。
        let rowHeight = colWidth * BoardLayout.rowHeightToColumnWidthRatio
        let rowPitch = naturalRowPitch * boxScale
        let colPitch = contentWidth * (BoardLayout.gridRight - BoardLayout.gridLeft) / CGFloat(n)
        let gridLeftX = contentOriginX + contentWidth * BoardLayout.gridLeft
        let rowTopY = size.height * BoardLayout.rowTop

        func columnCenterX(_ col: Int) -> CGFloat {
            gridLeftX + colPitch * (CGFloat(col) + 0.5)
        }

        // SpriteKit は y が上向きなので、行 row（0始まり、上から下）の
        // 上端 y(SpriteKit座標) = scene.height - rowTopY - rowPitch*row
        func rowTopSK(_ row: Int) -> CGFloat {
            size.height - rowTopY - rowPitch * CGFloat(row)
        }

        // グリッド最終行(row=n-1)の下端の直後に、トークン数によらず一定の間隔で漢字行を置く。
        let gridBottomSK = rowTopSK(n - 1) - rowHeight
        // 漢字ボックスは黄色いボックスより一回り大きい正方形。列の中心X座標は変えない。
        let kanjiBoxSize = rowHeight * BoardLayout.kanjiBoxScale
        let gapAfterGrid = naturalGapAfterGrid * boxScale
        let kanjiCenterY = gridBottomSK - gapAfterGrid - kanjiBoxSize / 2
        let counterRowCenterY = size.height * (1 - BoardLayout.counterRowCenterYFraction)

        let pipeBlockOrder = blockReadingOrder(marks: gameState.marks, hyphens: gameState.hyphens)
        let pipeRows = visualRows(for: pipeBlockOrder)
        let answerBlockOrder = blockReadingOrder(marks: puzzle.answerMarks, hyphens: puzzle.answerHyphens)
        let answerRows = visualRows(for: answerBlockOrder)
        let matchedCells = matchedGridCells(pipeRows: pipeRows, answerRows: answerRows)

        addChild(makeStageHeading())
        if timeLimitEnabled {
            addChild(makeHUD())
        }
        addChild(makeGrid(tokenCount: n, colPitch: colPitch, colWidth: colWidth,
                           rowHeight: rowHeight, rowTopSK: rowTopSK, columnCenterX: columnCenterX,
                           matchedCells: matchedCells))
        addChild(makeAnswerLines(rows: answerRows, colPitch: colPitch, rowHeight: rowHeight,
                                  rowTopSK: rowTopSK, gridLeftX: gridLeftX))
        addChild(makePipe(rows: pipeRows, rowHeight: rowHeight, rowPitch: rowPitch,
                           rowTopSK: rowTopSK, gridLeftX: gridLeftX, colPitch: colPitch, colWidth: colWidth,
                           tokenCount: n))
        addChild(makeKanjiRow(kanjiBoxSize: kanjiBoxSize,
                               centerY: kanjiCenterY, columnCenterX: columnCenterX))
        addChild(makeMarkBadges(colWidth: colWidth, kanjiBoxSize: kanjiBoxSize,
                                 kanjiCenterY: kanjiCenterY, columnCenterX: columnCenterX))
        addChild(makeHyphenToggles(colWidth: colWidth, kanjiBoxSize: kanjiBoxSize,
                                    kanjiCenterY: kanjiCenterY, columnCenterX: columnCenterX))
        if showHintStock {
            addChild(makeRemainingCountRow(centerY: counterRowCenterY))
        }

        checkForClear()
    }

    /// 現在の盤面が正解と一致したかを判定し、初めて一致した瞬間だけクリア演出を再生する
    /// （doc §M5）。`readingOrder(現在の marks/hyphens) == puzzle.answerOrder` で判定する。
    /// 別解（marks文字列が違っても読み順が同じもの）でもクリアになる。
    private func checkForClear() {
        let matched = pipeMatchesAnswer()
        if matched && !hasPlayedClearAnimation {
            hasPlayedClearAnimation = true
            finishPuzzle(success: true)
        } else if !matched {
            hasPlayedClearAnimation = false
        }
    }

    /// 問題の終了処理（doc: ゲームオーバー機能）。クリア（`success == true`）と
    /// 制限時間切れによるミス（`success == false`）の両方から呼ばれる共通の出口。
    /// - クリア時: 一致セルのパルス + パイプに沿って光が走る演出（doc §M5） +
    ///   pipeflow SE を鳴らし、1.0秒後に結果パネルを表示する。
    /// - ミス時: miss SE を鳴らし、演出なしですぐ結果パネル（正解の確認用）を表示する。
    /// どちらも `onPuzzleFinished` を即座に呼び、呼び出し元（GameFlowView）がライフを
    /// 増減できるようにする。演出中〜結果パネル表示中は入力をロックする。
    private func finishPuzzle(success: Bool) {
        inputLocked = true
        dismissMenu()

        guard success else {
            AudioEngine.shared.playSE("miss")
            // onPuzzleFinished(画像取得のトリガー)とshowResultPanelを同じタイミングで
            // 呼ぶ必要がある（下のクリア分岐と同じ理由。直後のコメント参照）。
            onPuzzleFinished?(puzzle.id, false)
            showResultPanel(success: false)
            return
        }

        for box in matchedBoxNodes {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.18, duration: 0.15),
                SKAction.scale(to: 1.0, duration: 0.15),
            ])
            box.run(SKAction.repeat(pulse, count: 2))
        }

        if let path = pipePath, let startPoint = pipeStartPoint, badgeDiameter > 0 {
            let glow = SKShapeNode(circleOfRadius: badgeDiameter * 0.32)
            glow.fillColor = .white
            glow.strokeColor = .white
            glow.glowWidth = badgeDiameter * 0.25
            glow.zPosition = 50
            glow.alpha = 0
            glow.position = startPoint
            addChild(glow)

            let follow = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.6)
            let fadeIn = SKAction.fadeIn(withDuration: 0.08)
            let fadeOutDelay = SKAction.sequence([
                SKAction.wait(forDuration: 0.42),
                SKAction.fadeOut(withDuration: 0.18),
            ])
            glow.run(.sequence([
                fadeIn,
                .group([follow, fadeOutDelay]),
                .removeFromParent(),
            ]))
        }

        AudioEngine.shared.playSE("pipeflow")

        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in
                guard let self else { return }
                // onPuzzleFinishedは画像取得を非同期でトリガーする。showResultPanelが
                // resultImageNodeを作る直前に同じタイミングで呼ぶことで、画像取得が
                // 先に終わってもresultImageNodeがまだnilで更新が捨てられる、という
                // 競合を避ける（ミス時のFAILEDパネル表示で気づいた不具合。ユーザー報告:
                // 「クリア時に画像が表示されずミス時に表示される」— これは1秒待機の
                // 間にonPuzzleFinishedとshowResultPanelが分離されていたのが原因）。
                self.onPuzzleFinished?(self.puzzle.id, true)
                self.showResultPanel(success: true)
            },
        ]))
    }

    /// M6: クリア後の結果パネル（`screen_004.png` 相当）を表示する。
    /// クリア時（`success == true`）は画像・読み下し・フレーバーテキストを表示する。
    /// 画像はまだ非同期取得中の可能性があるためプレースホルダで先に表示し、
    /// 取得できたら `updateResultImage(_:)` で差し替える（doc §M6 実装メモ）。
    /// ミス時（`success == false`）は正解を見せず "FAILED" とだけ表示する（doc §M8.5）。
    /// タップ、または4秒経過で `onResultAdvance` を呼ぶ。
    private func showResultPanel(success: Bool) {
        let panelWidth = contentWidth * 0.88
        let left = contentOriginX + contentWidth * 0.06
        let centerX = left + panelWidth / 2

        let node = SKNode()
        node.zPosition = 300

        if success {
            // パネルの高さはフレーバーテキストが全部見えることを優先し、内容に合わせて
            // 可変にする（盤面を隠しても構わない。doc §M6 実装メモ参照）。
            // 幅と上端だけは盤面のグリッドに合わせた固定値（ステージ見出しの下）。
            let rowHeight = contentWidth * BoardLayout.columnWidthFraction * BoardLayout.rowHeightToColumnWidthRatio
            let rowTopY = size.height * BoardLayout.rowTop
            let topSK = size.height - (rowTopY - rowHeight * 0.3) // SpriteKit座標系（y上向き）
            let paddingTop = size.height * 0.03
            let paddingBottom = size.height * 0.035
            let imageGap = size.height * 0.03
            let kandokuGap = size.height * 0.025

            var cursorY = topSK - paddingTop

            let imageSide = panelWidth * 0.55
            let imageNode = SKSpriteNode(color: SKColor(white: 0.85, alpha: 1), size: CGSize(width: imageSide, height: imageSide))
            imageNode.position = CGPoint(x: centerX, y: cursorY - imageSide / 2)
            imageNode.zPosition = 1
            node.addChild(imageNode)
            resultImageNode = imageNode
            cursorY -= imageSide + imageGap

            let kandokuLabel = SKLabelNode(text: puzzle.kandoku)
            kandokuLabel.fontName = "HiraginoSans-W6"
            kandokuLabel.fontSize = contentWidth * 0.048
            kandokuLabel.fontColor = .black
            kandokuLabel.numberOfLines = 0
            kandokuLabel.preferredMaxLayoutWidth = panelWidth * 0.86
            kandokuLabel.verticalAlignmentMode = .top
            kandokuLabel.horizontalAlignmentMode = .center
            kandokuLabel.position = CGPoint(x: centerX, y: cursorY)
            kandokuLabel.zPosition = 1
            node.addChild(kandokuLabel)
            cursorY -= kandokuLabel.frame.height + kandokuGap

            let flavorLabel = SKLabelNode(text: puzzle.flavor)
            flavorLabel.fontName = "HiraginoSans-W3"
            flavorLabel.fontSize = contentWidth * 0.03
            flavorLabel.fontColor = SKColor.darkGray
            flavorLabel.numberOfLines = 0
            flavorLabel.preferredMaxLayoutWidth = panelWidth * 0.82
            flavorLabel.verticalAlignmentMode = .top
            flavorLabel.horizontalAlignmentMode = .center
            flavorLabel.position = CGPoint(x: centerX, y: cursorY)
            flavorLabel.zPosition = 1
            node.addChild(flavorLabel)
            cursorY -= flavorLabel.frame.height

            let bottomSK = cursorY - paddingBottom
            let panel = SKShapeNode(rect: CGRect(x: 0, y: 0, width: panelWidth, height: topSK - bottomSK), cornerRadius: contentWidth * 0.03)
            panel.position = CGPoint(x: left, y: bottomSK)
            panel.fillColor = SKColor.white.withAlphaComponent(0.85)
            panel.strokeColor = .clear
            panel.zPosition = 0
            node.addChild(panel)
        } else {
            // ミス時: "FAILED" を画面中央に表示する（doc §M8.5後 ユーザー指示）のに加え、
            // 入力を誤ったバッジ位置を赤い丸で示し、その位置の正解の記号を表示する
            // （ユーザー指示: 「FAILEDとなった場合入力位置を赤い丸にして正解を表示する」）。
            let failedLabel = SKLabelNode(text: "FAILED")
            failedLabel.fontName = "HelveticaNeue-CondensedBlack"
            failedLabel.fontSize = contentWidth * 0.13
            failedLabel.fontColor = BoardPalette.wrongInput
            failedLabel.verticalAlignmentMode = .center
            failedLabel.horizontalAlignmentMode = .center
            failedLabel.position = CGPoint(x: contentOriginX + contentWidth * 0.5, y: size.height * 0.5)
            failedLabel.zPosition = 1
            node.addChild(failedLabel)

            let paddingV = size.height * 0.05
            let panelHeight = failedLabel.frame.height + paddingV * 2
            let panel = SKShapeNode(rect: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight), cornerRadius: contentWidth * 0.03)
            panel.position = CGPoint(x: left, y: size.height * 0.5 - panelHeight / 2)
            panel.fillColor = SKColor.white.withAlphaComponent(0.85)
            panel.strokeColor = .clear
            panel.zPosition = 0
            node.addChild(panel)

            addWrongInputMarkers(to: node)
        }

        addChild(node)
        resultPanelNode = node

        run(.sequence([
            .wait(forDuration: 4.0),
            .run { [weak self] in self?.advanceFromResultPanel() },
        ]), withKey: "resultAutoAdvance")
    }

    /// ミス時、盤面上の各バッジ（漢字ごとの返り点・ハイフントグル）のうち正解と
    /// 異なる位置だけを赤い丸で囲み、その位置の正解の記号を小さく添えて表示する。
    /// バッジ自体（`makeMarkBadges`/`makeHyphenToggles` が既に描画済み）は消さず、
    /// 上から重ねて描く。`badgeCenters`/`hyphenToggleCenters` は直近の `render()` で
    /// 計算済みの盤面座標をそのまま使う。
    private func addWrongInputMarkers(to node: SKNode) {
        let ringLineWidth = max(1.5, contentWidth * 0.006)

        if badgeCenters.count == puzzle.tokenCount {
            for i in 0..<puzzle.tokenCount where gameState.marks[i] != puzzle.answerMarks[i] {
                let center = badgeCenters[i]

                let ring = SKShapeNode(circleOfRadius: badgeDiameter / 2 + ringLineWidth)
                ring.strokeColor = BoardPalette.wrongInput
                ring.lineWidth = ringLineWidth
                ring.fillColor = .clear
                ring.position = center
                ring.zPosition = 5
                node.addChild(ring)

                guard let glyph = markGlyph(puzzle.answerMarks[i]) else { continue }
                let chipRadius = badgeDiameter * 0.34
                let chip = SKShapeNode(circleOfRadius: chipRadius)
                chip.fillColor = BoardPalette.answerLine
                chip.strokeColor = .white
                chip.lineWidth = max(1, contentWidth * 0.002)
                chip.position = CGPoint(x: center.x + badgeDiameter * 0.6, y: center.y + badgeDiameter * 0.6)
                chip.zPosition = 6
                node.addChild(chip)

                let chipLabel = SKLabelNode(text: glyph)
                chipLabel.fontName = "HiraginoSans-W6"
                chipLabel.fontSize = chipRadius * 1.1
                chipLabel.fontColor = .white
                chipLabel.horizontalAlignmentMode = .center
                chipLabel.verticalAlignmentMode = .center
                chipLabel.position = CGPoint(x: chip.position.x, y: chip.position.y - chipRadius * 0.06)
                chipLabel.zPosition = 7
                node.addChild(chipLabel)
            }
        }

        guard hyphenToggleUsable, hyphenToggleCenters.count == puzzle.tokenCount - 1 else { return }
        for gapIndex in 0..<(puzzle.tokenCount - 1) where gameState.hyphens[gapIndex] != puzzle.answerHyphens[gapIndex] {
            let ring = SKShapeNode(circleOfRadius: hyphenToggleDiameter / 2 + ringLineWidth)
            ring.strokeColor = BoardPalette.wrongInput
            ring.lineWidth = ringLineWidth
            ring.fillColor = .clear
            ring.position = hyphenToggleCenters[gapIndex]
            ring.zPosition = 5
            node.addChild(ring)
        }
    }

    /// 結果パネルの画像を非同期取得後に差し替える（doc §M6 実装メモ）。
    /// game.sqlite へのアクセスは BoardScene の責務外のため、呼び出し元（RootView）が
    /// `onPuzzleFinished` をフックにして画像を取得し、これを呼ぶ。
    func updateResultImage(_ image: UIImage) {
        resultImageNode?.texture = SKTexture(image: image)
        resultImageNode?.color = .white
        resultImageNode?.colorBlendFactor = 0
    }

    private func advanceFromResultPanel() {
        removeAction(forKey: "resultAutoAdvance")
        resultPanelNode?.removeFromParent()
        resultPanelNode = nil
        resultImageNode = nil
        onResultAdvance?()
    }

    /// パイプの表示行と正解の表示行を比較し、同じ行位置で列範囲が重なっている
    /// マス目（グリッドセル）を集める（doc: 一致しているセルは黄色枠を強調表示）。
    /// 行全体の範囲が完全一致する必要はなく、その行でパイプが通っている列と
    /// 正解が示す列が重なっていれば、その重なった列だけを強調する。
    private func matchedGridCells(pipeRows: [VisualRow], answerRows: [VisualRow]) -> Set<GridCell> {
        var cells: Set<GridCell> = []
        for r in 0..<min(pipeRows.count, answerRows.count) {
            let p = pipeRows[r]
            let a = answerRows[r]
            let overlapStart = max(p.colStart, a.colStart)
            let overlapEnd = min(p.colEnd, a.colEnd)
            guard overlapStart <= overlapEnd else { continue }
            for c in overlapStart...overlapEnd {
                cells.insert(GridCell(row: r, col: c))
            }
        }
        return cells
    }

    private func makeStageHeading() -> SKNode {
        let label = SKLabelNode(text: stageHeadingOverride ?? "STAGE\(puzzle.stageX)-\(puzzle.stageY)")
        label.fontName = "HelveticaNeue-CondensedBlack"
        label.fontSize = size.height * 0.05
        label.fontColor = BoardPalette.stageHeading
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: contentOriginX + contentWidth * 0.5, y: size.height * (1 - BoardLayout.stageHeadingCenterY))
        return label
    }

    /// 残り時間（左）・ライフ（右）のボトルゲージを "STAGEX-Y" 見出しの左右に配置する
    /// （doc: ゲームオーバー機能。文字の高さに合わせたサイズで表示。ユーザー指示で
    /// 左右を入れ替え、現在は左=残り時間・右=ライフ）。
    private func makeHUD() -> SKNode {
        let container = SKNode()
        let centerY = size.height * (1 - BoardLayout.stageHeadingCenterY)
        let bottleHeight = size.height * BoardLayout.hudBottleHeightFraction

        if let time = BottleGaugeNode(displayHeight: bottleHeight) {
            time.position = CGPoint(x: contentOriginX + contentWidth * BoardLayout.hudBottleInsetXFraction, y: centerY - bottleHeight / 2)
            time.setFraction(CGFloat(currentTimeFraction))
            container.addChild(time)
            timeBottleNode = time
        }
        if let life = BottleGaugeNode(displayHeight: bottleHeight) {
            life.position = CGPoint(x: contentOriginX + contentWidth * (1 - BoardLayout.hudBottleInsetXFraction), y: centerY - bottleHeight / 2)
            life.setFraction(CGFloat(currentLifeFraction))
            container.addChild(life)
            lifeBottleNode = life
        }
        return container
    }

    private func roundedBox(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> SKShapeNode {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let node = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        return node
    }

    private func makeGrid(
        tokenCount n: Int,
        colPitch: CGFloat,
        colWidth: CGFloat,
        rowHeight: CGFloat,
        rowTopSK: (Int) -> CGFloat,
        columnCenterX: (Int) -> CGFloat,
        matchedCells: Set<GridCell>
    ) -> SKNode {
        let container = SKNode()
        let cornerRadius = colWidth * 0.18
        let normalLineWidth = max(1, contentWidth * 0.0035)
        let matchedLineWidth = normalLineWidth * 2.6

        // グリッド自体は常に N 行描く（doc §M3: 未使用行は空欄のまま）。
        for row in 0..<n {
            let y = rowTopSK(row) - rowHeight / 2
            for col in 0..<n {
                let isMatched = matchedCells.contains(GridCell(row: row, col: col))
                let box = roundedBox(width: colWidth, height: rowHeight, cornerRadius: cornerRadius)
                box.strokeColor = BoardPalette.gridBorder
                box.lineWidth = isMatched ? matchedLineWidth : normalLineWidth
                box.fillColor = .clear
                box.position = CGPoint(x: columnCenterX(col), y: y)
                if isMatched {
                    // 一致しているセルは枠を太くするだけでなく、少し発光させる
                    box.glowWidth = matchedLineWidth * 0.6
                    matchedBoxNodes.append(box)
                }
                container.addChild(box)
            }
        }
        return container
    }

    /// 正解の表示行から、マゼンタの正解ラインを描く。
    /// 各行の中心1列分弱の幅で、太く・やや下げた位置に描く。
    private func makeAnswerLines(
        rows: [VisualRow],
        colPitch: CGFloat,
        rowHeight: CGFloat,
        rowTopSK: (Int) -> CGFloat,
        gridLeftX: CGFloat
    ) -> SKNode {
        let container = SKNode()
        let lineWidth = max(1, contentWidth * 0.011)
        let inset = colPitch * 0.10
        let extraDrop = rowHeight * 0.08

        for (row, span) in rows.enumerated() {
            let xStart = gridLeftX + colPitch * CGFloat(span.colStart) + inset
            let xEnd = gridLeftX + colPitch * CGFloat(span.colEnd + 1) - inset
            let y = rowTopSK(row) - rowHeight - lineWidth * 2 - extraDrop

            let path = CGMutablePath()
            path.move(to: CGPoint(x: xStart, y: y))
            path.addLine(to: CGPoint(x: xEnd, y: y))

            let line = SKShapeNode(path: path)
            line.strokeColor = BoardPalette.answerLine
            line.lineWidth = lineWidth
            line.lineCap = .round
            container.addChild(line)
        }
        return container
    }

    /// 現在の盤面状態から水色パイプを描く。
    ///
    /// ボックスの中を通ってよいのは、同じ表示行の中で左から右へ読み進める区間だけ
    /// （`visualRows` がまとめた1行分の水平区間）。行をまたぐ移動（＝戻り・ジャンプ）は、
    /// 行と行の間の「ボックスが無い隙間」の中間の高さで水平移動することで、無関係な
    /// ボックスの中を突き抜けないようにする。斜め線は使わず、水平・垂直の線分だけを
    /// `lineJoin = .round` で丸く繋ぐことで、ストロークの太さが常に一定になる。
    private func makePipe(
        rows: [VisualRow],
        rowHeight: CGFloat,
        rowPitch: CGFloat,
        rowTopSK: (Int) -> CGFloat,
        gridLeftX: CGFloat,
        colPitch: CGFloat,
        colWidth: CGFloat,
        tokenCount: Int
    ) -> SKNode {
        guard !rows.isEmpty else { return SKNode() }

        let lineWidth = colWidth * 0.5
        let margin = contentWidth * 0.04 // 左端/右端の「画面外」の余白
        let gutterHeight = max(1, rowPitch - rowHeight)

        func rowLeftX(_ span: VisualRow) -> CGFloat { gridLeftX + colPitch * CGFloat(span.colStart) }
        func rowRightX(_ span: VisualRow) -> CGFloat { gridLeftX + colPitch * CGFloat(span.colEnd + 1) }
        func rowCenterY(_ row: Int) -> CGFloat {
            rowTopSK(row) - rowHeight / 2
        }
        /// 行 row の下端とその次の行の上端の中間（ボックスが存在しない隙間の高さ）
        func gutterY(after row: Int) -> CGFloat {
            let bottomOfRow = rowTopSK(row) - rowHeight
            let topOfNextRow = rowTopSK(row + 1)
            return (bottomOfRow + topOfNextRow) / 2
        }

        // まず経由点を素直に積み上げる（同一直線上に連続する冗長な点が混ざりうる）。
        // 各行は必ず左端→右端の全幅を通す（＝同じ行内で左から右に読み進める区間は
        // 必ずボックスの中を通る）。行をまたぐ移動は隙間を経由して迂回する。
        var points: [CGPoint] = []

        let firstSpan = rows[0]
        let firstY = rowCenterY(0)
        if firstSpan.colStart > 0 {
            let entryGutterY = rowTopSK(0) + gutterHeight / 2
            points.append(CGPoint(x: contentOriginX - margin, y: entryGutterY))
            points.append(CGPoint(x: rowLeftX(firstSpan), y: entryGutterY))
            points.append(CGPoint(x: rowLeftX(firstSpan), y: firstY))
        } else {
            points.append(CGPoint(x: contentOriginX - margin, y: firstY))
            points.append(CGPoint(x: rowLeftX(firstSpan), y: firstY))
        }
        points.append(CGPoint(x: rowRightX(firstSpan), y: firstY))

        for row in 1..<rows.count {
            let span = rows[row]
            let y = rowCenterY(row)
            let gy = gutterY(after: row - 1)
            let prevX = points[points.count - 1].x
            points.append(CGPoint(x: prevX, y: gy))              // 自分の行の下端を抜けて隙間まで降りる
            points.append(CGPoint(x: rowLeftX(span), y: gy))     // 隙間の中を水平移動（ボックスなし）
            points.append(CGPoint(x: rowLeftX(span), y: y))      // 次の行のボックスへ縦に入る
            points.append(CGPoint(x: rowRightX(span), y: y))     // 行の全幅を左から右へ通す
        }

        let lastSpan = rows[rows.count - 1]
        if lastSpan.colEnd < tokenCount - 1 {
            let exitGutterY = rowTopSK(rows.count - 1) - rowHeight - gutterHeight / 2
            points.append(CGPoint(x: rowRightX(lastSpan), y: exitGutterY))
            points.append(CGPoint(x: contentOriginX + contentWidth + margin, y: exitGutterY))
        } else {
            points.append(CGPoint(x: contentOriginX + contentWidth + margin, y: points[points.count - 1].y))
        }

        // 同一直線上に連続する冗長な経由点を取り除く。CoreGraphics のストローク生成が
        // 冗長な共線点のせいで一瞬幅がブレたように見える描画になることがあるため、
        // 実際に方向が変わる点だけを残す。
        var simplified: [CGPoint] = []
        for p in points {
            if simplified.count >= 2 {
                let a = simplified[simplified.count - 2]
                let b = simplified[simplified.count - 1]
                let collinearHorizontal = a.y == b.y && b.y == p.y
                let collinearVertical = a.x == b.x && b.x == p.x
                if collinearHorizontal || collinearVertical {
                    simplified.removeLast()
                }
            }
            if simplified.last != p {
                simplified.append(p)
            }
        }

        let path = CGMutablePath()
        path.move(to: simplified[0])
        for p in simplified.dropFirst() {
            path.addLine(to: p)
        }
        pipePath = path
        pipeStartPoint = simplified[0]

        let matched = pipeMatchesAnswer()
        let pipe = SKShapeNode(path: path)
        pipe.strokeColor = matched ? BoardPalette.pipeMatched : BoardPalette.pipeIdle
        pipe.lineWidth = lineWidth
        pipe.lineCap = .round
        pipe.lineJoin = .round
        pipe.zPosition = -1
        return pipe
    }

    /// 現在の盤面が正解と（トークン単位の読み順で）完全一致しているか。
    /// M5 のクリア判定で使う予定だが、パイプの色を変えるのにも使う。
    private func pipeMatchesAnswer() -> Bool {
        tokenReadingOrder(marks: gameState.marks, hyphens: gameState.hyphens) == puzzle.answerOrder
    }

    private func makeKanjiRow(
        kanjiBoxSize: CGFloat,
        centerY: CGFloat,
        columnCenterX: (Int) -> CGFloat
    ) -> SKNode {
        let container = SKNode()
        let cornerRadius = kanjiBoxSize * 0.18
        let lineWidth = max(1, contentWidth * 0.0035)

        for (i, token) in puzzle.tokens.enumerated() {
            // 正方形の漢字ボックス。列の中心X座標(columnCenterX)は変えず、一回り大きく描く。
            let box = roundedBox(width: kanjiBoxSize, height: kanjiBoxSize, cornerRadius: cornerRadius)
            box.strokeColor = BoardPalette.gridBorder
            box.lineWidth = lineWidth
            box.fillColor = BoardPalette.kanjiBoxFill
            box.position = CGPoint(x: columnCenterX(i), y: centerY)
            container.addChild(box)

            let label = SKLabelNode(text: String(token))
            label.fontName = "HiraginoSans-W6"
            label.fontSize = kanjiBoxSize * 0.55
            label.fontColor = BoardPalette.kanjiText
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: columnCenterX(i), y: centerY - kanjiBoxSize * 0.03)
            container.addChild(label)
        }
        return container
    }

    /// 返り点の入力位置を、対応する漢字の右下に付く「下付き文字」のバッジとして描く
    /// （独立した行ではなく、各漢字ボックスの右下角に配置する）。
    /// 漢字を隠さないよう、バッジはボックスの下・中心よりわずかに右に配置する。
    /// 数字点(一/二/三/四)は他のトークンの文字と同様、1文字ずつ個別の円で囲う。
    /// タッチダウンで選択メニューを開くため、ヒットテスト用の中心座標も記録する。
    private func makeMarkBadges(
        colWidth: CGFloat,
        kanjiBoxSize: CGFloat,
        kanjiCenterY: CGFloat,
        columnCenterX: (Int) -> CGFloat
    ) -> SKNode {
        let container = SKNode()
        // 返り点バッジの大きさは黄色いボックス（グリッドのマス目）と同じにする
        let diameter = colWidth
        let lineWidth = max(1, contentWidth * 0.0035)
        // 漢字ボックスの下、漢字の中心よりわずかに右に配置し、文字にかからない
        // ようにする。右端の列でタップしづらくならない程度の控えめな量にする。
        let badgeOffsetX = diameter * 0.25
        let badgeOffsetY = -kanjiBoxSize / 2 - diameter * 0.16

        badgeDiameter = diameter
        var centers: [CGPoint] = []

        for i in 0..<puzzle.tokenCount {
            let mark = gameState.marks[i]
            let badgeCenter = CGPoint(
                x: columnCenterX(i) + badgeOffsetX,
                y: kanjiCenterY + badgeOffsetY
            )
            centers.append(badgeCenter)

            let circle = SKShapeNode(circleOfRadius: diameter / 2)
            circle.strokeColor = BoardPalette.gridBorder
            circle.lineWidth = lineWidth
            circle.fillColor = mark == .none ? BoardPalette.markSlotEmptyFill : BoardPalette.markSlotFilledFill
            circle.position = badgeCenter
            circle.zPosition = 1
            container.addChild(circle)

            if let glyph = markGlyph(mark) {
                let label = SKLabelNode(text: glyph)
                label.fontName = "HiraginoSans-W6"
                label.fontSize = diameter * 0.52
                label.fontColor = BoardPalette.markSlotFilledText
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: badgeCenter.x, y: badgeCenter.y - diameter * 0.03)
                label.zPosition = 2
                container.addChild(label)
            }
        }
        badgeCenters = centers
        return container
    }

    /// ハイフンのトグル（スロットの左側の小さな円）。この問題がハイフンを使う場合のみ表示する。
    /// スロット i の左のトグルは「トークン i-1 と i の間」を意味する（doc §M4）。
    /// タップで即座にオン/オフする（ドラッグメニューは不要）。
    private func makeHyphenToggles(
        colWidth: CGFloat,
        kanjiBoxSize: CGFloat,
        kanjiCenterY: CGFloat,
        columnCenterX: (Int) -> CGFloat
    ) -> SKNode {
        let container = SKNode()
        hyphenToggleUsable = puzzle.answerHyphens.contains(true)
        guard hyphenToggleUsable, badgeCenters.count == puzzle.tokenCount else {
            hyphenToggleCenters = []
            return container
        }

        let diameter = colWidth * 0.6
        hyphenToggleDiameter = diameter
        let lineWidth = max(1, contentWidth * 0.003)
        var centers: [CGPoint] = []

        for gapIndex in 0..<(puzzle.tokenCount - 1) {
            // gapIndex はトークン gapIndex と gapIndex+1 の間。トグルはスロット(gapIndex+1)の
            // 左に置く。
            let rightBadge = badgeCenters[gapIndex + 1]
            let center = CGPoint(x: rightBadge.x - badgeDiameter * 0.85, y: rightBadge.y)
            centers.append(center)

            let isOn = gameState.hyphens[gapIndex]
            let circle = SKShapeNode(circleOfRadius: diameter / 2)
            circle.strokeColor = BoardPalette.menuItemEnabled
            circle.lineWidth = lineWidth
            circle.fillColor = isOn ? BoardPalette.menuCapsule : .clear
            circle.position = center
            circle.zPosition = 1
            container.addChild(circle)

            if isOn {
                let label = SKLabelNode(text: "｜")
                label.fontName = "HiraginoSans-W6"
                label.fontSize = diameter * 0.7
                label.fontColor = BoardPalette.stageHeading
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: center.x, y: center.y - diameter * 0.03)
                label.zPosition = 2
                container.addChild(label)
            }
        }
        hyphenToggleCenters = centers
        return container
    }

    /// レ点・ハイフン・数字点の残り個数表示（doc §M3-7）。
    /// この問題で実際に使う種類だけを表示する（使わない種類は出さない）。
    /// 残数 = 正解に必要な個数 - 現在の盤面に置かれている個数。
    /// レ点・ハイフンは1個1個数える。
    /// **数字点（一・二・三・四）はそれぞれ独立したカウンタとして表示する**
    /// （一・二・三をまとめて1つの「×N」で表示すると、そのうちどれか1つを
    /// 置いただけで残り全部が尽きたように見えてユーザーが混乱するため、
    /// `(一)×1 (二)×1` のように記号ごとに分けて数える）。
    /// ハイフンは「一」と紛らわしい（どちらも横線1本に見える）ため、専用の記号
    /// "｜" で表示して区別する。
    private func makeRemainingCountRow(centerY: CGFloat) -> SKNode {
        let container = SKNode()
        let answerReCount = puzzle.answerMarks.filter { $0 == .re }.count
        let answerHyphenCount = puzzle.answerHyphens.filter { $0 }.count
        let placedReCount = gameState.marks.filter { $0 == .re }.count
        let placedHyphenCount = gameState.hyphens.filter { $0 }.count

        let remainingRe = max(0, answerReCount - placedReCount)
        let remainingHyphen = max(0, answerHyphenCount - placedHyphenCount)

        // 実際にこの問題で使う種類だけを集める
        var counters: [(glyphs: [String], count: Int)] = []
        if answerReCount > 0 {
            counters.append((["レ"], remainingRe))
        }
        let levelMarks: [(Mark, String)] = [(.ichi, "一"), (.ni, "二"), (.san, "三"), (.yon, "四")]
        for (mark, glyph) in levelMarks.prefix(puzzle.maxLevel) {
            let need = puzzle.answerMarks.filter { $0 == mark }.count
            guard need > 0 else { continue }
            let placed = gameState.marks.filter { $0 == mark }.count
            counters.append(([glyph], max(0, need - placed)))
        }
        if answerHyphenCount > 0 {
            counters.append((["｜"], remainingHyphen))
        }

        let fontSize = size.height * 0.032
        let circleRadius = fontSize * 0.6
        let circlePitch = circleRadius * 2.1

        // glyphs の各文字を、それぞれ個別の円で囲って横に並べる
        // （例: 数字点は「一」「二」をそれぞれ別の円に入れる。「一二」を1つの円に
        // まとめない）。
        func makeCounter(glyphs: [String], count: Int, x: CGFloat) -> SKNode {
            let node = SKNode()
            let groupWidth = CGFloat(glyphs.count - 1) * circlePitch
            for (i, glyph) in glyphs.enumerated() {
                let cx = CGFloat(i) * circlePitch - groupWidth / 2

                let circle = SKShapeNode(circleOfRadius: circleRadius)
                circle.strokeColor = BoardPalette.stageHeading
                circle.lineWidth = max(1, contentWidth * 0.003)
                circle.fillColor = .clear
                circle.position = CGPoint(x: cx, y: 0)
                node.addChild(circle)

                let glyphLabel = SKLabelNode(text: glyph)
                glyphLabel.fontName = "HiraginoSans-W6"
                glyphLabel.fontSize = fontSize * 0.9
                glyphLabel.fontColor = BoardPalette.stageHeading
                glyphLabel.horizontalAlignmentMode = .center
                glyphLabel.verticalAlignmentMode = .center
                glyphLabel.position = CGPoint(x: cx, y: -fontSize * 0.05)
                node.addChild(glyphLabel)
            }

            let countLabel = SKLabelNode(text: "×\(count)")
            countLabel.fontName = "HelveticaNeue-CondensedBold"
            countLabel.fontSize = fontSize
            countLabel.fontColor = BoardPalette.stageHeading
            countLabel.horizontalAlignmentMode = .left
            countLabel.verticalAlignmentMode = .center
            countLabel.position = CGPoint(x: groupWidth / 2 + circleRadius * 1.5, y: -fontSize * 0.05)
            node.addChild(countLabel)

            node.position = CGPoint(x: x, y: centerY)
            return node
        }

        // 各カウンタの実際の幅（丸の数で変わる）を考慮して、重ならないように
        // 一定の間隔を空けながら横に並べ、その並び全体を画面中央に置く。
        // （等間隔に中心を置くだけだと、丸が複数並ぶ広いカウンタが隣と重なる）
        let n = counters.count
        guard n > 0 else { return container }
        let labelWidthEstimate = fontSize * 1.5 // "×N" の概算幅
        let interCounterGap = fontSize * 1.0

        func halfWidths(_ glyphCount: Int) -> (left: CGFloat, right: CGFloat) {
            let groupWidth = CGFloat(glyphCount - 1) * circlePitch
            let left = groupWidth / 2 + circleRadius
            let right = groupWidth / 2 + circleRadius * 1.5 + labelWidthEstimate
            return (left, right)
        }

        let widths = counters.map { halfWidths($0.glyphs.count) }
        let totalWidth = widths.reduce(CGFloat(0)) { $0 + $1.left + $1.right }
            + interCounterGap * CGFloat(n - 1)

        var cursor = contentOriginX + contentWidth / 2 - totalWidth / 2
        for (i, counter) in counters.enumerated() {
            let x = cursor + widths[i].left
            container.addChild(makeCounter(glyphs: counter.glyphs, count: counter.count, x: x))
            cursor = x + widths[i].right + interCounterGap
        }
        return container
    }

    private func markGlyph(_ mark: Mark) -> String? {
        switch mark {
        case .none: return nil
        case .re: return "レ"
        case .ichi: return "一"
        case .ni: return "二"
        case .san: return "三"
        case .yon: return "四"
        }
    }

    // MARK: - タッチ入力（doc §M4）

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if resultPanelNode != nil {
            advanceFromResultPanel()
            return
        }
        guard !inputLocked else { return }
        guard let touch = touches.first else { return }
        dismissMenu()
        let point = touch.location(in: self)

        if let tokenIndex = hitTestBadge(point) {
            beginMarkMenu(for: tokenIndex)
            updateMenuHighlight(point)
            return
        }
        if let gapIndex = hitTestHyphenToggle(point) {
            if gameState.toggleHyphen(at: gapIndex) {
                render()
                onBoardChanged?()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first, activeMenu != nil else { return }
        updateMenuHighlight(touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first, activeMenu != nil else { return }
        updateMenuHighlight(touch.location(in: self))
        commitMenuSelection()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        dismissMenu()
    }

    private func hitTestBadge(_ point: CGPoint) -> Int? {
        guard badgeDiameter > 0 else { return nil }
        let tolerance = badgeDiameter * 0.65 // 半径よりやや広めに当たり判定を取る
        for (i, center) in badgeCenters.enumerated() {
            if hypot(point.x - center.x, point.y - center.y) <= tolerance {
                return i
            }
        }
        return nil
    }

    private func hitTestHyphenToggle(_ point: CGPoint) -> Int? {
        guard hyphenToggleUsable, hyphenToggleDiameter > 0 else { return nil }
        let tolerance = hyphenToggleDiameter * 0.75
        for (i, center) in hyphenToggleCenters.enumerated() {
            if hypot(point.x - center.x, point.y - center.y) <= tolerance {
                return i
            }
        }
        return nil
    }

    /// その問題で実際に使う記号だけを、スロットに近い順（下から上）に並べる。
    /// options[0] は常に .none（×＝削除）。
    private func menuOptions() -> [Mark] {
        var options: [Mark] = [.none]
        if puzzle.answerMarks.contains(.re) {
            options.append(.re)
        }
        let numberedInOrder: [Mark] = [.ichi, .ni, .san, .yon]
        if puzzle.maxLevel >= 2 {
            options.append(contentsOf: numberedInOrder.prefix(puzzle.maxLevel))
        }
        return options
    }

    private func beginMarkMenu(for tokenIndex: Int) {
        let options = menuOptions()
        let slotCenter = badgeCenters[tokenIndex]

        // 返り点選択パネルが小さくタップしても反応しづらいという指摘を受け、縦横とも
        // 1.5倍に拡大する（ユーザー指示）。下端の位置は拡大前と同じに揃えるため、
        // 元の下端位置を先に求めてから、そこを基準に拡大後の項目位置を積み上げる。
        let menuScale: CGFloat = 1.5
        let scaledDiameter = badgeDiameter * menuScale
        let itemRadius = scaledDiameter / 2
        let itemSpacing = scaledDiameter * 1.25

        let originalBottomY = slotCenter.y - badgeDiameter * 0.65
        let firstItemY = originalBottomY + itemRadius + scaledDiameter * 0.15

        var itemCenters: [CGPoint] = []
        for i in 0..<options.count {
            itemCenters.append(CGPoint(x: slotCenter.x, y: firstItemY + itemSpacing * CGFloat(i)))
        }

        let menuNode = SKNode()
        menuNode.zPosition = 100

        // 半透明シアンのカプセル背景
        let capsuleHeight = (itemCenters.last!.y - itemCenters.first!.y) + itemRadius * 2 + scaledDiameter * 0.3
        let capsuleWidth = scaledDiameter * 1.5
        let capsuleRect = CGRect(
            x: slotCenter.x - capsuleWidth / 2,
            y: itemCenters.first!.y - itemRadius - scaledDiameter * 0.15,
            width: capsuleWidth,
            height: capsuleHeight
        )
        let capsule = SKShapeNode(rect: capsuleRect, cornerRadius: capsuleWidth / 2)
        capsule.fillColor = BoardPalette.menuCapsule
        capsule.strokeColor = .clear
        capsule.zPosition = 0
        menuNode.addChild(capsule)

        var circleNodes: [SKShapeNode] = []
        var labelNodes: [SKLabelNode] = []
        for (i, option) in options.enumerated() {
            let enabled = gameState.canPlace(option, at: tokenIndex)
            let circle = SKShapeNode(circleOfRadius: itemRadius)
            circle.position = itemCenters[i]
            circle.lineWidth = max(1, contentWidth * 0.003)
            circle.strokeColor = enabled ? BoardPalette.menuItemEnabled : BoardPalette.menuItemDisabled
            circle.fillColor = .clear
            circle.zPosition = 1
            menuNode.addChild(circle)
            circleNodes.append(circle)

            let label = SKLabelNode(text: option == .none ? "×" : (markGlyph(option) ?? ""))
            label.fontName = "HiraginoSans-W6"
            label.fontSize = itemRadius * 1.1
            label.fontColor = BoardPalette.menuItemText
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: itemCenters[i].x, y: itemCenters[i].y - itemRadius * 0.05)
            label.zPosition = 2
            menuNode.addChild(label)
            labelNodes.append(label)
        }

        addChild(menuNode)
        activeMenu = ActiveMarkMenu(
            tokenIndex: tokenIndex,
            options: options,
            itemCenters: itemCenters,
            itemRadius: itemRadius,
            node: menuNode,
            circleNodes: circleNodes,
            labelNodes: labelNodes,
            highlightedIndex: nil
        )
    }

    private func updateMenuHighlight(_ point: CGPoint) {
        guard var menu = activeMenu else { return }
        let tolerance = menu.itemRadius * 1.1
        var newHighlight: Int?
        for (i, center) in menu.itemCenters.enumerated() {
            if hypot(point.x - center.x, point.y - center.y) <= tolerance {
                newHighlight = i
                break
            }
        }
        guard newHighlight != menu.highlightedIndex else { return }

        for i in 0..<menu.options.count {
            let enabled = gameState.canPlace(menu.options[i], at: menu.tokenIndex)
            let isHighlighted = (i == newHighlight) && enabled
            let baseColor = enabled ? BoardPalette.menuItemEnabled : BoardPalette.menuItemDisabled
            menu.circleNodes[i].fillColor = isHighlighted ? BoardPalette.menuItemHighlighted.withAlphaComponent(0.3) : .clear
            menu.circleNodes[i].strokeColor = isHighlighted ? BoardPalette.menuItemHighlighted : baseColor
            menu.labelNodes[i].fontColor = BoardPalette.menuItemText
            menu.circleNodes[i].setScale(isHighlighted ? 1.15 : 1.0)
        }
        menu.highlightedIndex = newHighlight
        activeMenu = menu
    }

    private func commitMenuSelection() {
        guard let menu = activeMenu else { return }
        defer { dismissMenu() }
        guard let highlighted = menu.highlightedIndex else { return } // メニュー外でリリース＝キャンセル
        let option = menu.options[highlighted]
        guard gameState.canPlace(option, at: menu.tokenIndex) else { return }
        if gameState.setMark(option, at: menu.tokenIndex) {
            AudioEngine.shared.playSE("button_click_01")
            render()
            onBoardChanged?()
        }
    }

    private func dismissMenu() {
        activeMenu?.node.removeFromParent()
        activeMenu = nil
    }
}
