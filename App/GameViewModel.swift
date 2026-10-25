import SwiftUI
import NumberOthelloCore

/// CPU の難易度（読み合い対応版）
enum CPUDifficulty: Hashable, CaseIterable {
    case easy
    case normal
    case hard

    var displayName: String {
        switch self {
        case .easy: "かんたん"
        case .normal: "ふつう"
        case .hard: "つよい"
        }
    }

    var profile: CPUProfile {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        }
    }
}

enum GameMode: Hashable {
    case twoPlayers
    case vsCPU(human: Player, difficulty: CPUDifficulty = .normal)
    /// 動作確認用の CPU 同士の対局（起動引数 `-demo`）
    case cpuOnly

    func isCPU(_ player: Player) -> Bool {
        switch self {
        case .twoPlayers: false
        case .vsCPU(let human, _): player != human
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
    /// 初期配置が終わった直後の案内を出している間 true。人間が本戦で最初の 1 手を置くまで続く
    private(set) var showsMainPhaseNotice = false

    /// CPU のプロフィール（難易度）
    private let cpuProfile: CPUProfile

    /// 対局中に蓄積される相手の戦略推定
    private(set) var opponentModel: OpponentModel = OpponentModel()

    init(mode: GameMode, state: GameState = GameState()) {
        self.mode = mode
        self.state = state

        // 難易度に応じてプロフィールを設定
        self.cpuProfile = switch mode {
        case .vsCPU(_, let difficulty):
            difficulty.profile
        case .twoPlayers, .cpuOnly:
            .normal
        }

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

    /// 初期配置で駒を選ぶ前に、置ける場所を弱く示すマス（選んだ後は `highlightedCells` が強く示す）
    var weakHintCells: Set<Position> {
        guard isHumanTurn, selectedKind == nil, case .setup(let step) = state.phase else { return [] }
        return Set(GameState.setupCells(step: step).filter { state.board[$0] == .empty })
    }

    var selectableKinds: [PieceKind] {
        let kinds = Set(state.legalMoves().map(\.kind))
        return PieceKind.allKinds.filter { kinds.contains($0) }
    }

    func tap(_ p: Position) {
        guard isHumanTurn else { return }
        // 方向選択中はインライン表示で盤面を隠さなくなった分、盤面のタップが素通りしてしまう。
        // setup/playing では駒配置に使うが、方向選択中（駒は選べない）は何もしない
        if case .awaitingBombDirection = state.phase { return }
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
        let mover = state.current
        let wasSetup: Bool
        if case .setup = state.phase { wasSetup = true } else { wasSetup = false }
        do {
            try state.place(move.kind, at: move.position)
            updateMainPhaseNotice(wasSetup: wasSetup, mover: mover)
            message = nil
            record()
            selectedKind = nil
        } catch {
            message = Self.describe(error)
        }
        scheduleCPUIfNeeded()
    }

    /// 初期配置が終わったら案内を立て、人間が本戦で最初の 1 手を置いたら下ろす（CPU 同士のデモでは下ろさない）
    private func updateMainPhaseNotice(wasSetup: Bool, mover: Player) {
        if wasSetup {
            if case .playing = state.phase { showsMainPhaseNotice = true }
        } else if !mode.isCPU(mover) {
            showsMainPhaseNotice = false
        }
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
        let profile = cpuProfile
        let model = opponentModel
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            let (decision, updatedModel): (CPUDecision, OpponentModel) = await Task.detached(priority: .userInitiated) {
                var rng = SystemRandomNumberGenerator()
                let ai = ReadingAI(profile: profile)
                if case .awaitingBombDirection = snapshot.phase {
                    return (.bomb(ai.chooseBombDirection(in: snapshot, using: &rng)), model)
                }
                let (move, newModel) = ai.chooseMove(in: snapshot, opponentModel: model, using: &rng)
                return (.move(move), newModel)
            }.value
            self.opponentModel = updatedModel
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
