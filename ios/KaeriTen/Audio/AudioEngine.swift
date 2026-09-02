import AVFoundation
import UIKit

/// M8: BGM・SEを管理するシングルトン（doc §M8）。
/// - BGMは2系統のプレイヤーを切り替えながらループ再生し、曲を変えるときは
///   0.5秒でクロスフェードする。
/// - SEは音ごとにプレイヤーを数個プールし、同時多重再生できるようにする
///   （AVAudioPlayerは再生中のファイルを差し替えられないため、同じ音用に
///   複数インスタンスを使い回す設計にした）。
/// - `.ambient` カテゴリを使うため、他アプリの音楽再生を止めない。
final class AudioEngine {
    static let shared = AudioEngine()

    // MARK: - BGM

    private var bgmPlayers: [AVAudioPlayer?] = [nil, nil]
    private var activeBGMSlot = 0
    private var currentBGMName: String?
    private var fadeTimer: Timer?
    /// バックグラウンド復帰時に再開するため、一時停止したBGMを覚えておく。
    private var wasPlayingBeforeBackground = false
    /// 現在再生中の曲固有の音量倍率（`BGMTrack.volumeMultiplier(for:)`）。
    /// `bgmVolume`（ユーザー設定）に掛け合わせて実際の再生音量にする。
    private var currentBGMVolumeMultiplier: Float = 1.0

    var bgmVolume: Float = 0.7 {
        didSet { bgmPlayers[activeBGMSlot]?.volume = bgmVolume * currentBGMVolumeMultiplier }
    }

    // MARK: - SE

    private var sePlayerPools: [String: [AVAudioPlayer]] = [:]
    private let sePoolSizePerSound = 3

    var seVolume: Float = 0.7

    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 音が鳴らないだけでゲーム進行には影響しないため、ここでは無視する。
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    // MARK: - BGM 再生

    /// 指定した曲（拡張子なしファイル名）をループ再生する。既に同じ曲がかかっていれば何もしない。
    func playBGM(_ name: String, crossfadeDuration: TimeInterval = 0.5) {
        guard currentBGMName != name else { return }
        guard let url = resourceURL(name: name, ext: "mp3", subdirectory: "bgm") else { return }
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }

        currentBGMName = name
        let oldVolumeMultiplier = currentBGMVolumeMultiplier
        let newVolumeMultiplier = BGMTrack.volumeMultiplier(for: name)
        currentBGMVolumeMultiplier = newVolumeMultiplier

        newPlayer.numberOfLoops = -1
        newPlayer.volume = crossfadeDuration > 0 ? 0 : bgmVolume * newVolumeMultiplier
        newPlayer.prepareToPlay()
        newPlayer.play()

        let oldSlot = activeBGMSlot
        let newSlot = 1 - activeBGMSlot
        let oldPlayer = bgmPlayers[oldSlot]
        bgmPlayers[newSlot] = newPlayer
        activeBGMSlot = newSlot

        fadeTimer?.invalidate()
        guard crossfadeDuration > 0 else {
            oldPlayer?.stop()
            bgmPlayers[oldSlot] = nil
            return
        }

        let steps = 20
        let stepInterval = crossfadeDuration / Double(steps)
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            newPlayer.volume = self.bgmVolume * newVolumeMultiplier * progress
            oldPlayer?.volume = self.bgmVolume * oldVolumeMultiplier * (1 - progress)
            if currentStep >= steps {
                timer.invalidate()
                oldPlayer?.stop()
                self.bgmPlayers[oldSlot] = nil
            }
        }
    }

    func stopBGM() {
        fadeTimer?.invalidate()
        bgmPlayers[0]?.stop()
        bgmPlayers[1]?.stop()
        currentBGMName = nil
    }

    @objc private func handleDidEnterBackground() {
        wasPlayingBeforeBackground = bgmPlayers[activeBGMSlot]?.isPlaying ?? false
        bgmPlayers[activeBGMSlot]?.pause()
    }

    @objc private func handleWillEnterForeground() {
        guard wasPlayingBeforeBackground else { return }
        bgmPlayers[activeBGMSlot]?.play()
    }

    // MARK: - SE 再生

    /// 指定した効果音（拡張子なしファイル名）を鳴らす。同じ音が既に再生中でも
    /// プールされた別インスタンスで重ねて再生できる。
    func playSE(_ name: String) {
        var pool = sePlayerPools[name] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) {
            idle.volume = seVolume
            idle.currentTime = 0
            idle.play()
            return
        }
        guard pool.count < sePoolSizePerSound,
              let url = resourceURL(name: name, ext: "mp3", subdirectory: "se"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = seVolume
        player.prepareToPlay()
        player.play()
        pool.append(player)
        sePlayerPools[name] = pool
    }

    // MARK: - リソース解決

    /// xcodegen/Xcodeのリソードコピー設定によってサブディレクトリ構成が保たれない
    /// 場合があるため、subdirectory指定ありで見つからなければフラットな配置でも探す。
    private func resourceURL(name: String, ext: String, subdirectory: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }
}
