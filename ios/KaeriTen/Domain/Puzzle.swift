import Foundation

/// 返り点の記号。生データの1文字にそのまま対応する。
enum Mark: Character {
    case none = "."
    case re = "r"
    case ichi = "1"
    case ni = "2"
    case san = "3"
    case yon = "4"

    /// 「戻り先」として数字点探索の対象になる記号（二・三・四）
    static let numberedTargets: [Mark] = [.ni, .san, .yon]

    var isSkippedOnForwardScan: Bool {
        self == .re || self == .ni || self == .san || self == .yon
    }
}

struct Puzzle: Identifiable {
    let id: Int
    let kanbun: String
    let tokens: [Character]        // kanbun を1文字ずつ分解したもの
    let kandoku: String
    let flavor: String
    let answerMarks: [Mark]
    let answerHyphens: [Bool]      // count == tokens.count - 1
    let answerOrder: [Int]         // 0始まりのトークン位置。answerOrder[step] = トークンインデックス
    let stageX: Int
    let stageY: Int
    let maxLevel: Int              // 数字点の最大段数（1 = レ点のみ）
    let kandokuOK: Bool            // 読み順と読み下しが整合するか（表示分岐には使わない。§1-E）

    var tokenCount: Int { tokens.count }
}
