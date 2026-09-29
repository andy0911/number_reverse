import SwiftUI
import NumberOthelloCore

enum GameMode: Hashable {
    case twoPlayers
    case vsCPU(human: Player)
    /// 動作確認用の CPU 同士の対局（起動引数 `-demo`）
    case cpuOnly

    func isCPU(_ player: Player) -> Bool {
        switch self {
        case .twoPlayers: false
        case .vsCPU(let human): player != human
        case .cpuOnly: true
        }
    }

    /// 広告のカウント対象かどうかの分類（spec §11.1）。動作確認用の `cpuOnly` は対象外
    var monetizationCategory: GameModeCategory {
        switch self {
        case .twoPlayers: .twoPlayers
        case .vsCPU: .vsCPU
        case .cpuOnly: .cpuOnly
        }
    }
}

@MainActor
@Observable
final class GameViewModel {
    let mode: GameMode
    private(set) var state = GameState()
    var selectedKind: PieceKind?
    private(set) var message: String?
    private(set) var lastFlipped: Set<Position> = []
    private(set) var lastPlaced: Position?
    private(set) var isCPUThinking = false
    private let ai = GreedyAI()

    init(mode: GameMode, state: GameState = GameState()) {
        self.mode = mode
        self.state = state
        scheduleCPUIfNeeded()
    }

    /// 今操作すべきプレイヤー（爆弾の割り込み中は爆弾の持ち主）
    var actingPlayer: Player? {
        switch state.phase {
        case .setup, .playing: state.current
        case .awaitingBombDirection(let owner, _): owner
        case .finished: nil
        }
    }

    var isHumanTurn: Bool {
        guard let p = actingPlayer else { return false }
        return !mode.isCPU(p) && !isCPUThinking
    }

    /// 選択中の駒で置けるセル。爆弾の方向選択中は、その爆弾自身の位置を示す
    /// （盤面を隠さずインライン表示にしたため、どの駒が爆発したのかを見失わないように）
    var highlightedCells: Set<Position> {
        if case .awaitingBombDirection(_, let position) = state.phase { return [position] }
        guard isHumanTurn, let kind = selectedKind else { return [] }
        return Set(state.legalMoves().filter { $0.kind == kind }.map(\.position))
    }

    var selectableKinds: [PieceKind] {
        let kinds = Set(state.legalMoves().map(\.kind))
        return PieceKind.allKinds.filter { kinds.contains($0) }
    }

    func tap(_ p: Position) {
        guard isHumanTurn else { return }
        guard let kind = selectedKind else {
            message = "先に下から駒を選んでください"
            return
        }
        perform(Move(kind, at: p))
    }

    func chooseBombDirection(_ direction: BombDirection) {
        guard isHumanTurn else { return }
        applyBomb(direction)
    }

    private func perform(_ move: Move) {
        do {
            try state.place(move.kind, at: move.position)
            message = nil
            record()
            selectedKind = nil
        } catch {
            message = Self.describe(error)
        }
        scheduleCPUIfNeeded()
    }

    private func applyBomb(_ direction: BombDirection) {
        try? state.chooseBombDirection(direction)
        record()
        scheduleCPUIfNeeded()
    }

    private func record() {
        lastFlipped = []
        for event in state.events {
            switch event {
            case .placed(let p, _): lastPlaced = p
            case .flipped(let ps): lastFlipped.formUnion(ps)
            case .passed(let player): message = "\(player.displayName)は置ける場所が無いためパス"
            default: break
            }
        }
    }

    private func scheduleCPUIfNeeded() {
        guard let p = actingPlayer, mode.isCPU(p), !isCPUThinking else { return }
        isCPUThinking = true
        let snapshot = state
        let ai = ai
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            let decision: CPUDecision = await Task.detached(priority: .userInitiated) {
                if case .awaitingBombDirection = snapshot.phase {
                    return .bomb(ai.chooseBombDirection(in: snapshot))
                }
                return .move(ai.chooseMove(in: snapshot))
            }.value
            isCPUThinking = false
            switch decision {
            case .bomb(let d): applyBomb(d)
            case .move(let m?): perform(m)
            case .move(nil): break
            }
        }
    }

    static func describe(_ error: Error) -> String {
        switch error as? MoveError {
        case .occupied: "そのマスには置けません"
        case .invalidSetupCell: "初期配置は指定エリアの自陣側にのみ置けます"
        case .numberRequiredInSetup: "初期配置では数字の駒のみ使えます"
        case .grayRequiresCapture: "灰色のマスは相手の駒を裏返せる時だけ置けます"
        case .noPieceInHand: "その駒は残っていません"
        default: "今は置けません"
        }
    }
}

private enum CPUDecision: Sendable {
    case move(Move?)
    case bomb(BombDirection)
}

extension Player {
    var displayName: String { self == .first ? "先行" : "後攻" }
}
