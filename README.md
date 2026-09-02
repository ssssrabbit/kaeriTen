# kaeriTen

漢文の返り点（レ点・一二三点・ハイフン）を指先で置いて、正しい読み順を再現するパズルゲームです。レ点や一二三点の意味を覚えていなくても、パズルとして繰り返し遊ぶうちに読み順の感覚が身につくように設計されています。

- App Store: https://apps.apple.com/jp/app/kaeriten/id6802865712
- 対応OS: iOS 17.0 以降（iPhone・iPad）
- 技術構成: SwiftUI + SpriteKit（外部パッケージ依存なし）

## 遊び方

画面下の水色のパイプが「今置いている返り点から実際に計算される読み順」を表します。正解の読み順（マゼンタの線）とパイプの形がぴったり重なればクリアです。

### 基本操作

- 漢字の下の丸（スロット）をタップすると、返り点の選択メニューが出てきます。
- 「レ」「一」「二」…から選ぶと、その返り点がスロットに置かれます。指を離した場所で選択が確定します。
- ハイフンが必要な問題では、漢字と漢字の間にある小さな丸をタップして、隣接する文字を1つの読みブロックとして結合／解除できます。
- 水色のパイプの形を、正解を示すマゼンタの線に合わせるのが目標です。
- 制限時間内に一致させればクリア。書き下し文と現代語訳が表示され、次の問題に進みます。

### クリアマークの意味

| マーク | 意味 |
|---|---|
| 緑のチェック（check_1） | ノーミス（パーフェクト）でクリアした回数。最大5個まで、優先的に表示されます |
| ピンクのチェック（check_5） | ミスありでクリアした回数。緑のマークで埋まらなかった残り枠に表示されます（合計最大5個） |
| 金の王冠（check_full） | そのステージでパーフェクトクリアを6回達成した完全クリアの証 |

## アプリのビルド方法

### 必要環境

| ツール | 用途 |
|---|---|
| Xcode 17 | iOS 17.0 SDK でのビルド・実行（App Store提出用Archiveもここから行います） |
| XcodeGen | `brew install xcodegen`。`project.yml` から `.xcodeproj` を生成します |

### 取得とビルド

```sh
git clone https://github.com/ssssrabbit/kaeriTen.git
cd kaeriTen/ios
xcodegen generate
xcodebuild -project KaeriTen.xcodeproj -scheme KaeriTen \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

または `ios/KaeriTen.xcodeproj` を Xcode で開いて Cmd+R（GUIで実行する場合はこちらが簡単です）。

> **注意**: `xcodebuild`・`swift build` はバックグラウンド実行しないでください。DerivedData のロック競合でデッドロックします。フォアグラウンドで1回ずつ実行してください。`ios/project.yml` を編集した後は、必ず `xcodegen generate` を再実行してから `xcodebuild` してください（`.xcodeproj` は生成物なので手編集しないでください）。

### テスト実行

```sh
xcodebuild -project KaeriTen.xcodeproj -scheme KaeriTen \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

### 署名設定

- `project.yml` の `DEVELOPMENT_TEAM` は空欄（個人情報のため未設定）。Xcodeの **Signing & Capabilities** タブで自分のApple Developer Teamを選択すること。
- Debug構成は `CODE_SIGN_STYLE: Automatic` なので、Teamを選べば実機・シミュレータともそのままビルドできる。
- Release構成（Archive用）は `CODE_SIGN_STYLE: Manual` + `CODE_SIGN_IDENTITY: "Apple Distribution"` 固定。App Store提出を行う場合は Apple Developer Portal で配布用プロビジョニングプロファイルを別途用意し、`project.yml` の `PROVISIONING_PROFILE_SPECIFIER` を設定してください。署名設定やAppIcon・PRODUCT_NAMEを変更した後は、必ず Clean Build Folder してから Archive を作り直します。

### Game Center

`KaeriTen.entitlements` に `com.apple.developer.game-center` を含みます。実績機能を動かすには、Apple Developer PortalでApp IDにGame Center capabilityを有効化し、App Store Connect側で実績を登録する必要があります。未設定でもアプリ自体は問題なくビルド・起動します（Game Centerサインインが失敗するだけ）。

### 既知の制約・注意点

- `Bundle.main` の subdirectory 指定でのリソース読み込みは効かないことがあります（xcodegenがResources配下のサブフォルダをバンドル直下にフラット配置するためです）。BGM/SE/画像読み込みコードは subdirectory 指定→指定なしのフォールバックを持っています。
- SpriteView上に後乗せしたSwiftUIコンテンツは、環境によって再描画が反映されないことがあります。結果パネル・ライフゲージ等はすべてSpriteKitノードとして実装しています。
- 返り点・ハイフンは元データベースの `mark_str`/`hyphen_str` を信用せず、`reading_order_str`（正解の読み順）から再構築した値のみを正としています。

より詳しい手順（署名なしでの展開からの流れ）は [BUILD_ON_ANOTHER_MAC.md](BUILD_ON_ANOTHER_MAC.md) を参照してください。
