# Game Center 実績の実装と登録手順

kaeriTen には Game Center の実績（Achievements）機能を実装済み。実績の解除条件はアプリの
ローカル進捗（`Progress`）だけから判定できるため、Game Centerにサインインしていない
状態でプレイしても進捗自体は正しく積み上がり、サインインした時点で未報告分がまとめて
Game Centerへ報告される。

## 実装済みのコード

| ファイル | 役割 |
|---|---|
| `ios/KaeriTen/GameCenter/AchievementCatalog.swift` | 実績6種の定義（ID・条件判定） |
| `ios/KaeriTen/GameCenter/AchievementManager.swift` | Game Centerサインイン・実績報告 |
| `ios/KaeriTen/State/Progress.swift` | 判定に使う進捗データ（`perfectClearCounts`・`missClearCounts`・`totalPuzzlesCleared`・`unlockedAchievements`） |
| `ios/KaeriTen/KaeriTen.entitlements` | Game Center capability（`com.apple.developer.game-center`） |

`AchievementManager.authenticate()` はアプリ起動時（`TitleView`）に1回呼ばれる。
`AchievementManager.evaluate(_:)` は問題を1問クリアするたび（`GameFlowView`）・
ステージを1回クリアするたび（同）に呼ばれ、新たに条件を満たした実績があれば
`GKAchievement.report(_:)` でGame Centerへ送信する。

## 実績一覧（App Store Connectで作成する識別子と一致させること）

| 識別子（Achievement ID） | 表示名の例 | 条件 |
|---|---|---|
| `de.opqrco.kaeriten.achievement.firstClear` | 最初のクリア | いずれかのステージを1回クリアする |
| `de.opqrco.kaeriten.achievement.allRounds123` | 全ラウンド制覇 | STAGE1・2・3の全10ラウンド（STAGE1-3〜1-6、2-3〜2-6、3-5〜3-6）をそれぞれ1回以上クリアする（STAGE4は対象外） |
| `de.opqrco.kaeriten.achievement.firstPerfect` | 最初のパーフェクト | いずれかのステージをノーミス（ライフ満タンのまま）でクリアする |
| `de.opqrco.kaeriten.achievement.fullComplete` | フルコンプリート | STAGE1〜4の全11ステージで、それぞれ合計6回クリア（パーフェクト+ミスあり）を達成する |
| `de.opqrco.kaeriten.achievement.clear100` | 百戦錬磨 | 通算100問クリアする |
| `de.opqrco.kaeriten.achievement.clear1000` | 千本ノック | 通算1000問クリアする |

表示名・説明文はApp Store Connect側で自由に決めてよい（コード側は識別子としか比較しない）。
上表の「表示名の例」はそのまま使ってもよいし変更してもよい。

## App Store Connectでの登録手順

1. [App Store Connect](https://appstoreconnect.apple.com/) にログインし、対象アプリ（kaeriTen）を開く。
2. 左メニューの **機能（Features）** → **Game Center** を選択する。
   - まだ「Game Centerを有効にする」ボタンが出ている場合はクリックして有効化する
     （Xcode側の Game Center capability・entitlements は本リポジトリで設定済み）。
3. **実績（Achievements）** セクションの「+」ボタンで新規実績を1つ作成する。
   - **参照名（Reference Name）**: 開発者用のメモ名（例: 「最初のクリア」）。ユーザーには見えない。
   - **識別子（Achievement ID）**: 上表の識別子をそのまま入力する（コードの `AchievementCatalog` と
     完全一致していないと報告が届かない）。
   - **ポイント（Points）**: 実績合計が100になるよう配分する（例: 6個なら 10/15/15/20/20/20 など）。
   - **非表示（Hidden）**: 「最初のクリア」のような基本実績は表示、
     「フルコンプリート」のようなやり込み実績は非表示にする、など好みで設定してよい。
   - **繰り返し可能（Repeatable）**: いずれも「いいえ」でよい（コード側も一度きりの解除しか行わない）。
   - 各言語ごとに **表示名** と **達成前・達成後の説明文** を入力する（日本語ロケールは必須）。
   - **画像**: 1024×1024pxのバッジ画像をアップロードする（用意していなければ後回しにしてもよいが、
     審査には必要）。
4. 上記を6つの実績すべてについて繰り返す。
5. 保存後、**アプリ内課金や実績はApp Storeに送信するバージョンと一緒に審査される**ため、
   次回のビルド提出時に実績の設定もあわせて送信されるようApp Store Connect上で
   「提出準備完了」の状態にしておく。

## 動作確認（サンドボックス）

- 実機・シミュレータともに、**サンドボックスのGame Centerアカウント**でサインインしていないと
  実績は報告されない（本番のGame Centerアカウントとは別に用意する）。
- 実機: 設定アプリ → Game Center からサンドボックスアカウントでサインインする。
- シミュレータ: アプリ起動時に表示されるGame Centerのサインインダイアログからサインインする
  （初回はSafariでサンドボックス用Apple IDの認証が必要になることがある）。
- サインイン後にプレイすると、`AchievementManager.evaluate(_:)` が呼ばれるタイミング
  （問題クリア・ステージクリア）で条件を満たした実績が報告され、画面上部にバナーが表示される
  （`showsCompletionBanner = true` を設定済み）。
- Game Center App（またはApp内の実績表示画面。kaeriTen自体には実績一覧UIは未実装）で
  解除状況を確認できる。

## 既知の注意点

- App Store Connect側に実績が登録される**前**に `GKAchievement.report(_:)` を呼んでも
  エラーになるだけで、コード側はエラーを握りつぶして再試行しない。App Store Connect側の
  登録が完了してから改めてプレイし直すか、`Progress.unlockedAchievements` から該当IDを
  削除してから再評価させる必要がある。
- 識別子の打ち間違いは実行時までわからない（App Store Connect側とコード側の文字列比較の
  ため）。コピー＆ペーストで一致させること。
