import Foundation
import NumberOthelloCore

// 人間代理プレイヤーと CPU プリセットを対戦させ、人間側の勝率を測る（docs/calibration.md）
// 使い方: swift run -c release calibrate <difficulty> <games> [seedStart]
//   difficulty: easy | normal | hard | hardPrevious | hardClassic | proxy | custom（C_DEPTH などの環境変数で組み立てる）
//   games: 対局数（seed が偶数なら人間代理が先行、奇数なら後攻）
// 出力: 1 局 1 行の TSV（seed, 人間の手番, 人間の駒数, CPU の駒数, 結果）と最後に集計

/// 再現可能な乱数（SplitMix64。AITests と同じ）
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 人間代理: 2 手読み・低ゆらぎ（温度 0.1・位置評価なし。v1.1.5 の校正値を再現する設定）。環境変数 PROXY_TEMP / PROXY_POS で温度・位置評価の重みを変えられる
let env = ProcessInfo.processInfo.environment
let humanProxy = CPUProfile(
    searchDepth: 2,
    selectionTemperature: Double(env["PROXY_TEMP"] ?? "") ?? 0.1,
    bombDirectionErrorRate: 0.1,
    positionalWeight: Int(env["PROXY_POS"] ?? "") ?? 0
)

/// つよいの候補を環境変数で組み立てる（探索幅・予算の比較用）。C_BASE=hardPrevious で 1 つ前のつよいを基にする
func customProfile() -> CPUProfile {
    let base: CPUProfile = env["C_BASE"] == "hardPrevious" ? .hardPrevious : .hard
    func v(_ k: String, _ d: Int) -> Int { Int(env[k] ?? "") ?? d }
    return CPUProfile(
        searchDepth: v("C_DEPTH", base.searchDepth),
        selectionTemperature: Double(env["C_TEMP"] ?? "") ?? base.selectionTemperature,
        handMemoryErrorRate: base.handMemoryErrorRate,
        bombDirectionErrorRate: Double(env["C_BOMBERR"] ?? "") ?? base.bombDirectionErrorRate,
        opponentModelLearningThreshold: base.opponentModelLearningThreshold,
        positionalWeight: v("C_POS", base.positionalWeight),
        endgameSolveCells: v("C_END", base.endgameSolveCells),
        rootBreadth: v("C_ROOT", base.rootBreadth),
        searchBreadth: v("C_BREADTH", base.searchBreadth),
        nodeBudget: v("C_NODES", base.nodeBudget),
        endgameBudget: v("C_ENDBUDGET", base.endgameBudget)
    )
}

func profile(named name: String) -> CPUProfile? {
    switch name {
    case "easy": .easy
    case "normal": .normal
    case "hard": .hard
    case "hardPrevious": .hardPrevious
    case "hardClassic": .hardClassic
    case "proxy": humanProxy
    case "custom": customProfile()
    default: nil
    }
}

let args = CommandLine.arguments
guard args.count >= 3, let cpuProfile = profile(named: args[1]), let games = Int(args[2]), games > 0 else {
    print("usage: calibrate <easy|normal|hard|hardPrevious|hardClassic|proxy|custom> <games> [seedStart]")
    exit(2)
}
let seedStart = args.count >= 4 ? UInt64(args[3]) ?? 0 : 0

var humanWins = 0, cpuWins = 0, draws = 0
var cpuMoves = 0, cpuTotal = 0.0, cpuMax = 0.0
var unfinished = 0
for i in 0..<games {
    let seed = seedStart + UInt64(i)
    let human: Player = seed % 2 == 0 ? .first : .second
    var rng = SeededRNG(state: seed &* 7919 &+ 1)
    let ais: [Player: ReadingAI] = [human: ReadingAI(profile: humanProxy), human.opponent: ReadingAI(profile: cpuProfile)]
    var models = [Player.first: OpponentModel(), .second: OpponentModel()]
    var state = GameState()
    var steps = 0
    while state.outcome == nil, steps < 400 {
        steps += 1
        if case .awaitingBombDirection(let owner, _) = state.phase {
            try! state.chooseBombDirection(ais[owner]!.chooseBombDirection(in: state, using: &rng))
            continue
        }
        let p = state.current
        let t0 = Date()
        let r = ais[p]!.chooseMove(in: state, opponentModel: models[p]!, using: &rng)
        if p != human {
            let dt = Date().timeIntervalSince(t0)
            cpuMoves += 1; cpuTotal += dt; cpuMax = max(cpuMax, dt)
        }
        models[p] = r.updatedModel
        guard let m = r.move else { break }
        try! state.place(m.kind, at: m.position)
    }
    if state.outcome == nil { unfinished += 1 }
    let h = state.score(of: human), c = state.score(of: human.opponent)
    let result = h > c ? "human" : c > h ? "cpu" : "draw"
    if h > c { humanWins += 1 } else if c > h { cpuWins += 1 } else { draws += 1 }
    print("\(seed)\t\(human == .first ? "first" : "second")\t\(h)\t\(c)\t\(result)")
}
print("# \(args[1]) games=\(games) human=\(humanWins) cpu=\(cpuWins) draw=\(draws)"
      + String(format: " cpuMove avg=%.3fs max=%.3fs", cpuTotal / Double(max(1, cpuMoves)), cpuMax)
      + " unfinished=\(unfinished) proxy(temp=\(humanProxy.selectionTemperature) pos=\(humanProxy.positionalWeight))"
      + " cpu(depth=\(cpuProfile.searchDepth) temp=\(cpuProfile.selectionTemperature) end=\(cpuProfile.endgameSolveCells)"
      + " nodes=\(cpuProfile.nodeBudget) endBudget=\(cpuProfile.endgameBudget))")
