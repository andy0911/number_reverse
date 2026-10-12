/// CPU の難易度プロフィール（読み合い対応版）
/// spec §9 の拡張として、難易度による読みの深さと相手戦略の推定を定義
public struct CPUProfile: Sendable {
    /// 読みの深さ（手数）
    /// - 1: 1手評価（GreedyAI 相当）
    /// - 2以上: α-β ミニマックスで N 手先まで読む（反復深化。予算内で完了した深さを採用）
    public let searchDepth: Int

    /// 選択時のゆらぎ（softmax の温度）
    /// - 0.0: 確定的（最高評価値の手を必ず選ぶ）
    /// - 1.0: 程よくランダム（高評価な手ほど選ばれやすい）
    /// - ∞: 完全ランダム
    public let selectionTemperature: Double

    /// 手駒の記憶誤り率（0.0–1.0）
    /// 確率 p で、ある駒の残数を 1 枚間違えて記憶する
    /// - 0.0: 完璧な記憶（カンニング）
    /// - 0.2: 初心者（たまに見落とし）
    public let handMemoryErrorRate: Double

    /// 爆弾方向の判断を誤る確率
    /// 相手の爆発方向を、最良でなく次善以下で選ぶ確率
    public let bombDirectionErrorRate: Double

    /// 相手の戦略を推定するまでの学習手数
    /// この手数後から相手の癖を反映した読みを開始
    public let opponentModelLearningThreshold: Int

    /// 位置評価（返されにくさ・取れる着手マスの差）の重み。0 で無効
    public let positionalWeight: Int

    /// 赤・青の空きマスがこの数以下になったら全探索で読み切る。0 で無効
    public let endgameSolveCells: Int

    /// 終盤全読みに使うノード数の上限。超えたら諦めて通常の読みへ
    public let endgameBudget: Int

    /// ルートで深く読む手の数（1 手評価の上位）
    public let rootBreadth: Int

    /// ルート以外の各局面で読む手の数（1 手評価の上位）
    public let searchBreadth: Int

    /// 1 回の探索で展開してよい手数の上限。超えたら浅い深さの結果を使う
    public let nodeBudget: Int

    /// 標準的な難易度プリセット

    /// かんたん: 2手読み + 高温ゆらぎ + 記憶誤り
    /// 人間代理（2手読み・低ゆらぎ）に対し人間側の勝率が約70%になるよう校正
    public static let easy = CPUProfile(
        searchDepth: 2,
        selectionTemperature: 1.5,
        handMemoryErrorRate: 0.15,
        bombDirectionErrorRate: 0.05,
        opponentModelLearningThreshold: 100,
        positionalWeight: 1,
        rootBreadth: 6,
        searchBreadth: 6
    )

    /// ふつう: 2手読み + 低温ゆらぎ
    /// 人間代理に対し人間側の勝率が約40%になるよう校正
    public static let normal = CPUProfile(
        searchDepth: 2,
        selectionTemperature: 0.5,
        handMemoryErrorRate: 0.05,
        bombDirectionErrorRate: 0.05,
        opponentModelLearningThreshold: 100,
        positionalWeight: 1,
        rootBreadth: 6,
        searchBreadth: 6
    )

    /// つよい: 6手読み + 位置評価 + 広い終盤全読み + ゆらぎなし
    /// 旧「つよい」（`hardPrevious`）に勝ち越すことを AITests で確認している。
    /// 1 手の探索はノード数の上限（`nodeBudget`）で打ち切るので、端末が遅くても考える時間は有限
    public static let hard = CPUProfile(
        searchDepth: 6,
        selectionTemperature: 0,
        handMemoryErrorRate: 0,
        bombDirectionErrorRate: 0,
        opponentModelLearningThreshold: 0,
        positionalWeight: 1,
        endgameSolveCells: 11,
        rootBreadth: 12,
        searchBreadth: 8,
        nodeBudget: 1_500_000,
        endgameBudget: 1_500_000
    )

    /// 1 つ前の「つよい」（3手読み + 位置評価 + 終盤7マス全読み。比較用）
    public static let hardPrevious = CPUProfile(
        searchDepth: 3,
        selectionTemperature: 0.1,
        handMemoryErrorRate: 0.02,
        bombDirectionErrorRate: 0.05,
        opponentModelLearningThreshold: 10,
        positionalWeight: 1,
        endgameSolveCells: 7
    )

    /// 位置評価・終盤全読みを使わない旧「つよい」（比較用）
    public static let hardClassic = CPUProfile(
        searchDepth: 3,
        selectionTemperature: 0.1,
        handMemoryErrorRate: 0.02,
        bombDirectionErrorRate: 0.05,
        opponentModelLearningThreshold: 10
    )

    public init(
        searchDepth: Int = 1,
        selectionTemperature: Double = 0.3,
        handMemoryErrorRate: Double = 0.0,
        bombDirectionErrorRate: Double = 0.0,
        opponentModelLearningThreshold: Int = 100,
        positionalWeight: Int = 0,
        endgameSolveCells: Int = 0,
        rootBreadth: Int = 12,
        searchBreadth: Int = 6,
        nodeBudget: Int = 200_000,
        endgameBudget: Int = 30_000
    ) {
        self.endgameBudget = max(1, endgameBudget)
        self.rootBreadth = max(1, rootBreadth)
        self.searchBreadth = max(1, searchBreadth)
        self.nodeBudget = max(1, nodeBudget)
        self.positionalWeight = max(0, positionalWeight)
        self.endgameSolveCells = max(0, endgameSolveCells)
        self.searchDepth = max(1, min(8, searchDepth))
        self.selectionTemperature = max(0, selectionTemperature)
        self.handMemoryErrorRate = max(0, min(1, handMemoryErrorRate))
        self.bombDirectionErrorRate = max(0, min(1, bombDirectionErrorRate))
        self.opponentModelLearningThreshold = max(0, opponentModelLearningThreshold)
    }
}

/// 対局中に CPU が蓄積する相手の情報
/// 相手の手から「貪欲/2手読み/3手読み」の確率を推定する
/// Sendable struct として、GameViewModel で保持・更新される
public struct OpponentModel: Sendable {
    /// 相手がこれまで打った手数
    public var turnCount: Int = 0

    /// 各戦略の事後確率（初期値は均等分布）
    /// インデックス 0: 貪欲（1手読み）
    /// インデックス 1: 2手読み
    /// インデックス 2: 3手読み
    public var strategyProbs: [Double] = [1/3, 1/3, 1/3]

    public init() {}

    /// 相手の手を観測して、ベイズ更新する（未実装スタブ）
    /// - Parameters:
    ///   - observedMove: 相手が実際に打った手
    ///   - evaluationsByStrategy: 各戦略で観測手の評価値
    /// - Returns: 更新されたモデル
    public func updated(
        observedMove: Move?,
        evaluationsByStrategy: [Int]
    ) -> OpponentModel {
        var updated = self
        updated.turnCount += 1
        // TODO: ベイズ更新のロジックを実装
        // 暫定: 手数をカウントするだけ
        return updated
    }
}
