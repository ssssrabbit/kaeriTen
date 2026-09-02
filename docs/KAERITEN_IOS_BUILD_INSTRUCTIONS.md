# KaeriTen — iOS パズルゲーム実装指示書

> 本書は `docs/workflow_game.txt`（企画メモ）を、Claude Code が実行可能な形に具体化した実装指示書である。
> Claude は**本書のマイルストーンを上から順に**実行し、各マイルストーンの受け入れ条件を満たしてから次へ進むこと。

- プロジェクトルート: `/Users/takaho/Google Drive/マイドライブ/Projects/Kanbun`
- 対象: iOS 17.0+ / iPhone 縦画面固定
- 作成日: 2026-08-16

---

## 0. 前提と設計判断

### 0.1 企画メモからの変更点（重要）

`workflow_game.txt` には「Godot を用い」と書かれているが、**本実装では Godot を使わず SwiftUI + SpriteKit のネイティブ iOS アプリとする**（ユーザー承認済み）。

理由:

- Godot はシーン編集・エクスポートテンプレート・Xcode 書き出しに GUI 手作業が入り、Claude が単独でビルド〜シミュレータ実行〜スクリーンショット検証まで完結できない。
- Swift はすべてテキストソースであり、`xcodebuild` → `simctl` → スクリーンショットまで自動で回せる。`git diff` も人間が読める。
- SQLite / WebP / 音声再生はいずれも iOS 標準 API で扱える。

企画メモのそれ以外の内容（ゲームルール、画面構成、ステージ定義、リソース配置）は**すべてそのまま踏襲する**。

### 0.2 技術スタック

| 領域 | 採用 |
|---|---|
| UI シェル / 画面遷移 | SwiftUI |
| ゲーム盤面描画（パイプ・グリッド・アニメ） | SpriteKit (`SKScene` を `SpriteView` で埋め込む) |
| 問題データ | SQLite（アプリ同梱の軽量 DB）— `SQLite3` C API を薄いラッパで直接利用（外部依存なし） |
| 画像 | WebP BLOB。iOS 14+ の `UIImage(data:)` は WebP をデコードできる |
| 音声 | `AVAudioPlayer`（BGM ループ）+ `AVAudioPlayer` プール（SE） |
| セーブデータ | `UserDefaults`（進行状況・音量設定） |
| 依存管理 | **外部パッケージを追加しない**（SPM 依存ゼロ。CocoaPods 禁止） |

### 0.3 命名規約（グローバルルール遵守・必須）

- `PRODUCT_NAME` は **ASCII のみ**: `KaeriTen`
- `CFBundleDisplayName` も **ASCII のみ**: `kaeriTen`（doc §M8.5後 ユーザー指示。アプリ名・
  ファイル名に日本語を使うと署名バグの原因になるため、表示名も含め日本語を使わない方針に変更した）
- Bundle ID: `de.opqrco.kaeriten`（doc §M8.5後 ユーザー指示で `com.takaho.kaeriten` から変更）
- App Store カテゴリ: Games（サブカテゴリ Educational）

濁点・半濁点を含む日本語を `PRODUCT_NAME` に使うと codesign / App Store 検証で error 90034 が発生するため、絶対に使わないこと。

### 0.4 ビルド実行のルール（グローバルルール遵守・必須）

- `xcodebuild` を **`run_in_background: true` で実行してはならない**（DerivedData のロック競合でデッドロックする）。
- `xcodebuild` はフォアグラウンドで、タイムアウト付きで 1 回ずつ実行する。
- 実行前に `ps aux | grep xcodebuild` で残プロセスがないことを確認する。
- 型チェックだけしたいときは `swiftc -typecheck` を使う。

---

## 1. Git 運用ルール

既存の Kanbun リポジトリ（`master` ブランチ）をそのまま使う。ゲーム実装は**サブディレクトリ `ios/` に隔離**し、既存の Python 資産に影響を与えない。

### 1.1 ブランチ戦略

```bash
git checkout -b feature/kaeriten-ios
```

- 全作業をこのブランチで行う。`master` には触らない。
- マイルストーン完了ごとに `master` へはマージせず、ブランチ上にタグを打って積み上げる。

### 1.2 コミット規約

- **1 マイルストーン = 最低 1 コミット**。マイルストーン内でも論理的単位ごとに小さくコミットする。
- コミットメッセージ形式:

```
M<番号>: <日本語で何をしたか>

- 変更点の箇条書き
- 受け入れ条件の達成状況

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

### 1.3 マイルストーンタグ（ロールバック地点）

各マイルストーンの受け入れ条件を満たした時点で、必ず注釈付きタグを打つ:

```bash
git tag -a m3-board-render -m "M3: 盤面描画とルート表示が完成"
```

タグ一覧は「§2 マイルストーン一覧」の `tag` 列を使うこと。

### 1.4 問題が起きたときの戻し方

```bash
# 直前のマイルストーン状態を確認
git tag -l
git log --oneline --decorate -20

# 作業中の変更を捨てて直前のタグに戻す
git stash            # 惜しい変更があれば退避
git reset --hard m3-board-render

# タグ地点からやり直し用のブランチを切る
git checkout -b feature/kaeriten-ios-retry m3-board-render
```

**破壊的操作（`reset --hard`、`clean -fd`、タグ削除）を行う前は必ずユーザーに確認を取る。**

### 1.5 .gitignore への追記（M0 で実施）

リポジトリ直下の `.gitignore` は `*.db` を無視している。生成する軽量 DB はコミットしたいので、拡張子を `.sqlite` にし、以下を追記する:

```gitignore
# --- iOS game ---
ios/build/
ios/DerivedData/
*.xcuserdatad
xcuserdata/
.DS_Store

# 生成物だが同梱するのでコミットする（*.db の無視ルールを回避するため .sqlite を使う）
!ios/KaeriTen/Resources/game.sqlite
```

`game.sqlite` は生成物だが、**ビルド再現性のためリポジトリにコミットする**（生成スクリプトも併せてコミットするので再生成は常に可能）。

---

## 2. マイルストーン一覧

| # | 名称 | tag | 概要 |
|---|---|---|---|
| M0 | 足場づくり | `m0-scaffold` | ブランチ・ディレクトリ・.gitignore・空の Xcode プロジェクト |
| M1 | データ救済と抽出 | `m1-dataset` | `reading_order_str` から返り点・ハイフンを再生成し、`game.sqlite` に書き出す |
| MX | 読み下し修正スクリプト | `mx-kandoku-fixer` | LM Studio を呼んで読み下し文を修正するスクリプトを**作成のみ**（実行しない・本線ではない） |
| M2 | ドメインロジック | `m2-domain` | 返り点 → 読み順を計算する純粋 Swift ロジック + ユニットテスト |
| M3 | 盤面描画 | `m3-board-render` | screen_001 相当の静止画面（グリッド・漢字・マゼンタ正解線・水色パイプ） |
| M4 | 入力と操作 | `m4-input` | 返り点タップ→放射メニュー選択（screen_002 相当）、パイプ再計算 |
| M5 | クリア判定と演出 | `m5-clear` | 正解時にパイプが発光（screen_003 相当） |
| M6 | 結果イベント画面 | `m6-event` | 画像・読み下し・フレーバーテキスト表示（screen_004 相当） |
| M7 | ステージ進行 | `m7-progression` | Stage X-Y 構成、進捗保存、ステージ選択、クリア画面 |
| M8 | 音響 | `m8-audio` | BGM ループ・SE・音量設定 |
| M9 | 仕上げ | `m9-polish` | アイコン、起動画面、実機ビルド設定、README |

---

## M0 — 足場づくり

### 目的
以降の作業が git で追跡・巻き戻し可能な状態を作る。

### 作業

1. ブランチ作成:
   ```bash
   git checkout -b feature/kaeriten-ios
   ```
2. `.gitignore` に §1.5 の内容を追記。
3. ディレクトリ構成を作成:

```
ios/
├── KaeriTen.xcodeproj/
├── KaeriTen/
│   ├── App/                 # KaeriTenApp.swift, RootView.swift
│   ├── Domain/              # Puzzle.swift, ReadingOrder.swift, StageCatalog.swift
│   ├── Data/                # PuzzleStore.swift, SQLite.swift
│   ├── Scene/               # BoardScene.swift, PipeRenderer.swift, MarkPicker.swift
│   ├── UI/                  # StageSelectView, GameView, EventView, SettingsView
│   ├── Audio/               # AudioEngine.swift
│   ├── Resources/
│   │   ├── game.sqlite      # M1 で生成
│   │   ├── bgm/             # resource/bgm からコピー
│   │   └── se/              # resource/se からコピー
│   └── Assets.xcassets/
└── KaeriTenTests/           # ドメインロジックのユニットテスト
```

4. Xcode プロジェクトを作成する。**GUI は使わず**、`xcodegen` が無ければ `project.pbxproj` を手書きするのではなく、以下のいずれかを選ぶ:
   - 推奨: `xcodegen`（`brew install xcodegen`）を使い `ios/project.yml` からプロジェクトを生成する。`project.yml` をコミットすれば `.xcodeproj` は再生成可能になる。
   - `xcodegen` を入れられない場合はユーザーに相談すること。

5. `project.yml` の要点:
   ```yaml
   name: KaeriTen
   options:
     bundleIdPrefix: com.takaho
     deploymentTarget: { iOS: "17.0" }
   targets:
     KaeriTen:
       type: application
       platform: iOS
       sources: [KaeriTen]
       settings:
         base:
           PRODUCT_NAME: KaeriTen            # ASCII 必須
           PRODUCT_BUNDLE_IDENTIFIER: de.opqrco.kaeriten
           INFOPLIST_KEY_CFBundleDisplayName: kaeriTen   # ASCII 必須（doc §M8.5後）
           INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
           INFOPLIST_KEY_UIStatusBarHidden: YES
         configs:
           Debug:  { CODE_SIGN_STYLE: Automatic }
           Release: { CODE_SIGN_STYLE: Manual, CODE_SIGN_IDENTITY: "Apple Distribution" }
   ```

6. 「Hello, KaeriTen」だけを表示する `KaeriTenApp.swift` を置く。

### 受け入れ条件

- [ ] `xcodebuild -project ios/KaeriTen.xcodeproj -scheme KaeriTen -destination 'platform=iOS Simulator,name=iPhone 17' build` がフォアグラウンドで成功する
- [ ] シミュレータで起動し、スクリーンショットに「Hello, KaeriTen」が写る
- [ ] `git tag -a m0-scaffold`

---

## M1 — データ救済と抽出

### 目的
`kanbun_matrix_corpus.db` から出題データを抽出し、アプリ同梱用の軽量 `game.sqlite` を生成する。

**DB の `mark_str` / `hyphen_str` は壊れているため使わない。`reading_order_str` を唯一の正とし、それを再現する返り点とハイフンを探索で作り直す**（これにより使用可能な問題が 3,332 → **5,213 問（98.4%）** に増える。`tools/build_game_db.py` 実装・実行済み、§1-B / §1-C）。

### 1-A. 元データの仕様（実測確定済み）

テーブル `game_manifest_assets`（全 5,380 行、うち `reading_order_str IS NOT NULL` が 5,295 行）:

| 列 | 内容 |
|---|---|
| `id` | 主キー |
| `kanbun_text` | 出題される偽中国語（漢字列） |
| `kandoku_text` | 読み下し文（クリア後に表示） |
| `modern_translation` | フレーバーテキスト（クリア後に表示） |
| `mark_str` | 返り点。1 トークン 1 文字。**壊れているため使用しない**（§1-B / §1-C 参照） |
| `hyphen_str` | ハイフン。長さ = トークン数 - 1。**同上、使用しない** |
| `reading_order_str` | **正解の読み順。これを唯一の正とする** |
| `image_blob` | WebP 画像（先頭 4 バイトが `RIFF`）。5,251 行に存在 |
| `image` | **全行 NULL。使用しないこと**（企画メモの記述と実データが食い違う） |
| `english_prompt`, `template_id` | ゲームでは未使用 |

#### `mark_str` の文字

| 文字 | 意味 |
|---|---|
| `.` | 返り点なし |
| `r` | レ点 |
| `1` | 一点 |
| `2` | 二点 |

出現数: `.` 14,926 / `r` 5,153 / `1` 2,383 / `2` 2,383（一と二は必ず同数＝ペア）。三点以上は元データには存在しない。

#### `hyphen_str` の文字

`0` = ハイフンなし、`1` = そのトークンと次のトークンの間にハイフン。出現数: `0` 15,825 / `1` 3,725。

#### `reading_order_str` の意味（実証で確定）

**`reading_order_str` の i 番目（0 始まり）の文字は、「i+1 番目に読むトークンの位置（1 始まり）」である。**

例: `id=331` `暈飲山間而買` / `mark_str=".2.1r."` / `reading_order_str="134265"`
→ 読む順は トークン1(暈) → 3(山) → 4(間) → 2(飲) → 6(買) → 5(而)。
`kandoku_text` =「暈は山間を飲みて、これを買う。」と一致する。

※ 逆の解釈（「トークン i が何番目に読まれるか」）は不正解。実データで検証済み。

#### トークン数 ≠ 文字数の行がある

`len(kanbun_text) != len(reading_order_str)` の行が 32 件ある（例: `γ線美書自楮` は 6 文字だが 5 トークン。`γ線` が 1 トークン）。
**トークン数の正は `len(mark_str)` = `len(reading_order_str)` である。**
`kanbun_text` を単純に 1 文字ずつ割ると盤面がずれるため、この 32 件は M1 で除外する（複雑なトークナイズは行わない）。

### 1-B. 返り点 → 読み順のアルゴリズム（正）

#### ハイフンの前処理

まずハイフンで結ばれたトークンを **1 つの読みブロック**に結合する。`hyphens[k] == '1'` なら トークン `k` と `k+1` は同一ブロック。

ブロックに付く返り点は、**そのブロックの末尾トークンの mark** を採用する（実データで検証済み。先頭トークン採用だと一致率が 62.9% → 40.9% に落ちる）。

読み順はブロック単位で計算し、最後にブロックを構成トークンへ左→右に展開する。ハイフンで結ばれたトークンは必ず連続・順方向に読まれる。

#### 返り点の記号

| 記号 | 意味 |
|---|---|
| `.` | なし |
| `r` | レ点（直前のブロックへ戻る。連続すればレ点連鎖） |
| `1` | 一点（戻りの起点） |
| `2` `3` `4` | 二点・三点・四点（戻り先。近い順に読む） |

上中下点は**実装しない**（必要な問題が 4 件しかないため M1 で除外する）。

#### 本体アルゴリズム

ブロック列を左から右に走査する。

```
read[] = 未読フラグ
out[]  = 読んだ順のブロック位置

i = 0
while 未読が残る:
    if i >= n: break
    if read[i] または mark[i] が 'r' / '2' / '3' / '4':
        i += 1                      # 返り点付きは飛ばして後で戻る
        continue

    out に i を追加（read[i] = true）

    if mark[i] == '1':
        レ点連鎖解決(i)
        # 一点を読んだら 二 → 三 → 四 の順に戻る
        for level in ['2', '3', '4']:
            j = i より前にある未読ブロックのうち mark[j] == level で最も i に近いもの
            if j が存在しない: break
            out に j を追加（read[j] = true）
            レ点連鎖解決(j)
    else:
        レ点連鎖解決(i)

    i += 1

レ点連鎖解決(p):
    k = p - 1
    while k >= 0 かつ mark[k] == 'r' かつ read[k] が false:
        out に k を追加（read[k] = true）
        k -= 1
```

最後に `out`（ブロック位置の列）を、各ブロックの構成トークンへ左→右に展開してトークン位置の列にする。

このアルゴリズム（ハイフン結合を含む）を **DB の `mark_str` / `hyphen_str` をそのまま信じて**全 5,295 行に適用すると、`reading_order_str` と完全一致するのは 3,332 行（62.9%）にとどまる。

**しかしこれは DB の `mark_str` / `hyphen_str` が壊れているだけであり、問題そのものは大半が救済できる。**§1-C の方針を採る。

#### なぜ DB の返り点をそのまま使ってはいけないか（調査済み・結論）

1. **`mark_str` と `hyphen_str` は `reading_order_str` とは別の処理で生成されており、整合していない。**
   `id=13 道徳買自教` では、`kandoku_text`「道徳、教より購う」から導かれる正解（読み順 `1,2,5,4,3` / 返り点 `..rr.`）に対し、DB の `mark_str` は `...r.`、`reading_order_str` は `12534` と **3 者がすべて食い違う**。
2. **`reading_order_str` の側は、一〜四点とハイフンを併用すればほぼ全て返り点で表現できる。**
   例: `id=10 極飲於国籍` の `reading_order_str="45312"`（＝ 国 籍 於 極 飲）は、ユーザーからの指摘を機に検証した。
   `極‐飲` をハイフンで 1 ブロックに結合し `三・二・一` を使う解（`hyphens="1000"` `marks=".32.1"`）でも正確に再現できるが、
   実装した探索では**ハイフンなしで `一二三四点をフル活用する解**（`marks="342.1"`、`hyphens="0000"`）が「ハイフン数最小」を優先する探索順で選ばれた（どちらも自己検証済みで正しい。優先順位の設計次第でどちらも採用しうる）。
   ハイフンは「戻った先を順方向に連続して読む」ことを可能にし、一〜四点は最大 4 か所への戻りを表現できるため、両者を併用するとレ点・二点だけでは届かない順序の大半に到達できる。
3. したがって、**`reading_order_str` を正とし、`mark_str` と `hyphen_str` を探索で作り直す**のが正しい方針である。

#### 救済後の到達率（`tools/build_game_db.py` 実行結果・実測）

| 方針 | 使用可能な問題数 |
|---|---|
| DB の `mark_str`/`hyphen_str` をそのまま使う | 3,332（62.9%） |
| **`reading_order_str` から返り点・ハイフンを再生成する（一〜四点 + ハイフン対応）** | **5,213（98.4%）** |
| どうしても到達不能（一〜四点 + ハイフンでも表現できない真に壊れた順序） | 6（0.1%）※ |
| 形式的な理由で除外（トークン数不一致・画像欠落など） | 76（1.4%） |

※ 対象 5,295 行中。到達不能の 6 件（例: `id=806 復愛本人座燕`, `id=1031 転飲門座木造` など）は上中下点のような**入れ子構造の返り点**が必要であり、本ゲームでは実装しないため除外する。

**探索での返り点・ハイフンの選び方（実装した優先順位）**: 各問題について、可能な全てのハイフン分割（最大 32 通り）を試し、それぞれについて目標の読み順を再現する返り点をアルゴリズム的に導出する（導出できない分割は捨てる）。複数の分割が成立する場合は **(1) ハイフン数が少ない、(2) 数字点の最大段数が小さい** の順で最も単純な解を採用する。導出した返り点・ハイフンは、書き出し前に必ずフォワードシミュレータへ通し、`reading_order_str` と一致することを機械的に再検証する（一致しなければその解は不採用）。

**上中下点（入れ子構造）は実装しない**。該当 6 件は除外する。一〜四点までのみ対応する（最大段数の実測分布は §1-D 直後を参照）。

### 1-C. 救済つき抽出スクリプト

`tools/build_game_db.py` を新規作成する（Python 3、標準ライブラリ + `Pillow` のみ）。

**基本方針: `reading_order_str` を唯一の正とし、返り点とハイフンはそこから再生成する。DB の `mark_str` / `hyphen_str` は破棄する。**

処理:

1. `kanbun_matrix_corpus.db` を **読み取り専用**（`file:...?mode=ro` URI）で開く。元 DB は絶対に書き換えない。
2. 一次フィルタ（形式的な健全性）:
   - `reading_order_str`, `kandoku_text`, `modern_translation` が非 NULL
   - `len(kanbun_text) == len(reading_order_str)`（不一致 32 行は除外。`γ線` のような複数文字トークンは扱わない）
   - トークン数 3〜6
   - `reading_order_str` が 1..n の順列である
   - `image_blob` が非 NULL かつ先頭 4 バイトが `RIFF`
3. **返り点・ハイフンの再生成（救済の核。実装済み: `tools/build_game_db.py`）**:
   - ハイフンの入れ方 `2^(n-1)` 通り（n ≤ 6 なので最大 32 通り）を全探索する。
   - 各分割について、`reading_order_str` が**各ブロックのトークンを連続かつ順方向に読んでいるか**を検査する（`block_order_from_reading`）。満たさない分割は捨てる。
   - 満たす場合、ブロック単位の目標読み順（ブロック番号の順列 `P`）が得られる。これを再現する返り点をブロック単位で**貪欲に導出する**（`derive_block_marks`）:
     - 走査位置 `i` と `P` の消費ポインタ `t` を同時に進める。`P[t] == i` なら「素直な前進読み」としてそのブロックを読み、直後に「直前のブロックへの戻り（レ点連鎖）」を続く限り消費する。
     - レ点連鎖を消費し終えてもなお `P[t] < i` かつ未消費なら、そのブロックに `一` を置き、続けて `二`・`三`・`四` の順で「`i` より前にある未消費ブロック」を `P` の指示に従って割り当てる（各割り当て後もレ点連鎖の解決を挟む）。
     - どの規則にも合致しない場合は導出失敗とし、その分割は不採用。
   - 導出できた `marks`/`hyphens` は、**必ずフォワードシミュレータ（§1-B 本体アルゴリズム）に通して `reading_order_str` と完全一致するか再検証する**。一致しない解は破棄する（导出ロジックのエッジケースに対する安全網）。
   - 複数の分割が成立する場合は **(1) ハイフン数、(2) 数字点の最大段数** の順に小さいものを採用する（＝ハイフンを使わずに済むなら使わない。四点までで足りるならそれで済ませる）。
   - どの分割でも導出・検証に成功しなければ、その行は不採用（真に到達不能。実測 6 件）。
4. ステージ分類を計算して列に持たせる（§1-D）。
5. 画像を長辺 512px に縮小し、WebP 品質 80 で再エンコードして格納（アプリサイズ削減のため）。
6. `kandoku_text` との整合フラグを立てる（§1-E）。
7. 出力先: `ios/KaeriTen/Resources/game.sqlite`

出力スキーマ:

```sql
CREATE TABLE puzzles (
    id            INTEGER PRIMARY KEY,   -- 元 DB の id をそのまま引き継ぐ
    kanbun        TEXT NOT NULL,
    kandoku       TEXT NOT NULL,
    flavor        TEXT NOT NULL,
    marks         TEXT NOT NULL,         -- 再生成した返り点 '.', 'r', '1'..'4'
    hyphens       TEXT NOT NULL,         -- 再生成したハイフン '0'/'1'
    reading_order TEXT NOT NULL,         -- 元データ（唯一の正）
    token_count   INTEGER NOT NULL,
    stage_x       INTEGER NOT NULL,      -- 1=レ点のみ / 2=数字点あり / 3=ハイフンあり
    stage_y       INTEGER NOT NULL,      -- = token_count
    max_level     INTEGER NOT NULL,      -- 数字点の最大段数（1=レ点のみ, 2=一二, 3=一二三, 4=一二三四）
    kandoku_ok    INTEGER NOT NULL,      -- 1 = reading_order が kandoku と整合。表示分岐には使わない（§1-E / MX 用のメタデータ）
    image         BLOB NOT NULL          -- WebP
);
CREATE INDEX idx_stage ON puzzles(stage_x, stage_y);

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);  -- generated_at, source_rows, kept_rows など
```

**自己検証（必須）**: 書き出した全行について、§1-B のアルゴリズムに `marks` と `hyphens` を与えた結果が `reading_order` と一致することを、書き出し直後に再計算して確認する。1 行でも不一致なら中断してエラーにする。

同時に `tools/build_game_db_report.md` に採用件数・除外理由別件数を出力し、これもコミットする。

### 1-D. ステージ在庫（救済後の実測値）

企画メモの「X は 1 がレ点のみ、2 がレ点と返点、3 がハイフンもあり」をそのまま採用する。ただし X=2 には一二点だけでなく一二三点・一二三四点も含める（記号の段数はゲーム内で残数表示されるので、プレイヤーには自然に伝わる）。

- `stage_x` = 3 if ハイフンあり / 2 if 数字点あり（ハイフンなし）/ 1 if レ点のみ（ハイフンなし）
- `stage_y` = トークン数（3〜6）

`tools/build_game_db.py` の実行結果（実測・自己検証済み、`tools/build_game_db_report.md` に同じ内容を出力）:

| | 3字 | 4字 | 5字 | 6字 | 計 |
|---|---|---|---|---|---|
| **Stage1**（レ点のみ） | 658 | 688 | 492 | 216 | **2,054** |
| **Stage2**（数字点あり） | 202 | 641 | 1,023 | 1,002 | **2,868** |
| **Stage3**（ハイフンあり） | 0 | 0 | 69 | 222 | **291** |
| 計 | 860 | 1,329 | 1,584 | 1,440 | **5,213** |

数字点の最大段数の分布: 1段(レ点のみ) 2,054 / 2段(一二) 1,259 / 3段(一二三) 1,646 / 4段(一二三四) 254。

**Stage3-3・Stage3-4（3字・4字でハイフンが必要な問題）は 0 問である。これは在庫不足ではなく、数学的に証明された恒久的な制約である**: 3トークンの順列は全6通り、4トークンの順列は全24通りしかないが、そのうち「ハイフンなしでは表現できない」ものは**1件もない**（全順列を総当たりで検証済み）。コーパスをどれだけ拡充しても Stage3-3・Stage3-4 は埋まらない。詳細な証明・再検証コード・将来ルール変更の選択肢は [PUZZLE_INVENTORY_GAPS.md](PUZZLE_INVENTORY_GAPS.md) に記録した。**したがって Stage3 は 5字・6字の 2 サイズのみで構成し、Stage3-3・Stage3-4 はステージ一覧から除外する**（10 ステージ構成になる: Stage1-3〜6, Stage2-3〜6, Stage3-5〜6）。

救済前（DB の返り点をそのまま使う場合）は 3,332 問だった。**救済によって全ステージが最低 202 問の在庫を持つようになり、「同じステージで同じ問題に当たりにくい」という要件を満たせる**（最小の Stage2-3 でも 202 問あるので、1 ステージ 5 問なら 40 セッション以上重複しない）。

この表はスクリプトの実行結果そのものである。再実行して食い違ったらユーザーに報告する。

### 1-E. `kandoku_text` との整合について（方針決定済み）

再生成した読み順が `kandoku_text`（読み下し文）と整合するのは **5,213 問中 2,073 問（39.8%）** にとどまる。

**原因は判明している**: `kandoku_text` は小さいローカル LLM で生成したため品質が低く、読み順と食い違っているものが多い。つまり壊れているのは主に読み下し文の側であり、パズルとしての構造（偽中国語 + 読み順 + 返り点）は成立している。

**方針（ユーザー決定済み。実装はこれに従う）**:

- **返り点・ハイフンで読み順を表現できる問題は、読み下し文と矛盾していても全て使用する。** 出題対象は 5,213 問すべて。
- **開発段階では、矛盾していても `kandoku_text` をそのまま「仮の読み下し文」として表示する。** M6 で出し分けはしない。
- `kandoku_ok` フラグは DB に持たせるが、**アプリの表示分岐には使わない**。将来の修正作業の対象抽出と進捗計測のためのメタデータとして保持する。
- 読み下し文（あるいは偽中国語と読み順）の修正は後日行う。そのためのスクリプトは MX で作成するが、**トークンコストがかかるため今回は実行しない**。

したがって M6 の実装では `kandoku` を常に表示してよい。表示分岐のコードを書く必要はない。

### 受け入れ条件

- [ ] `tools/build_game_db.py` が実行でき、`ios/KaeriTen/Resources/game.sqlite` が生成される
- [ ] 元 DB `kanbun_matrix_corpus.db` のタイムスタンプが変わっていない（読み取り専用が守られている）
- [x] 採用件数: **5,213 問**（実測）
- [x] 実運用する 10 ステージ（Stage1-3〜6, Stage2-3〜6, Stage3-5〜6）の在庫がいずれも 200 問以上ある（Stage3-3・Stage3-4 は在庫 0 のためステージ一覧から除外。§1-D）
- [x] `game.sqlite` のサイズ: 55.1MB（60MB 未満）
- [x] `tools/build_game_db_report.md` に採用/除外の内訳が記録されている
- [x] **全採用行について「再生成した `marks`/`hyphens` を §1-B に通した結果 == `reading_order`」が 100% になる**（スクリプト内で自己検証、5,213 件全て一致を確認済み）
- [x] `id=10 極飲於国籍` が採用され、`hyphens="0000"` / `marks="342.1"` になっている（ハイフンなし・一〜四点をフル活用する解。導出優先順位が「ハイフン数最小」を先に見るため選ばれた。`hyphens="1000"`/`marks=".32.1"` も別解として存在するが不採用）
- [x] `git tag -a m1-dataset`

---

## MX — 読み下し修正スクリプト（作成のみ・実行しない）

### 位置づけ

**本線ではない。M1 の後、M2 と並行して着手してよいが、ゲーム実装をブロックしない。**

`kandoku_text` は小さいローカル LLM で生成したため、読み順と矛盾しているものが 52.5%（2,277 問）ある（§1-E）。将来これを修正するためのスクリプトを**用意だけしておく**。

**トークンコスト・実行時間がかかるため、このマイルストーンではスクリプトを実行しない。** 動作確認は 3〜5 件程度のドライラン（`--limit 3 --dry-run`）にとどめ、それ以上は回さないこと。全件実行するかどうかはユーザーが後日判断する。

### 成果物

`tools/fix_kandoku_lmstudio.py` を作成する。

### 既存の LM Studio 呼び出し規約（このリポジトリの先例に合わせる）

過去に `regenerate_images.py` で使われていた規約をそのまま踏襲する（コミット `3171cf0` 参照）:

```python
LM_STUDIO_URL = "http://localhost:1234/v1/chat/completions"
LM_MODEL      = "google/gemma-4-26b-a4b"   # 実際に LM Studio にロードされているモデル名に合わせる
LM_MAX_TOKENS = 5000                        # 思考トークン込み
LM_TIMEOUT    = 180
COMMIT_INTERVAL = 20                        # N 件ごとに DB へコミット
```

- HTTP は `urllib.request` を使う（外部依存を増やさない）。
- レスポンスから `</think>` 以降を取り出す処理を入れる（思考モデル対策）。
- 例外は握りつぶして `None` を返し、その行はスキップして次へ進む（全体を止めない）。

### 2 つの修正モード

`--mode` で切り替える。既定は `kandoku`。

**`--mode kandoku`（読み下し文を直す）**

読み順を正として、それに合致する読み下し文を作らせる。パズル構造を壊さないので安全。

- LLM に渡すもの: 偽中国語、読み順どおりに並べ替えた漢字列、フレーバーテキスト（`modern_translation`）
- 求めるもの: その順序で読んだときに自然な日本語になる読み下し文（送り仮名・ルビ付き）
- プロンプトには「**漢字の出現順序を絶対に変えてはならない**」ことを明示する。

**`--mode kanbun`（偽中国語と読み順のほうを直す）**

読み下し文を正として、偽中国語と読み順を作り直す。こちらはパズルの構造そのものが変わるため、`game.sqlite` の再生成が必要になる。

- LLM に渡すもの: 現在の読み下し文、現在の偽中国語
- 求めるもの: その読み下し文に対応する漢文（漢字列）と、その読み順

### 必須の後処理検証（LLM の出力を信用しない）

どちらのモードでも、LLM の出力を**そのまま DB に書いてはならない**。以下を機械的に検証し、通らなければその行をスキップして理由を記録する。

1. `--mode kandoku`: 生成された読み下し文から括弧内ルビを除去し、**読み順どおりに全トークンが順に出現する**ことを確認する（§1-E の `kandoku_ok` 判定と同じ関数を使う）。
2. `--mode kanbun`: 生成された偽中国語のトークン数が 3〜6 であること、読み順が 1..n の順列であること、**§1-B の返り点探索で実現可能であること**（`tools/build_game_db.py` の探索関数を import して再利用する）。
3. 元の値は必ず別列に退避してから上書きする。

### 安全策（必須）

- **元 DB `kanbun_matrix_corpus.db` を直接書き換えてはならない。** 出力は別ファイル `kandoku_fixed.sqlite` に書き、`id` と修正後の値だけを持つ差分テーブルにする。元 DB へのマージはユーザーが明示的に指示したときだけ行う。
- `--limit N`（処理件数上限）と `--dry-run`（DB に書かず標準出力に出すだけ）を必ず実装する。
- 対象行の既定は `kandoku_ok = 0` の 2,277 問のみ（整合している行は触らない）。
- 中断・再開できるように、処理済み `id` を記録して再実行時にスキップする。
- 進捗を `tqdm` などに頼らず `print` で出す（依存を増やさない）。

### 受け入れ条件

- [ ] `tools/fix_kandoku_lmstudio.py --help` が動作する
- [ ] `--dry-run --limit 3` で 3 件だけ処理でき、出力が目視で妥当である（**これ以上は実行しない**）
- [ ] LM Studio が起動していない場合、わかりやすいエラーで終了する（スタックトレースを吐かない）
- [ ] 元 DB のタイムスタンプが変わっていない
- [ ] `git tag -a mx-kandoku-fixer`

---

## M2 — ドメインロジック（Swift）

### 目的
返り点・ハイフンの状態から読み順を計算する**純粋関数**を Swift で実装し、Python 版と完全に一致することをテストで保証する。ここが全ゲームの心臓部なので、UI より先に固める。

### 作業

1. `Domain/Puzzle.swift`:
   ```swift
   enum Mark: Character {
       case none = ".", re = "r"
       case ichi = "1", ni = "2", san = "3", yon = "4"   // 一二三四点
   }

   struct Puzzle {
       let id: Int
       let tokens: [String]        // kanbun を 1 文字ずつ
       let kandoku: String
       let flavor: String
       let answerMarks: [Mark]
       let answerHyphens: [Bool]   // count == tokens.count - 1
       let answerOrder: [Int]      // 0 始まりのトークン位置。answerOrder[step] = token index
       let stageX: Int
       let stageY: Int
       let maxLevel: Int           // 数字点の最大段数（1 = レ点のみ）
       let kandokuOK: Bool         // 読み順と読み下しが整合するか。表示分岐には使わない（§1-E）
   }
   ```

2. `Domain/ReadingOrder.swift`:
   ```swift
   /// 返り点の配置から読み順を求める。戻り値は「step 番目に読むトークンの位置（0 始まり）」
   func readingOrder(marks: [Mark]) -> [Int]
   ```
   §1-B の擬似コードをそのまま移植する。無限ループ防止のガード（最大 4n 反復）を入れること。

3. ハイフンの扱い（§1-B の前処理を実装する）:
   - ハイフンは隣接トークンを**1 つの読みブロックに結合**する。返り点はブロック単位で作用する。
   - ブロックの返り点は**末尾トークンの mark** を採用する（先頭ではない。§1-B 参照）。
   - 実装方針: `hyphens` からブロック分割 → ブロック列の mark で `readingOrder` を計算 → ブロックを左→右に展開してトークン列に戻す。
   - **正解判定は `readingOrder(現在の盤面)` == `puzzle.answerOrder` で行う**。marks/hyphens の文字列一致で判定してはならない（別解を弾いてしまうため）。ただし、ハイフン込みの読み順計算が `answerOrder` を再現できることは M2 のテストで必ず確認すること。

4. `KaeriTenTests/ReadingOrderTests.swift`:
   - `game.sqlite` の全問題を読み込み、`readingOrder(answerMarks + answerHyphens)` が `answerOrder` と一致することを検証する網羅テストを書く。
   - 加えて、以下の手計算ケースを個別テストに固定する。**すべて `tools/build_game_db.py` が実際に生成した `game.sqlite` の値であり、自己検証済み**（元データの `mark_str`/`hyphen_str` ではなく、再生成後の値である点に注意）:
     | id | kanbun | marks | hyphens | 期待する読み順（1 始まり） | 何の回帰テストか |
     |---|---|---|---|---|---|
     | 1 | 猶走賎 | `.r.` | `00` | `1,3,2` | レ点 |
     | 3 | 勿食異例 | `r2.1` | `000` | `3,4,2,1` | レ点 + 一二点 |
     | 524 | 蛭無聞山間 | `.r2.1` | `0000` | `1,4,5,3,2` | レ点連鎖 |
     | 331 | 暈飲山間而買 | `.2.1r.` | `00000` | `1,3,4,2,6,5` | 一二点 + レ点 |
     | 10 | 極飲於国籍 | `342.1` | `0000` | `4,5,3,1,2` | 一二三四点（4段フル活用、ハイフンなしで足りる例） |
     | 963 | 魚介寝座書房 | `..23.1` | `00000` | `1,2,5,6,3,4` | 二三点 + 一点 |
     | 180 | 書用品於廟 | `r.231` | `0100` | `5,2,3,1,4` | **ハイフン結合**（無視する実装では落ちる。用‐品 を1ブロックとして扱う） |
     | 1136 | 略買竿自螢 | `.r231` | `1000` | `5,3,1,2,4` | **ハイフン結合**（略‐買 を1ブロックとして扱う。レ点とも併用） |

   - **ブロックの返り点は末尾トークンに置く**という規約のテストも入れること（`id=180` がまさにそれ。`用‐品` ブロックの mark `2` は末尾トークン `品`（3文字目）に付く。トークン単位の `marks` 文字列は `r.231` で、2文字目 `用` は `.`、3文字目 `品` が `2`）。

5. `Data/PuzzleStore.swift`: SQLite3 C API の薄いラッパで `game.sqlite` を読み、`Puzzle` を返す。画像は必要になるまで読まない（`imageData(for id:)` で遅延取得）。

### 受け入れ条件

- [ ] `xcodebuild test` が成功し、全問題の網羅テストが 100% 通る
- [ ] 手計算 5 ケースが通る
- [ ] UI コードを一切書いていない（Domain/Data 層のみ）
- [ ] `git tag -a m2-domain`

---

## M3 — 盤面描画

### 目的
`resource/images/screen_001.png` に相当する静止画面を SpriteKit で描く。

### 画面レイアウト（screen_001.png / screen_002.png をピクセル解析して確定）

上から順に:

1. **ステージ表示**: `STAGE5-3` 相当。太いイタリック風の見出し、色 `#00C5FF`（明るいシアン。実測）。
2. **グリッド**: N 列 × N 行の角丸正方形（N = トークン数）。枠線は黄色 `#FFF45D`（実測）、塗りなし、背景は黒 `#000000`。
   - **列 = トークン位置**（左→右、固定・変化しない）。
   - **行 = ブロック単位の読み順ステップ**（上→下）。**重要: 行はトークン単位ではなくブロック単位である**（下記参照）。
3. **マゼンタの正解線**: 色 `#FF5DDF`（実測）。各行 `row` の下端に短い横線を引く。
4. **水色のパイプ**: 現在の返り点配置から計算した読み順を、太い角丸ポリラインで描く（暗い水色 `#005059`。実測）。左端から入り、右端へ抜ける。
   - 一致していないセルは通常表示、一致しているセルは黄色枠を強調表示。
5. **漢字行**: グリッド下に 1 行。薄いグレーの角丸ボックス（`#CCCCCC`。実測）に黒文字で `kanbun` の各トークン。
6. **返り点入力行**: 漢字行のさらに下に、トークンごとの円形スロット（黄色枠・黒塗り）。返り点が置かれると濃いグレー塗り＋白文字で `レ` / `一` / `二` / `三` / `四` を表示。
7. **残り個数表示**: 画面最下部。その問題で実際に使う種類（レ点／数字点／ハイフン）だけをシアンで動的に表示する。詳細は §M7「残り返り点の在庫表示」を参照（ハイフンは「｜」で表示するなど、当初想定から変更あり）。

#### 行は「表示行」単位である（実測 + 実装検証で確定した仕様。単純なブロック単位ではない）

`screen_001.png`（STAGE5-3 = `id=331 暈飲山間而買`、`hyphens="00100"` で「山‐間」が1ブロック）のマゼンタ線をピクセル解析したところ、次が判明した:

- **行1〜5にはマゼンタ線があるが、行6には無い。**グリッドは常に N 行あるが、実際に使われるのは行数分だけであり、残りの行は空欄になる。
- **行2のマゼンタ線だけ幅が約2倍**（列3〜列4の2列分）。これは「山‐間」ブロックがこの行で一括して読まれることを示す。他の行は1列分の幅（単一トークンのブロック）。

ここまでは「1ブロック=1行」という単純な仮定でも説明できるが、**この仮定は screen_001.png の初期状態（返り点・ハイフンが全く無い状態）の水色パイプと矛盾する**。全く未配置の状態は6個の独立したブロック（各1トークン）になり、単純な「1ブロック=1行」では対角線状の階段（行1→列1, 行2→列2, ...）になるはずだが、実測では**水色パイプは行1のみを画面幅いっぱいに横切る一直線**だった（doc原文の「先頭から最後までストレートに読まれるので暗い水色が一直線になっている」と一致）。

**正しい規則（両方の実測と矛盾なく整合する）**: ブロック単位の読み順を先頭から辿り、**列が直前の行の右端 + 1 から連続して始まるブロックは同じ行にまとめる**。実際にジャンプ（列が連続しない、＝返り点による戻りが起きた）地点でのみ新しい行を使う。

- 全く未配置の状態: 6ブロックの列がそれぞれ 1,2,3,4,5,6 と完全に連続するため、**全て1行に統合**され、行1が列1〜6いっぱいに広がる一直線になる（実測と一致）。
- `id=331` の正解（`[B1, B3, B2, B5, B4]` = 暈→山間→飲→買→而、列で言うと 1→(3-4)→2→6→5）: どの遷移も列が連続しないため、5ブロック全てが個別の行になる（実測と一致）。

**実装は `Domain/ReadingOrder.swift` の `visualRows(for:) -> [VisualRow]` として行った**（`blockReadingOrder(marks:hyphens:) -> BlockReadingOrder` でブロック分割とブロック単位の読み順を得て、それを `visualRows` で表示行にまとめる2段階）。

`BoardScene` は、**現在の盤面**については `visualRows(for: blockReadingOrder(currentMarks, currentHyphens))` を、**正解**については `visualRows(for: blockReadingOrder(puzzle.answerMarks, puzzle.answerHyphens))` を呼び、それぞれの表示行数だけ行を使って描画する。表示行数を超える行（在庫が余った行）は何も描画しない。

**注意**: 正解判定そのもの（クリア判定）は M2 で決めた通り `tokenReadingOrder(現在) == puzzle.answerOrder` のトークン単位比較のままで変えない。行の見た目（ブロック単位・表示行単位のまとめ方）は表示上の都合であり、別解が生じても勝敗判定には影響しない。

#### 座標の実測値（1320×2868 のモックアップ画像を基準。scene サイズへの相対値に変換して使うこと）

| 要素 | 値（フラクション、= 実測px / 画像寸法） |
|---|---|
| グリッド左端 | x = 0.053 |
| グリッド右端 | x = 0.946 |
| 列幅 | 0.098（画面幅比） |
| 列ピッチ（列の中心間隔） | 0.159 |
| 行1上端 | y = 0.187 |
| 行の高さ | 0.054 |
| 行ピッチ（行の上端間隔） | 0.084 |
| 漢字行上端 | y = 0.697 |
| 漢字行〜返り点入力行の間隔 | 0.015 |
| 返り点入力行上端 | y = 0.764 |
| ステージ見出し中心 | x = 0.499, y = 0.084 |

これらは目安であり、`SKScene.size` に対する相対計算のベースとして使う（ハードコードした pt 値ではなく `scene.size.width * 0.098` のように計算すること）。

### 実装メモ

- 盤面は `BoardScene: SKScene` として実装し、`SpriteView(scene:)` で SwiftUI に埋め込む。
- パイプは `SKShapeNode` の `CGPath` で描く。角は円弧で丸める（screen_002 の S 字カーブを参照）。
- レイアウトは全て `sceneSize` からの相対値で計算し、ハードコードした pt 値を使わない（iPhone SE 〜 Pro Max で崩れないこと）。
- この段階では入力を受け付けない。返り点は「全て未配置」の初期状態のみ描く（水色パイプが 1 行目を左から右に一直線に横切る = screen_001 の状態）。

### 受け入れ条件

- [x] シミュレータ（iPhone 17 / iPhone 17e。この開発機に iPhone SE 実機シミュレータが存在しないため代替）両方でスクリーンショットを撮り、`screen_001.png` と構図が一致することを目視確認した
- [x] トークン数 3, 5（ハイフンあり）, 6（ハイフンあり）で確認。全パターンでレイアウトが崩れない
- [x] `git tag -a m3-board-render`

今後 M4 以降でパイプ描画を触る際は、上記「行は『表示行』単位である」節の `visualRows` の挙動（列が連続する限り同じ行にまとまる）を前提にすること。

### 検証手順（Claude が自分で行うこと）

```bash
xcodebuild -project ios/KaeriTen.xcodeproj -scheme KaeriTen \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
その後 iOS Simulator ツールで `attach` → `launch` → `screenshot` し、自分で見て判断する。ユーザーに「確認してください」と丸投げしない。

---

## M4 — 入力と操作

### 目的
`screen_002.png` に相当する返り点入力を実装する。

### 操作仕様

- 返り点スロット（§M3 の 6.）を**タッチダウン**すると、そのスロットから縦方向に選択メニューがポップアップする。
  - メニュー項目（上から）: `四` / `三` / `二` / `一` / `レ` / `×`（削除）
    **その問題で使わない記号は最初から項目に出さない**（`maxLevel` で判断。レ点のみの問題なら `レ` と `×` の 2 項目だけ）。項目数が可変なのでメニューの高さも可変にする。
  - スロットの**左側**に「ハイフン」トグルの円が出る（その問題がハイフンを使う場合のみ）。ハイフンはトークン**間**に付くので、スロット `k` の左のトグルは「トークン `k-1` と `k` の間」を意味する。
  - 半透明のシアン `#7FE9F5` のカプセル形状。
- **指を離した位置**の項目が選択決定される（ドラッグして離す UI）。指がメニュー外なら選択キャンセル。
- 選択後、水色パイプを即座に再計算・再描画する。
- 使用個数制限: 各記号の残数を超える配置は選べない（メニュー項目をグレーアウト）。残数は `answerMarks` から算出する（`レ` の個数 = `r` の数、数字点のセット数 = `1` の数、ハイフン数 = `answerHyphens` の true の数）。
- 数字点は**セットで 1 組**（一二 / 一二三 / 一二三四）。`一` を置いたら対応する `二`（必要なら `三` `四`）も置く必要がある。
- **不完全な配置でも読み順計算がクラッシュしないこと。** 対応する `一` がない `二`/`三`/`四`、順番が飛んでいる数字点（`一` と `三` だけ等）は、その記号を無印として扱うフォールバックを入れる。プレイヤーは途中経過を常に見られる必要があるため、例外を投げてはいけない。

### 実装メモ

- タッチ処理は `BoardScene` の `touchesBegan/Moved/Ended` で行う。SwiftUI のジェスチャは使わない（SpriteKit 側に一元化）。
- 盤面状態は `@Observable final class GameState`（`State/GameState.swift`）に持ち、`RootView` が生成して `BoardScene` に渡す。`BoardScene` は `gameState.marks`/`gameState.hyphens` を直接読み書きし、変更後は自前で `render()` を呼び直す（SwiftUIの再描画サイクルには乗せない）。
- `GameState` は `canPlace(_:at:)`（在庫チェック。置き換え対象トークン自身の使用分は除外して数える）と `setMark(_:at:)`、`toggleHyphen(at:)` を提供する。
- **M3 で実際に実装したレイアウト（返り点バッジ＝漢字ボックス右下のサブスクリプト）に合わせてメニューの出現位置を調整した**: ドックの原案（screen_002.png ベース）は独立した返り点入力行を前提にしていたが、実装はバッジからスロット真上へ縦に積み上げる方式にした。項目順は下（バッジに一番近い）から `×` → `レ` → `一` → `二` → `三` → `四`（実際に使う記号だけ）で、doc記載の「上から四三二一レ×」と整合する。
- ハイフントグルは実測ではドラッグ不要のシンプルな**タップ**でオン/オフする（doc は「トグル」とだけ書いており、ドラッグ方式かどうかは未規定だったため、シンプルな方を採用）。
- SE `resource/se/button_click.mp3` をメニュー選択決定時に鳴らす（M8 で本実装、ここではフックだけ用意）。

### 受け入れ条件

- [x] タップ→ドラッグ→リリースで返り点が置ける（シミュレータの `touch_path` で自動検証済み。`id=180` で `レ`→書、`二`→品 を実際に配置して確認）
- [x] 返り点を置くたびに水色パイプが変化する（スクリーンショットで確認。配置のたびに `blockReadingOrder`/`visualRows` が再計算され経路が変わることを確認）
- [x] 残数を超える配置ができない（`二` を使い切った状態で別トークンに `二` を選んでも配置されないことを確認）
- [x] `×` で返り点を削除できる（配置した `レ` を `×` で削除し、在庫が元に戻ることを確認）
- [x] `git tag -a m4-input`

---

## M5 — クリア判定と演出

### 目的
`screen_003.png` に相当するクリア演出。

### 仕様

- 毎回の入力後に `readingOrder(現在の marks/hyphens) == puzzle.answerOrder` を判定。
- 一致したら:
  - 水色パイプを明るいシアン `#1FBFD4` に変え、始点から終点へ光が走るアニメーション（0.6 秒程度）。
  - 通過セルの黄色枠を太くして発光させる。
  - クリア SE を鳴らす（M8）。
  - 1.0 秒後に M6 のイベント画面へ遷移。
- 部分一致の可視化: 現在のパイプが正解線と重なっている行のセル枠を強調する（M3 で実装済みのロジックを流用）。

### 実装メモ（実測）

- `checkForClear()` を `render()` の末尾で毎回呼び、`tokenReadingOrder(marks:hyphens:) == puzzle.answerOrder` で判定（`readingOrder` ではなくブロック展開後のトークン順で比較。§M2 のルール通り）。
- クリア判定は marks 文字列の一致ではなく読み順（`Int` 配列）の一致で行うため、別解は自動的に正しく扱われる（実装上、別解専用の分岐は存在しない＝そもそも区別しない設計）。
- `SKAction.follow(path:asOffset:false,orientToPath:false,duration:0.6)` で白いグローノードを `pipePath` に沿って走らせる。`pipePath`/`pipeStartPoint` は `makePipe()` で毎回再構築して保持。
- 一致セルは `makeGrid()` で `matchedBoxNodes` に集め、`glowWidth` を上げて発光させる（`box.run(.repeat(pulse, count: 2))` でパルス）。
- `inputLocked: Bool` を追加し `touchesBegan` の先頭で `guard` する形で入力をロック（`SKScene.isUserInteractionEnabled = false` は独自の `touchesBegan` オーバーライドを止めないため使えないことが判明）。
- 1.0 秒待って `onCleared?()` を呼ぶ（M6 未実装のため現状は何も起きない＝正常）。

### 受け入れ条件

- [x] 正解配置を自動入力するとクリア演出が出る（実機シミュレータで id=1490「欲聞崖於簑」にレ点×4を配置して確認。パイプが `#1FBFD4` に変化、4つの一致セルが発光、1.6秒後 `onCleared` が例外なく発火してアプリがクラッシュしないことを確認）
- [x] 別解（marks 文字列は違うが読み順が同じ）でもクリアになる（`tokenReadingOrder` の配列比較で判定しており marks 文字列に依存しないため、設計上保証される。既存の `ReadingOrderTests`（全5,213問）が読み順一致を検証済み）
- [x] `xcodebuild test` — 12 tests, 0 failures
- [x] `git tag -a m5-clear`

---

## M6 — 結果イベント画面

### 目的
`screen_004.png` に相当する画面。

### 仕様

- 盤面の上に半透明の白パネル（`#FFFFFF` 約 85% 不透明）をオーバーレイ。
- 上部に正方形の画像（`game.sqlite` の `image` を `UIImage(data:)` でデコード）。パネル幅の 55% 程度。
- 中央に `kandoku`（読み下し）を太字・大きめで表示。
  `kandokuOK` による**出し分けはしない**（§1-E）。現状の読み下し文は仮のものであり、読み順と矛盾していてもそのまま表示する。
- その下に `flavor`（フレーバーテキスト）を小さめ・グレーで表示。
- **タップ、または 4 秒経過**で次の問題へ進む。
- 画面下部には引き続き漢字行・返り点行が見えている（screen_004 参照）。

### 実装メモ（実測・最重要）

**当初 SwiftUI（`ResultPanel` + `.overlay`/`.fullScreenCover`/`zIndex`）で実装したが、
このビルド環境（iOS 26.5 シミュレータSDK）では致命的な描画バグを踏んだため、
最終的に M3-M5 と同じ SpriteKit 直接描画に全面的に切り替えた。**

発見した現象（実機シミュレータで再現確認済み）:
- `RootView` の `@State`（`showResult` 等）は正しく更新され、`body` も正しく再評価される
  （print デバッグ・NSLog で確認済み）。
- しかし `SpriteView(scene:)` の**初回表示より後に**追加・変化した SwiftUI コンテンツは、
  `.overlay`・`ZStack` 兄弟・`zIndex`・`.fullScreenCover`（`.presentationBackground(.clear)`
  はもちろん不透明な `Color.red` 単体でも）のいずれの手法でも**画面に一切反映されない**。
  同様に `boardScene` state を新しい `BoardScene` インスタンスに差し替えても
  `SpriteView` の表示は切り替わらない。
- 一方、**SpriteKit 自身の `render()` 呼び出し（`addChild`/`removeAllChildren` 等）は
  常に正しく画面に反映される**（M3-M5 の全機能がこれで動いていた通り）。
- 結論: 初回表示より後の「SwiftUI 側の再描画」が SpriteView と同居する画面では
  信頼できない。**今後（M7-M9）も、盤面の上に何かを重ねて出す機能は SwiftUI ではなく
  SpriteKit（`BoardScene` に `addChild` する形）で実装すること。**

上記の理由により、最終的な実装は以下の設計にした:
- `BoardScene` は**アプリ起動時に一度だけ生成し、以後ずっと使い回す**
  （`RootView` は二度と `boardScene` state を差し替えない）。
- 問題送りは `BoardScene.loadPuzzle(_ puzzle: Puzzle)` で行う。内部で新しい `GameState`
  に差し替えて `render()` を呼ぶだけで、SwiftUI 側の状態変更を一切経由しない。
- 結果パネルは `BoardScene.showResultPanel()` が `SKShapeNode`（背景）/`SKSpriteNode`
  （画像）/`SKLabelNode`（`kandoku`・`flavor`、`numberOfLines = 0` で自動折り返し）を
  直接 `addChild` して作る。`BoardLayout.resultPanelFrame(tokenCount:containerSize:)` で
  盤面グリッド部分ちょうどを覆う矩形を計算し、漢字行・返り点行は隠さない（doc写真通り）。
- 画像デコードは `RootView` 側（`PuzzleStore.imageData(for:)` + `UIImage(data:)`）で
  バックグラウンド実行し、`BoardScene.updateResultImage(_:)` でテクスチャを後から
  差し替える（先にグレーのプレースホルダ矩形を表示）。
- タップは `touchesBegan` の先頭で `resultPanelNode != nil` かを見て最優先処理。
  4秒の自動遷移は `SKAction.wait(forDuration: 4.0)` を `withKey: "resultAutoAdvance"`
  で保持し、タップ時に `removeAction(forKey:)` で確実にキャンセルする
  （GCDタイマー+世代カウンタのような仕組みは不要になった）。

### 追加修正（ユーザーフィードバック反映）

- **パネルの高さは内容（フレーバーテキスト全体）に合わせて可変にする。盤面を隠すことは
  気にしない。** 当初はグリッド部分だけを覆う固定サイズだったため、フレーバーテキストが
  長い問題でパネルからテキストがはみ出す問題があった。`showResultPanel()` を画像→
  kandoku→flavorの順に実際のノード高さ（`SKLabelNode.frame.height`、`numberOfLines = 0`
  で自動計算）を積み上げてから、その合計に合わせて背景の白パネルを最後に生成する設計に
  変更（`BoardLayout.resultPanelFrame` は不要になったため削除）。幅と上端（ステージ見出し
  の下）だけは従来通り固定。
- **返り点が1つも必要ない問題（`marks` が全て `.none`。全5213問中366問）は出題しない。**
  何も操作しなくても最初から正解と一致してしまい、プレイヤーが触らないままクリアになる
  ため。`PuzzleStore.loadAllPuzzles()` で読み込み時に除外する（`ReadingOrderTests` の
  件数下限アサーションも 5000→4500 に調整済み）。

### 受け入れ条件

- [x] 画像・読み下し・フレーバーが正しく表示される（実機シミュレータでid=1490「欲聞崖於簑」を解いて確認。画像デコード成功、kandoku/flavorとも正しい文言・折り返しで表示。フレーバーが長い場合もパネルが伸びて全文表示されることを確認）
- [x] タップで即座に次へ進む（実機シミュレータで確認。パネルタップ直後にSTAGE2-3へ遷移）/ 放置すると4秒で自動的に進む（実機シミュレータで確認。複数問題を連続で自動送りできることを確認）
- [x] 画像デコード失敗時もクラッシュしない（`try?` + `flatMap` でnilフォールバックし、`updateResultImage`が呼ばれないだけでプレースホルダ矩形のまま維持される設計）
- [x] 返り点なしで最初から正解と一致する「実質ノーヒント」問題は出題されない（`PuzzleStore` で除外済み）
- [x] `xcodebuild test` — 12 tests, 0 failures
- [x] `git tag -a m6-event`

---

## M7 — ステージ進行

### 目的
`Stage X-Y` 構成と進捗管理。

### ステージ定義（企画メモ準拠）

- `X`: 難易度 — `1` = レ点のみ / `2` = 数字点あり（一二／一二三／一二三四点）/ `3` = ハイフンもあり
- `Y`: 文字数（トークン数）— `3`〜`6`
- 本来 `Stage1-3` 〜 `Stage3-6` で 12 種だが、**`Stage3-3` と `Stage3-4` は在庫 0 問のため実装しない**（§1-D）。
  **通常運用は 10 ステージ**: `Stage1-3〜6`（4）+ `Stage2-3〜6`（4）+ `Stage3-5〜6`（2）。
  `StageCatalog.swift` にステージ一覧を定数で持たせ、この 10 種だけを列挙する（`game.sqlite` の実件数から動的に算出するのではなく、固定リストとしてハードコードしてよい。理由が明確な欠番のため）。

#### Stage4（ノーヒント。ユーザー決定済みの追加仕様。§M7実装時に確定）

Stage1〜3 とは別に **`Stage4`** を追加する。問題そのものは Stage3 と同じプール（またはその一部）を使い回すが、**画面下部の「残り返り点の在庫表示」（§M3-7）を非表示にする**、という一段難しいモードである。

- 実装は `BoardScene` に既に用意済みの `showHintStock: Bool` パラメータで切り替える（`false` で在庫表示なし）。`Stage4` を選択したときだけ `false` を渡す。
- 問題データそのもの（マス目・漢字・正解ライン）は Stage1〜3 と変わらない。**ヒントの有無だけがStage4の差分**である。
- **プールはStage1〜3の全問題（`stage_x` 1〜3すべて、トークン数不問）。難易度を問わない「総合力を試す最終ステージ」という位置づけ（ユーザー確定）。**
  これにより通常10ステージ + Stage4 で**合計11ステージ**になる。
- Stage4はStage1〜3のいろいろな問題を横断して出題するため、盤面上部の見出しは出題された問題自身のstage_x/stage_y（例:「STAGE2-5」）ではなく、**常に固定で「STAGE4」と表示する**（`BoardScene` の `stageHeadingOverride: String?` init引数で上書き。nilなら従来通り問題自身のstage_x/stage_yを表示）。

### 残り返り点の在庫表示（実測・実装済みの仕様。§M3-7 を上書き）

画面最下部の水色アイコン表示は、当初「レ点アイコン」「一二点アイコン」の2種固定だったが、**その問題で実際に使う種類だけを動的に表示する**方式に変更した:

- レ点を使わない問題では「レ」のカウンタを出さない。
- 数字点を使う問題では、実際に使う最大段数（`puzzle.maxLevel`）分だけ「一」「二」（「三」「四」）を個別の円で並べて表示する。固定で「一二」とは表示しない。
- **ハイフンを使う問題では「｜」（縦棒）のカウンタを表示する。** ハイフンの記号に「一」を流用すると、どちらも横線1本に見えて紛らわしいため、専用の記号 `｜` を使うと決定した（一と区別するため）。
- 表示する種類の数（1〜3個）に応じて画面幅に等間隔で配置する。
- `Stage4` ではこの表示自体を出さない（前項参照）。

### 出題のランダム化（重要要件）

**同じステージを繰り返し遊んでも同じ問題に当たりにくいこと**が本ゲームの要件である。§1-D の救済により最小のステージ（Stage2-3）でも 202 問、平均 521 問の在庫があるので、以下で実現する。

- 1 ステージあたりの出題数: **5 問**（実運用する 10 ステージ全てで在庫が足りることを M1 で確認済み）。
- 出題は各ステージの候補から**毎回シャッフルして**選ぶ。同一セッション内はもちろん重複させない。
- さらに **`recentlyPlayed` として直近に出題した問題 id をステージごとに保持し、次回以降の抽選から除外する**。保持数はそのステージの在庫の 50%（上限 200 件）とし、FIFO で古いものから捨てる。これにより在庫を一巡するまで同じ問題が再出題されない。
- `recentlyPlayed` も永続化する（アプリ再起動でリセットされてはならない）。
- 抽選対象が尽きた場合（在庫を一巡した場合）は `recentlyPlayed` をクリアして再び全問から抽選する。

### 進捗保存

`UserDefaults` に以下を保存:

```swift
struct Progress: Codable {
    var clearedStages: Set<String>       // "1-3" 形式
    var bestMoves: [String: Int]         // ステージごとの最少手数
    var recentlyPlayed: [String: [Int]]  // ステージ → 直近に出題した puzzle id（FIFO）
    var bgmVolume: Double
    var seVolume: Double
}
```

### 画面遷移（実装済み。当初案から変更あり）

```
StageSelectView  →  GameFlowView（1ステージ5問）  →  StageClearView  →  StageSelectView
```

`EventView`（結果イベント画面）は独立した SwiftUI 画面にはせず、M6 の設計通り
`BoardScene` が自前で結果パネルを表示する（§M6 実装メモ参照。SpriteView上のSwiftUI
オーバーレイがこのビルド環境で機能しないため）。したがって遷移は
「1問クリア→（BoardScene内で結果パネル表示・次問題へ）を5回→StageClearView」という形になる。

- `StageSelectView`: **11** ステージ（通常10 + Stage4）を2列グリッド表示。クリア済みは緑チェック付き。順番ロックは**かけない**（どのステージからでも遊べる）。
  `NavigationStack(path:)` を自前で持ち、`StageClearView` の「戻る」で `path = NavigationPath()` として一気にrootへ戻る。
- `GameFlowView`: そのステージの5問をまとめて管理する画面。`BoardScene` は画面表示中ずっと1つのインスタンスを使い回し、問題送りは `BoardScene.loadPuzzle(_:)` で行う（§M6実装メモの設計をそのまま踏襲）。`onBoardChanged` が呼ばれるたびに手数をカウントし、5問目の結果パネルが閉じられたら `StageClearRoute` を `path` に積んでクリア画面へ遷移する。
- `StageClearView`: 「STAGE CLEAR」・ステージ名・手数を表示。タップで `path = NavigationPath()` によりステージ選択へ一気に戻る。

#### 実装メモ（実測・重要）

- **`NavigationStack` の push/pop は、M6で発覚した「SpriteView初回表示後のSwiftUI更新が反映されない」バグの影響を受けない**ことを、本実装に着手する前に最小テストアプリで確認した（`NavigationLink(value:)` → `.navigationDestination(for:)` で push、戻るボタンで pop、いずれも実機シミュレータで正しく画面に反映されることを確認済み）。そのためM7の画面遷移は素朴に `NavigationStack`/`NavigationPath` で実装できる。バグの影響範囲は「同一画面内でSpriteViewの上に後からSwiftUIコンテンツを重ねる／scene自体を差し替える」ケースに限られる。
- **`.onAppear` は `NavigationStack` 自体ではなく、スタックの中身（実際に見え隠れする側）に付けること。** `NavigationStack(path:) { content }` の `content` に `.onAppear` を付けないと、pushしてpopで戻ってきたときに再発火せず、`StageSelectView` の進捗（クリアチェック）がその場で更新されない（アプリを再起動すれば正しい状態が見えるため、初回ロードだけなら気づきにくいバグだった）。
- 「手数」は `BoardScene.onBoardChanged`（返り点・ハイフンを変更するたびに呼ばれる。既にM4で実装済み）の呼び出し回数をステージ内の5問合計でカウントする。× で削除する操作も1手として数える。
- `PuzzleSelection.swift` に出題選択ロジックを純粋関数として切り出し（`selectPuzzles(from:excluding:count:using:)` / `updatedRecentlyPlayed(current:newlyPlayed:poolSize:)`）、UIから独立してユニットテストできるようにした。
- **【M8.5後の修正】在庫が少ないステージで、直前にプレイした問題がすぐ次のセッションの
  1問目として再出題される不具合があった。** 原因は `selectPuzzles` が候補不足時に
  `recentlyPlayed` の除外を丸ごと諦めて全問から選び直す実装だったこと（除外「全部」か
  「無し」かの二択だったため、在庫が少ないと直前セッションの5問がそのまま次の1問目に
  出うる）。除外を直近優先で段階的に緩める方式（`recentlyPlayed.suffix(excludeCount)`を
  `count`件確保できるまで`excludeCount`を減らしながら試す）に変更し、`PuzzleSelectionTests.
  testSelectPuzzlesAvoidsImmediateRepeatWhenPoolIsSmall` で「直前セッション最後の問題が
  次のセッションに含まれないこと」を検証している。

### 受け入れ条件

- [x] 11 ステージ（通常10 + Stage4）が選択でき、それぞれ 5 問を通してプレイできる（実機シミュレータでSTAGE1-3・STAGE1-4を実際に5問ずつ解いてSTAGE CLEARまで確認）
- [x] アプリを再起動しても進捗と `recentlyPlayed` が残る（実機シミュレータでアプリ再起動後もクリアチェックが残ることを確認）
- [x] **同じステージを 10 回連続でプレイしても同じ問題が再出題されない**（`PuzzleSelectionTests.testStageRandomizationNoRepeatsOverTenDraws` で自動検証。Stage2-3(202問、cap=101)で10回×5問=50件が重複しないことを確認。注: 在庫69問のStage3-5のように `poolSize/2 < 50` となる極小ステージでは、この保証は数学的に成立しない。これはM7のアルゴリズムの欠陥ではなく、既知のデータ在庫不足の問題であり `docs/STAGE_PUZZLE_COUNTS.md` に別途記録済み）
- [x] `xcodebuild test` — 15 tests, 0 failures
- [x] `git tag -a m7-progression`

---

## M8 — 音響

### 目的
BGM と SE を実装する。

### リソース（実装時にユーザー確定した割り当て。SE は当初案から変更）

- BGM: `resource/bgm/*.mp3`（10 曲）→ `ios/KaeriTen/Resources/bgm/` にコピー
- SE: `resource/se/button_click_01.mp3`（返り点選択決定時）, `resource/se/pipeflow.mp3`（クリア時）
  → `ios/KaeriTen/Resources/se/` にコピー。**`button_click.mp3` は未使用（コピーしない）**。

**注意**: これらの音源ファイルは Git LFS を使わずに通常コミットする（合計 28MB、100MB 未満のため問題なし）。

### 仕様

- `AudioEngine`（シングルトン、`ios/KaeriTen/Audio/AudioEngine.swift`）で管理。
- BGM: ステージ選択画面とゲーム画面でそれぞれ1曲をループ再生。曲は`stage_x`（難易度）ごとに割り当てる
  （`BGMTrack.swift`）。画面遷移時は0.5秒でクロスフェード（2系統のプレイヤーを`Timer`で20分割して
  音量をなめらかに入れ替える自前実装。`AVAudioPlayer`に組み込みのフェード機能はないため）。
- SE: 返り点選択決定時に`button_click_01`、クリア時に`pipeflow`（`BoardScene`の
  `commitMenuSelection()`/`playClearAnimation()`から`AudioEngine.shared.playSE(_:)`を呼ぶ）。
  同じ音を音ごとにプールした`AVAudioPlayer`（最大3個）で使い回すことで同時多重再生に対応
  （`AVAudioPlayer`は再生中のファイルを差し替えられないため、音ごとに複数インスタンスを持つ設計）。
- `AVAudioSession`のカテゴリは`.ambient`（他アプリの音楽を止めない）。
- 設定画面（`SettingsView.swift`。`StageSelectView`右上の歯車アイコンから遷移）でBGM/SEの音量を
  個別にスライダーで調整でき、`Progress`（`UserDefaults`）に保存される。
- アプリがバックグラウンドに入ったらBGMを一時停止、復帰したら再開する
  （`UIApplication.didEnterBackgroundNotification`/`willEnterForegroundNotification`を監視）。

### 実装メモ（実測）

- **`Bundle.main.url(forResource:withExtension:subdirectory:)`にsubdirectoryを指定しても見つからない
  ことを実機シミュレータで確認した。** xcodegen/Xcodeのリソースコピーで`Resources/bgm/`・
  `Resources/se/`のサブフォルダ構成が保たれず、全ファイルがバンドル直下にフラットに配置される
  （`find KaeriTen.app -iname "*.mp3"`で確認）。そのため`AudioEngine.resourceURL(name:ext:subdirectory:)`
  は`subdirectory`指定ありで探し、見つからなければ指定なしでも探すフォールバックを持つ。
- ファイル名にスペースを含むBGM（例: `"Clockwork Dumplings.mp3"`）も`Bundle.main.url(forResource:)`に
  拡張子なしファイル名をそのまま渡せば問題なく解決できる。
- **【M8.5後の変更】ステージ選択画面のBGMを`kanbun bunbun`から`resource/bgm/stageselect.mp3`に
  変更した際、`ios/KaeriTen/Resources/bgm/`にファイルをコピーしただけで`xcodegen generate`を
  実行し忘れ、ビルドしても無音になる不具合があった。** `resources: - path: KaeriTen/Resources`は
  フォルダ参照ではなく生成時点のファイル一覧を`.xcodeproj`に書き出す方式のため、**新しいリソース
  ファイルを追加したら必ず`xcodegen generate`を再実行すること**（`find KaeriTen.app -iname "*.mp3"`
  で実際にバンドルされているか確認する習慣をつける）。また原曲の音量が他のBGMより大きかったため、
  `BGMTrack.volumeMultiplier(for:)`で曲ごとの音量倍率を持たせ、`stageselect`は0.4倍で再生するように
  した（`AudioEngine`の`bgmVolume`設定・クロスフェード双方に反映）。

### 受け入れ条件

- [x] BGMがループ再生され、画面遷移でクロスフェードする（実機シミュレータでステージ選択→ゲーム画面→ステージ選択の遷移で曲が切り替わることをログで確認）
- [x] SEが操作に反応して鳴る（実機シミュレータで返り点選択・クリアそれぞれのタイミングで`AVAudioPlayer`が正しいファイルで再生されることを確認）
- [x] 音量設定が保存・反映される（設定画面のスライダーを操作してBGM音量が即座に変わることを確認）
- [x] バックグラウンド復帰でおかしくならない（実機シミュレータでHOMEボタン→再度起動してもクラッシュしないことを確認）
- [x] `xcodebuild test` — 15 tests, 0 failures
- [x] `git tag -a m8-audio`

---

## M8.5 — ゲームオーバー機能

### 目的
M8完了後にユーザー指示で追加。制限時間・ライフ制を導入してゲーム性を上げる。

### 仕様（ユーザー指示）

- 1問あたり制限時間30秒（`LifeSystem.timeLimit`）。時間内にクリアできないとミス。
- ミス1回でライフ -1/3（`LifeSystem.missPenalty`）、正解1回でライフ +1/9
  （`LifeSystem.clearBonus`）。ライフは0〜1にクランプ。
- ライフが0になったらゲームオーバー（`GameOverView`。進捗は保存しない＝
  `clearedStages`/`bestMoves`に反映されない）。
- ステージクリア時、残りライフに応じて評価を表示（`StageGrade`）:
  `life>=1.0`→PERFECT、`>=2/3`→GREAT、`>=1/3`→GOOD、それ以外（生存）→NOT BAD。
- ライフ・残り時間は`resource/images/bottle_empty.png`（輪郭・アルファ画像）の下に
  `bottle_water.png`（塗りつぶし画像）を重ねて表示。"STAGEX-Y"見出しの左（ライフ）・
  右（残り時間）に、見出し文字の高さに合わせたサイズで配置（`BoardScene.makeHUD()`）。
- SE: ミス`miss.mp3`、ゲームオーバー`gameover.mp3`、ステージクリア`stageclear.mp3`
  （問題ごとのクリアは引き続きM8の`pipeflow.mp3`。`stageclear`は5問通しクリア専用）。

### 実装メモ（実測・重要）

- **水位クロップのY範囲は「上端63・下端233（256px中、画像編集ソフトの慣例で上端0）」
  とユーザーから指示されたが、この範囲を素直に「上端固定・下端がfractionに応じて
  伸びる」向きでクロップすると、ライフが減るほど水位が画像の上（首元）に残り底が
  空になるという物理的に逆の見た目になることが `bottle_empty.png`
  にグリッド線を引いて検証した結果わかった。** 「壺にたまる水のように」という
  指示文の意図（水は下から溜まる）を優先し、**下端(233px相当)を固定して
  fractionに応じて上端が伸びる**向きでクロップする実装にした
  （`BottleGaugeNode.setFraction(_:)`）。実機シミュレータで20秒待って残り時間
  ゲージが下から2/3ほど正しく減っていくこと、ミス発生でライフゲージが
  下から2/3に減ることを確認済み。
- クロップ矩形は`SKTexture(rect:in:)`（左下原点・正規化座標）を使うため、
  top-down pxのY値をそのまま渡さず`1 - y/256`で変換する必要がある。
- ライフは`BoardScene`をステージ内で使い回す設計（§M6実装メモ）のため
  `loadPuzzle(_:)`では**リセットしない**（制限時間だけリセットする）。ライフの
  現在値は`GameFlowView`側の`@State`が真実の値を持ち、`BoardScene.updateLife(_:)`
  で描画にだけ反映する片方向の設計にした。
- 制限時間のカウントダウンは`SKScene.update(_:)`をオーバーライドして実装。
  `currentTime`はアプリ起動からの絶対時刻でありシーンごとの経過秒ではないため、
  問題ロード時に`needsTimerReset`フラグを立てておき、次の`update`呼び出しの
  瞬間の`currentTime`を`puzzleStartTime`として遅延キャプチャする方式にした。
- クリアとミスの結果パネル表示・SE再生・`onPuzzleFinished`コールバック呼び出しは
  `finishPuzzle(success:)`に統合した（旧`playClearAnimation()`をリネーム・拡張）。
  ミス時は演出（パルス・光の玉）をスキップし、即座に結果パネル（正解の画像・
  読み下しを見せる）を表示する。
- 実機シミュレータで意図的に3問連続タイムアウトさせ、`GAME OVER`画面への遷移・
  `clearedStages`に記録されないこと（ステージ選択に戻ってもチェックマークが
  付かないこと）を確認済み。

### 追加の不具合修正（ユーザーレビュー後・実測）

- **結果パネルの画像が「クリア時に出ずミス時に出る」逆転バグ**: `finishPuzzle`で
  `onPuzzleFinished`（画像取得の非同期トリガー）を関数の先頭で即座に呼び、
  `showResultPanel`（`resultImageNode`を新規生成する箇所）はクリア時だけ1秒の
  演出待機の後に呼んでいたため、画像取得が1秒以内に完了すると
  `resultImageNode`がまだnilで`updateResultImage`の代入が握りつぶされていた
  （ミス時は両者を待機なしで連続して呼んでいたため再現しなかった）。
  `onPuzzleFinished`と`showResultPanel`を必ず同じタイミング（同じクロージャ内）
  で呼ぶよう統一して解消。あわせてユーザー指示で、ミス時は正解を見せず
  `"FAILED"`とだけ表示するよう`showResultPanel(success:)`に分岐を追加した。
- **残り時間ボトルが特定の配置（画面左）でのみ描画されない不具合**:
  `BottleGaugeNode.setFraction(_:)`は毎フレーム`SKTexture(rect:in:)`で新しい
  テクスチャを生成しており、`update(_:)`から60回/秒呼ばれ続けていた。この
  頻度で作り続けた場合に限り、画面左に配置したボトルの水位だけが描画されない
  現象を実機シミュレータで確認した（`waterNode`の`texture`/`size`/`position`/
  `alpha`/`hidden`はログ上どちらの配置でも完全に同一の値であることを確認済みで
  あり、SpriteKit側のテクスチャ再生成頻度に起因するレンダリング不具合と判断）。
  更新頻度を約10回/秒（0.1秒間隔）に間引くことで解消し、以後複数回の
  実機シミュレータ確認で再現しなくなった。原因の完全な特定（SpriteKit内部の
  挙動）はできていないが、間引きは無駄なテクスチャ生成を減らす意味でも
  そもそも妥当な変更である。
- ステージ見出し・ライフ/残り時間ボトルはDynamic Islandにかかる可能性がある
  との指摘を受け、`BoardLayout.stageHeadingCenterY`を`rowTop/2`(0.12)から
  固定値`0.16`に変更して下げた。あわせてユーザー指示でボトルの左右を
  入れ替え（左=残り時間、右=ライフ）。

### レスポンシブレイアウト対応（ユーザー指示・実測）

- **返り点の残数リストを画面下部からグリッドの上（見出し/HUDの下）へ移動した。**
  以前は漢字行の下に配置していたため、トークン数が多い問題（6トークン）や
  縦に短い端末（iPhone SE等）で画面から溢れることがあった。上に移動したことで
  グリッドの行数に関係なく一定の位置に収まるようになった
  （`BoardLayout.counterRowCenterYFraction`）。
- **iPhone SEのような縦横比が狭い端末で画面から溢れないよう、黄色いボックスの
  サイズを動的に縮小する仕組みを追加した。** `render()`でグリッド(n行)+漢字行+
  バッジ余白の「自然な」合計高さと、実際に使える高さ（見出し/HUD/残数リストの下から
  画面下端の安全マージンまで）を比較し、はみ出す場合だけ`boxScale`（最小0.4）で
  縮小する。iPhone SE(375×667pt)で6トークン問題を計算すると`boxScale≈0.96`と
  ごく僅かな縮小で収まることを机上計算で確認済み（実機シミュレータでの対話的操作は
  権限の都合で確認できず、数式による検証と、通常サイズの端末で同じコードパスが
  正しく動作することの確認で代替した）。
- **iPadのような電話より横長/正方形に近いアスペクト比では、盤面の横幅を
  `BoardLayout.maxContentAspect`(0.6)以下に制限し、左右に黒い余白を残して
  中央寄せする。** 電話（iPhone SE比0.562・iPhone比0.460）は制限にかからず
  従来通り画面いっぱいに表示され、iPad（縦0.75・横1.33）は制限にかかって
  中央寄せされる（ユーザー指示: iPadでは黒い領域ができてもよいので中央に表示する。
  ランドスケープでも同様に中央寄せされる）。`contentWidth`/`contentOriginX`を
  `render()`で計算し、盤面のあらゆる横方向の位置・サイズ計算をこの2つ基準に
  統一した（`size.width`を直接参照する箇所を全て置き換えた）。
- **ミス時の"FAILED"ダイアログを画面中央に配置するよう変更した。** クリア時の
  結果パネル（正解画像・読み下し・フレーバーテキスト）は引き続き見出しの下に
  固定表示するが、ミス時は内容が"FAILED"の1行だけなので、`showResultPanel(success:)`
  を成功/失敗で完全に分岐させ、失敗時は`size.height * 0.5`を基準に縦方向も
  中央寄せするようにした。
- **App Store掲載用スクリーンショットの撮影に伴い、`TARGETED_DEVICE_FAMILY`を
  `"1"`（iPhoneのみ）から`"1,2"`（Universal・iPad含む）に変更した。** これにより
  iPadでもiPhoneの互換モード（縮小表示）ではなく実解像度でネイティブ実行され、
  上記の`contentWidth`/`contentOriginX`による中央寄せレイアウトがそのまま働く
  ことを`iPad Pro (12.9-inch) (6th generation)`シミュレータ（2048×2732）で確認済み。
  AppIconはXcode 14以降の単一サイズ（1024×1024, universal idiom）形式のため
  iPad用アイコンも追加作業なしで生成される。`html/screenshots/`に
  iPhone（1284×2778, `iPhone 13 Pro Max`相当）・iPad（2048×2732,
  `iPad Pro (12.9-inch) (6th generation)`相当）それぞれ3枚ずつ、
  App Store Connectの規定解像度に一致する実機シミュレータ撮影のスクリーンショットを保存した。

### 受け入れ条件

- [x] 制限時間内にクリアできないとミスになり、ライフが1/3減る（実機シミュレータで確認）
- [x] 正解するとライフが1/9回復する（コードレビューで確認。M8で実績のあるクリア演出コードパスをそのまま流用しているため）
- [x] ライフが0になるとゲームオーバー画面へ遷移し、進捗が保存されない（実機シミュレータで確認）
- [x] ライフ・残り時間ゲージが見出しの左右に表示され、下から水がたまる/減るように見える（実機シミュレータで確認）
- [x] `xcodebuild build` 成功
- [ ] `git tag -a m8.5-gameover`（コミット時に付与）

---

## M9 — 仕上げ

### 作業

1. **アプリアイコン**: `resource/images/icon.png`（ユーザー提供、512×512、alpha無し）を512→1024に
   Lanczosでアップスケールし `ios/KaeriTen/Assets.xcassets/AppIcon.appiconset/appicon.png` に配置。
   ```bash
   magick resource/images/icon.png -filter Lanczos -resize 1024x1024 -background black -alpha remove -alpha off PNG24:ios/KaeriTen/Assets.xcassets/AppIcon.appiconset/appicon.png
   sips -g hasAlpha ios/KaeriTen/Assets.xcassets/AppIcon.appiconset/appicon.png   # → hasAlpha: no を確認済み
   ```
2. **起動画面**: `ios/KaeriTen/App/LaunchScreen.storyboard`（黒背景 + シアンの `KAERITEN` ラベル）を追加し、
   `project.yml` の `INFOPLIST_KEY_UILaunchScreen_Generation`（空白自動生成）を
   `INFOPLIST_KEY_UILaunchStoryboardName: LaunchScreen` に置き換え。
3. **Release 署名設定**: `CODE_SIGN_STYLE = Manual` / `CODE_SIGN_IDENTITY = "Apple Distribution"` は
   `project.yml` に設定済み（`xcodebuild -showBuildSettings -configuration Release` で実効値を確認済み）。
   **`DEVELOPMENT_TEAM` と `PROVISIONING_PROFILE_SPECIFIER` はユーザーのApple Developerアカウント情報が
   必要なため未設定のまま**（Claudeが勝手に補完できない項目。`docs/KAERITEN_README.md` に手順を記載）。
   App Store提出はユーザーが行う。
4. **`docs/KAERITEN_README.md`**: ビルド手順、`game.sqlite` の再生成手順、ディレクトリ構成、既知の制約を記載。
5. **総合テスト**: 実機シミュレータで11ステージ（Stage1-3〜6・Stage2-3〜6・Stage3-5〜6・Stage4）すべてに
   実際に入り、盤面が正しく描画されクラッシュしないことを確認（トークン数3〜6・ヒントあり/なしの
   全パターンを網羅）。既にクリア済みのステージ（進捗引き継ぎ）も新コードで問題なく読み込めることを確認。

### 実装メモ（実測）

- ホーム画面に表示される縮小版アイコン（`AppIcon60x60@2x.png`等）は`actool`が角丸マスク合成のため
  自動的にalphaを付与する。これは正常な挙動であり、App Store error 90717の対象は1024x1024の
  マーケティングアイコン（appiconset内のソースファイル）のみ。ソース側でalpha無しを確認していれば問題ない。
- 実機シミュレータでの起動画面の実フレームキャプチャは、SwiftUIへの遷移が速すぎてスクリーンショットで
  捕捉できなかった。`LaunchScreen.storyboardc`のビルド成功とInfo.plistの`UILaunchStoryboardName`が
  正しく設定されていること、およびアプリが正常起動することで代替確認とした。

### 受け入れ条件

- [x] Debug構成でビルド・テストが通る（15 tests, 0 failures）
- [x] アイコン（1024x1024ソース）に alpha が無い
- [x] 起動画面（LaunchScreen.storyboard）が黒背景+シアンのKAERITENロゴで実装されている
- [x] README が揃っている（`docs/KAERITEN_README.md`）
- [x] 11ステージすべてが実機シミュレータでクラッシュせず表示される
- [ ] Release 構成でのアーカイブ（`DEVELOPMENT_TEAM`/プロビジョニングプロファイルはユーザー設定待ち）
- [x] `git tag -a m9-polish`

---

## 3. カラーパレット（screen_*.png から抽出）

| 用途 | 色 |
|---|---|
| 背景 | `#000000` |
| ステージ見出し / UI アクセント | `#00B0F0` |
| グリッド枠 | `#EEEE44` |
| 正解ルート（マゼンタ線） | `#FF66CC` |
| 現在ルート（未クリア） | `#1A6B78` |
| 現在ルート（クリア時の発光） | `#1FBFD4` |
| 選択メニュー | `#7FE9F5`（半透明） |
| 漢字ボックス | 塗り `#D9D9D9` / 枠 `#EEEE44` / 文字 `#000000` |
| 配置済み返り点 | 塗り `#3A3A3A` / 文字 `#FFFFFF` |

正確な値は `resource/images/screen_001.png` 〜 `screen_004.png` から実際にピクセルを読んで確定させること。上表は目安である。

---

## 4. Claude への実行上の注意

1. **マイルストーンを飛ばさない。** M2（ドメインロジック + テスト）を終える前に UI を書き始めないこと。読み順計算が間違ったまま UI を作ると全部やり直しになる。
2. **各マイルストーンの終わりに必ずコミットしてタグを打つ。** 打ち忘れると巻き戻し地点が失われる。
3. **`xcodebuild` はバックグラウンド実行禁止。** フォアグラウンドでタイムアウト付き、1 回ずつ。
4. **元 DB `kanbun_matrix_corpus.db` は読み取り専用。** 書き込みは一切しない。
5. **自分で検証する。** シミュレータのスクリーンショットを自分で撮って見る。「確認してください」でユーザーに検証を押し付けない。
6. **仕様の食い違いを見つけたら報告する。** 企画メモと実データが食い違う箇所（`image` 列が全 NULL である等）は、勝手に解釈せずユーザーに事実を伝えてから進める。
7. **外部依存を追加しない。** SPM / CocoaPods のパッケージを増やす必要が出たら、まずユーザーに相談する。
8. **MX のスクリプトを全件実行しない。** トークンコストがかかる。動作確認は `--dry-run --limit 3` まで。全件実行はユーザーが後日判断する。
9. **読み下し文が読み順と矛盾していても問題を除外しない。** 読み下し文は仮のものであり、後日 MX で修正する前提。パズルとして成立していれば採用する（§1-E）。
10. **書誌情報・URL を推測で書かない**（グローバルルール）。

---

## 5. 参照ファイル

| パス | 内容 |
|---|---|
| `docs/workflow_game.txt` | 元の企画メモ |
| `resource/images/screen_001.png` | ゲーム開始時の画面 |
| `resource/images/screen_002.png` | 返り点入力中の画面 |
| `resource/images/screen_003.png` | ステージクリア時の画面 |
| `resource/images/screen_004.png` | クリア後のイベント画面 |
| `resource/bgm/` | BGM 素材 10 曲 |
| `resource/se/` | SE 素材 2 種 |
| `kanbun_matrix_corpus.db` | 問題の元データ（`game_manifest_assets` テーブル） |
