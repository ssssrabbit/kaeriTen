# KaeriTen を別のMacでビルドする

`make package` で作成した `dist/KaeriTen-src-YYYYMMDD.zip` の展開後の手順。

## 1. 展開

```sh
unzip KaeriTen-src-*.zip
cd KaeriTen-src-*/ios
```

## 2. Xcodeプロジェクトを開く

`project.pbxproj` はアーカイブ作成時に `xcodegen`（`project.yml` から）で
再生成済みなので、そのまま開くだけでよい。

```sh
open KaeriTen.xcodeproj
```

`project.yml` を編集して構成を変更したい場合は、`brew install xcodegen` の上で

```sh
cd ios && xcodegen generate
```

を実行してから開く。

## 3. 署名設定

- `project.yml` の `DEVELOPMENT_TEAM` は空欄（個人情報のため未設定）。
  Xcodeの **Signing & Capabilities** タブで自分のApple Developer Teamを選択すること。
- Debug構成は `CODE_SIGN_STYLE: Automatic` なので、Teamを選べば実機・シミュレータとも
  そのままビルドできる。
- Release構成（Archive用）は `CODE_SIGN_STYLE: Manual` + `Apple Distribution` 固定。
  App Store提出を行う場合は Apple Developer Portal で配布用プロビジョニングプロファイルを
  別途用意し、`project.yml` の `PROVISIONING_PROFILE_SPECIFIER` を設定すること。

## 4. Game Center機能

`KaeriTen.entitlements` に `com.apple.developer.game-center` を含む。実績機能を
動かすには、Apple Developer PortalでApp IDにGame Center capabilityを有効化し、
App Store Connect側で実績を登録する必要がある。
未設定でもアプリ自体は問題なくビルド・起動する（Game Centerサインインが失敗するだけ）。

## 5. 依存関係

外部パッケージ（SPM/CocoaPods）は一切使用していない。`libsqlite3.tbd` のみ
システムSDKからリンクする（`project.yml` に定義済み）。

## 6. ビルド

```sh
cd ios
xcodebuild -project KaeriTen.xcodeproj -scheme KaeriTen \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

または Xcode で Cmd+R。

**注意**: `xcodebuild` はビルドディレクトリにロックファイルを作るため、
バックグラウンド実行や複数プロセスの同時実行は避けること（デッドロックする）。
