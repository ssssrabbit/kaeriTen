import Foundation

/// 返り点の配置からブロック単位の読み順を求める（doc §1-B / tools/build_game_db.py の
/// simulate_tokens を忠実に移植したもの。ハイフンは含まない = 呼び出し側でブロック化する）。
///
/// ゲーム中は途中経過（不完全な返り点配置）でも常に描画できる必要があるため、
/// アルゴリズムが行き詰まった場合は例外を投げず、残ったブロックを左から右へ
/// 追加して必ず `marks.count` 個の完全な順列を返す。
func readingOrder(marks: [Mark]) -> [Int] {
    let m = marks.count
    guard m > 0 else { return [] }

    var read = [Bool](repeating: false, count: m)
    var out: [Int] = []
    out.reserveCapacity(m)

    func resolveReChain(_ p: Int) {
        var k = p - 1
        while k >= 0 && marks[k] == .re && !read[k] {
            out.append(k)
            read[k] = true
            k -= 1
        }
    }

    var i = 0
    var guardCount = 0
    let guardLimit = 8 * m + 8

    while out.count < m {
        guardCount += 1
        if guardCount > guardLimit || i >= m {
            break
        }
        if read[i] || marks[i].isSkippedOnForwardScan {
            i += 1
            continue
        }
        out.append(i)
        read[i] = true
        if marks[i] == .ichi {
            resolveReChain(i)
            for level in Mark.numberedTargets {
                var found: Int?
                var cand = i - 1
                while cand >= 0 {
                    if !read[cand] && marks[cand] == level {
                        found = cand
                        break
                    }
                    cand -= 1
                }
                guard let j = found else { break }
                out.append(j)
                read[j] = true
                resolveReChain(j)
            }
        } else {
            resolveReChain(i)
        }
        i += 1
    }

    // フォールバック: 不完全な返り点配置（プレイ中）では行き詰まりうる。
    // 未読ブロックを左から右へ追加し、常に完全な順列を返す。
    if out.count < m {
        for idx in 0..<m where !read[idx] {
            out.append(idx)
        }
    }
    return out
}

/// トークン列をハイフンでブロックに分割する。hyphens[k] == true なら
/// トークン k と k+1 は同一ブロック。
func blocksFromHyphens(tokenCount: Int, hyphens: [Bool]) -> [[Int]] {
    guard tokenCount > 0 else { return [] }
    var blocks: [[Int]] = [[0]]
    for k in 0..<(tokenCount - 1) {
        if k < hyphens.count && hyphens[k] {
            blocks[blocks.count - 1].append(k + 1)
        } else {
            blocks.append([k + 1])
        }
    }
    return blocks
}

/// ブロック分割と、ブロック単位の読み順（読む順に並んだブロックインデックス列）。
struct BlockReadingOrder {
    let blocks: [[Int]]   // blocks[b] = ブロック b を構成するトークン位置（左→右）
    let order: [Int]      // order[s] = s 番目（0始まり）に読むブロックのインデックス
}

/// 返り点・ハイフンからブロック単位の読み順を求める。
/// 盤面描画（§M3）は行 = ブロック単位のステップとして扱うため、この関数を使う。
/// 正解判定には使わない（`tokenReadingOrder` を使うこと）。
func blockReadingOrder(marks: [Mark], hyphens: [Bool]) -> BlockReadingOrder {
    let n = marks.count
    guard n > 0 else { return BlockReadingOrder(blocks: [], order: []) }
    let blocks = blocksFromHyphens(tokenCount: n, hyphens: hyphens)
    let blockMarks: [Mark] = blocks.map { marks[$0.last!] }
    let order = readingOrder(marks: blockMarks)
    return BlockReadingOrder(blocks: blocks, order: order)
}

/// 盤面描画用の「表示行」。連続して前進するだけの区間は1行にまとめ、
/// 実際に戻り（ジャンプ）が起きた地点で新しい行に分かれる。
struct VisualRow {
    let colStart: Int
    let colEnd: Int
}

/// ブロック単位の読み順を表示行に変換する。
/// doc §M3 実測（screen_001.png のピクセル解析）: 返り点が全く無い初期状態では
/// 6トークン全てが列0→5へ連続的に前進するだけなので1行にまとまり、
/// 「先頭から最後までストレートに読まれるので一直線になる」という仕様と一致する。
/// 一方 id=331 の正解（レ点・一二点あり）では列が連続しない区間ごとに
/// 新しい行が使われ、5行に分かれる（実測と一致）。
func visualRows(for blockOrder: BlockReadingOrder) -> [VisualRow] {
    var rows: [VisualRow] = []
    for blockIndex in blockOrder.order {
        guard blockIndex >= 0, blockIndex < blockOrder.blocks.count else { continue }
        let block = blockOrder.blocks[blockIndex]
        guard let minCol = block.min(), let maxCol = block.max() else { continue }
        if let last = rows.last, minCol == last.colEnd + 1 {
            rows[rows.count - 1] = VisualRow(colStart: last.colStart, colEnd: maxCol)
        } else {
            rows.append(VisualRow(colStart: minCol, colEnd: maxCol))
        }
    }
    return rows
}

/// 返り点・ハイフンからトークン単位の読み順を求める。ゲームの正解判定は
/// 必ずこの関数の結果を使うこと（文字列一致による判定は禁止。§M2）。
func tokenReadingOrder(marks: [Mark], hyphens: [Bool]) -> [Int] {
    let result = blockReadingOrder(marks: marks, hyphens: hyphens)
    var tokens: [Int] = []
    tokens.reserveCapacity(marks.count)
    for bi in result.order {
        tokens.append(contentsOf: result.blocks[bi])
    }
    return tokens
}
