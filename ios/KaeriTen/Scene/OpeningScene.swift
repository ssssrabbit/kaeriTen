import SpriteKit
import UIKit

/// タイトル画面のオープニング（ユーザー指示: 「オープニングではアプリアイコンが返点と
/// 黄色いボックスからモーショングラフィックスで構成されるようにする」）。
/// `resource/images/title_00`〜`title_07`（初期配置）から切り出した8個の部品テクスチャ
/// （`Resources/opening/e0`〜`e6`・`e7_big`・`e7_small`）を、`title_10`〜`title_17`
/// （最終配置＝実際のアプリアイコンと一致）との差分ぶんだけ動かして組み上げる。
///
/// 各部品の位置・角度は、元画像（1024×1024、y下向き）をPCA解析して実測した値を
/// SpriteKitのy上向き座標系に変換したもの（詳細はコミットログ参照）。黄色いボックス
/// （e7）だけは「線幅を変えずにサイズ縮小」という指示のため、単純な拡大縮小ではなく
/// 大小2枚のテクスチャをクロスフェードすることで線の太さの破綻を避けている。
final class OpeningScene: SKScene {
    private struct ElementSpec {
        let textureName: String
        /// 部品テクスチャ自身の自然サイズ（元画像px、切り出し済みテクスチャの実寸）。
        let size: CGSize
        /// 開始位置・終了位置（元画像1024空間の座標、y下向き）。
        let startImg: CGPoint
        let endImg: CGPoint
        /// 終了角度（度）。SpriteKit座標系（反時計回りが正）。0なら回転しない。
        let endAngleDegrees: CGFloat
        /// 動き始めるタイミング（秒）。部品ごとに少しずらして組み上がる感じを出す。
        let delay: TimeInterval
    }

    private static let canvasSize: CGFloat = 1024
    private static let moveDuration: TimeInterval = 1.05

    /// title_00〜title_06 → title_10〜title_16（返り点・数字点のストローク）。
    private static let strokeElements: [ElementSpec] = [
        ElementSpec(textureName: "e0", size: CGSize(width: 170, height: 194),
                    startImg: CGPoint(x: 392.0, y: 539.0), endImg: CGPoint(x: 401.5, y: 520.5),
                    endAngleDegrees: 0, delay: 0.0), // e0は回転を別扱いするためここでは0
        ElementSpec(textureName: "e1", size: CGSize(width: 200, height: 58),
                    startImg: CGPoint(x: 308.0, y: 972.0), endImg: CGPoint(x: 522.5, y: 475.0),
                    endAngleDegrees: 143.0, delay: 0.04),
        ElementSpec(textureName: "e2", size: CGSize(width: 157, height: 57),
                    startImg: CGPoint(x: 312.5, y: 687.5), endImg: CGPoint(x: 494.0, y: 681.5),
                    endAngleDegrees: -67.0, delay: 0.08),
        ElementSpec(textureName: "e3", size: CGSize(width: 209, height: 57),
                    startImg: CGPoint(x: 312.5, y: 763.5), endImg: CGPoint(x: 586.0, y: 645.5),
                    endAngleDegrees: -47.6, delay: 0.12),
        ElementSpec(textureName: "e4", size: CGSize(width: 157, height: 58),
                    startImg: CGPoint(x: 312.5, y: 379.0), endImg: CGPoint(x: 619.5, y: 365.0),
                    endAngleDegrees: 0, delay: 0.16),
        ElementSpec(textureName: "e5", size: CGSize(width: 135, height: 58),
                    startImg: CGPoint(x: 312.5, y: 433.0), endImg: CGPoint(x: 631.0, y: 427.0),
                    endAngleDegrees: 0, delay: 0.20),
        ElementSpec(textureName: "e6", size: CGSize(width: 191, height: 58),
                    startImg: CGPoint(x: 312.5, y: 487.0), endImg: CGPoint(x: 669.5, y: 484.0),
                    endAngleDegrees: 0, delay: 0.24),
    ]

    /// title_00 → title_10（レ点本体）。「その場で最後に素早く回転、オーバーシュートして
    /// 戻る」ため、位置は他と同じイーズアウトで動かしつつ、回転だけ最後に別枠で行う。
    private static let reMarkStart = CGPoint(x: 392.0, y: 539.0)
    private static let reMarkEnd = CGPoint(x: 401.5, y: 520.5)
    private static let reMarkSize = CGSize(width: 170, height: 194)
    private static let reMarkFinalAngle: CGFloat = -161.0
    private static let reMarkOvershootAngle: CGFloat = -186.0

    /// title_07 → title_17（黄色いボックス）。
    private static let boxStartSize = CGSize(width: 569, height: 587)
    private static let boxStartPos = CGPoint(x: 511.5, y: 520.5)
    private static let boxEndSize = CGSize(width: 160, height: 160)
    private static let boxEndPos = CGPoint(x: 423.0, y: 362.0)

    private var hasPlayed = false

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .clear
    }

    /// `Resources/opening/` 配下のPNGは、ビルド時にサブディレクトリを保持せずバンドル
    /// 直下に展開される（`BottleGaugeNode.loadImage` と同じ実測結果。§Scene/BoardScene.swift）。
    /// 念のため `subdirectory` 指定も試した上で、直下も探すフォールバックにする。
    private static func loadTexture(named name: String) -> SKTexture {
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "opening")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url, let image = UIImage(contentsOfFile: url.path) else {
            return SKTexture()
        }
        return SKTexture(image: image)
    }

    /// オープニングを1回だけ再生する。完了したら `completion` を呼ぶ。
    /// `size` がまだ確定していない場合は何もしない（呼び出し側は `SpriteView` の
    /// `onAppear` で `size` を設定した後に呼ぶこと）。
    func play(completion: @escaping () -> Void) {
        guard !hasPlayed, size.width > 0, size.height > 0 else { return }
        hasPlayed = true
        removeAllChildren()

        let displaySize = min(size.width, size.height) * 0.62
        let scale = displaySize / Self.canvasSize
        let iconCenter = CGPoint(x: size.width / 2, y: size.height * 0.76)

        func convert(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: iconCenter.x + (p.x - Self.canvasSize / 2) * scale,
                y: iconCenter.y - (p.y - Self.canvasSize / 2) * scale
            )
        }

        addBox(convert: convert, scale: scale)
        for spec in Self.strokeElements where spec.textureName != "e0" {
            addStroke(spec, convert: convert, scale: scale)
        }
        addReMark(convert: convert, scale: scale)

        let totalDuration = Self.moveDuration + 0.24 + 0.4 // 最後のストロークの遅延+移動 と レ点スナップの余裕
        run(.sequence([.wait(forDuration: totalDuration), .run(completion)]))
    }

    private func addBox(convert: (CGPoint) -> CGPoint, scale: CGFloat) {
        // 線幅を保つため、拡大縮小ではなく大小2枚のテクスチャをクロスフェードする
        // （ユーザー指示: 「イーズアウトで線幅を変えずにサイズ縮小」）。
        let bigBox = SKSpriteNode(texture: Self.loadTexture(named: "e7_big"))
        bigBox.size = CGSize(width: Self.boxStartSize.width * scale, height: Self.boxStartSize.height * scale)
        bigBox.position = convert(Self.boxStartPos)
        bigBox.zPosition = 0
        addChild(bigBox)

        let smallBox = SKSpriteNode(texture: Self.loadTexture(named: "e7_small"))
        smallBox.size = CGSize(width: Self.boxEndSize.width * scale, height: Self.boxEndSize.height * scale)
        smallBox.position = convert(Self.boxEndPos)
        smallBox.alpha = 0
        smallBox.zPosition = 1
        addChild(smallBox)

        let fadeOut = SKAction.fadeOut(withDuration: Self.moveDuration)
        fadeOut.timingMode = .easeOut
        let fadeIn = SKAction.fadeIn(withDuration: Self.moveDuration)
        fadeIn.timingMode = .easeOut
        bigBox.run(fadeOut)
        smallBox.run(fadeIn)
    }

    private func addStroke(_ spec: ElementSpec, convert: (CGPoint) -> CGPoint, scale: CGFloat) {
        let node = SKSpriteNode(texture: Self.loadTexture(named: spec.textureName))
        node.size = CGSize(width: spec.size.width * scale, height: spec.size.height * scale)
        node.position = convert(spec.startImg)
        node.zRotation = 0
        node.zPosition = 2
        addChild(node)

        let move = SKAction.move(to: convert(spec.endImg), duration: Self.moveDuration)
        move.timingMode = .easeOut
        var actions: [SKAction] = [move]
        if spec.endAngleDegrees != 0 {
            let rotate = SKAction.rotate(toAngle: spec.endAngleDegrees * .pi / 180, duration: Self.moveDuration, shortestUnitArc: false)
            rotate.timingMode = .easeOut
            actions = [.group([move, rotate])]
        }
        node.run(.sequence([.wait(forDuration: spec.delay), .group(actions)]))
    }

    private func addReMark(convert: (CGPoint) -> CGPoint, scale: CGFloat) {
        let node = SKSpriteNode(texture: Self.loadTexture(named: "e0"))
        node.size = CGSize(width: Self.reMarkSize.width * scale, height: Self.reMarkSize.height * scale)
        node.position = convert(Self.reMarkStart)
        node.zRotation = 0
        node.zPosition = 3
        addChild(node)

        let move = SKAction.move(to: convert(Self.reMarkEnd), duration: Self.moveDuration)
        move.timingMode = .easeOut

        let overshoot = SKAction.rotate(toAngle: Self.reMarkOvershootAngle * .pi / 180, duration: 0.16, shortestUnitArc: false)
        overshoot.timingMode = .easeOut
        let settle = SKAction.rotate(toAngle: Self.reMarkFinalAngle * .pi / 180, duration: 0.16, shortestUnitArc: false)
        settle.timingMode = .easeInEaseOut
        let snap = SKAction.sequence([overshoot, settle])

        node.run(.sequence([
            move,
            .wait(forDuration: 0.08),
            snap,
        ]))
    }
}
