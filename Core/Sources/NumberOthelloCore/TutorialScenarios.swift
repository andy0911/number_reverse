// コーチモードの具体的なシナリオ（説明文と、その主張の検証項目）。仕組みは Tutorial.swift。
//
// 執筆ルール（事実と異なる説明を防ぐ）:
// - 説明文に書く「盤面の事実」「裏返る/裏返らない」「置ける/置けない」「合計の数値」は、
//   同じ手順の `before` / `after` に claim として併記する。claim は TutorialTests と実行時に実エンジンと照合される。
//   文章そのものは自動では検証されず、claim への書き漏らしも検出されない（「a + b = c」の算術だけはテストが確認する）。
//   文章を直したら claim を、claim を直したら文章を、必ず見直す。
// - 一般化に注意する。数字駒にだけ当てはまる規則（表裏を足すと 10、合計の比較）を「駒」全般と書かない
//   （T・B は裏が ×、T は挟み判定で数を無視、B は挟み判定の合計に 0 として加わる）。初期配置と本戦でも規則が違う（置ける場所、点線の意味）。
// - 座標は (row, col)。row 0 が上（後攻側）、row 7 が下（先行側）。説明文には座標を書かない。
// - 各操作の実行者は、実行時の手番（爆発方向の選択は爆弾の持ち主）に合わせて書く。合わないと run() が失敗として報告する。
//   配置が拒否されると手番は変わらず、相手に置ける場所が無いとパスになり同じプレイヤーが続けて置く（spec §4.3, §5.4）。

/// 説明の順に並べたシナリオ一覧
public enum Tutorial {
    public static let scenarios: [TutorialScenario] = [
        zones, flip, tie, behindArmy, enemyArmy, tank, bombCapture, bombExplosion, wasteland, grayCell, passAndEnd,
    ]

    // MARK: - 記述用の短縮

    private typealias P = Position

    /// 先行 / 後攻の数字駒
    private static func a(_ n: Int) -> Cell { .piece(Piece(.first, .number(n))) }
    private static func b(_ n: Int) -> Cell { .piece(Piece(.second, .number(n))) }

    private static func dir(_ dr: Int, _ dc: Int) -> Direction { Direction(dr: dr, dc: dc) }

    private static let emptyRow = ". . . . . . . ."

    private static func step(
        _ title: String, _ lead: String, focus: TutorialFocus = .none,
        before: [TutorialClaim] = [], demo: TutorialDemo? = nil
    ) -> TutorialStep {
        TutorialStep(title: title, lead: lead, focus: focus, demo: demo, before: before)
    }

    private static func demo(
        _ buttonTitle: String, _ actions: [TutorialAction], result: String, focus: TutorialFocus,
        after: [TutorialClaim]
    ) -> TutorialDemo {
        TutorialDemo(buttonTitle: buttonTitle, actions: actions, result: result, resultFocus: focus, after: after)
    }

    // MARK: - 1. ゾーンと点線（spec §2, §4.1）

    static let zones = TutorialScenario(
        id: .zones,
        title: "マスの色と点線",
        initial: GameState(),
        steps: [
            step(
                "赤マス（初期配置）",
                "中央の 4 マスは赤マスです。ゲームが始まると、まず「初期配置」で、この赤マスに最初の駒を置きます。",
                focus: .zones([.red]),
                before: [.zoneCount(.red, 4), .phase(.setup(step: 0))]),
            step(
                "点線（陣の境目）",
                "盤の真ん中の点線が陣の境目です。上側が後攻の陣、下側が先行の陣になります。",
                focus: .divider,
                before: [.side(P(3, 0), .second), .side(P(4, 0), .first)]),
            step(
                "初期配置は自分の陣だけ",
                "初期配置では、自分の陣の中にしか置けません。先行が、点線の上側（後攻の陣）にある赤マスへ 5 を置こうとすると…",
                focus: .cells([P(3, 3)]),
                before: [.zone(P(3, 3), .red), .side(P(3, 3), .second), .current(.first)],
                demo: demo(
                    "上側の赤マスに置いてみる",
                    [.place(.first, .number(5), at: P(3, 3))],
                    result: "置けませんでした。点線の上側は後攻の陣なので、先行は置けません（初期配置のとき。本戦では点線に関係なく置けます）。",
                    focus: .cells([P(3, 3)]),
                    after: [.rejected(.invalidSetupCell), .cell(P(3, 3), .empty)])),
            step(
                "初期配置は数字の駒だけ",
                "初期配置で置けるのは数字の駒だけです。先行が自分の陣の赤マスへ T（戦車）を置こうとすると…",
                focus: .cells([P(4, 3)]),
                before: [.zone(P(4, 3), .red), .side(P(4, 3), .first), .current(.first)],
                demo: demo(
                    "T を置いてみる",
                    [.place(.first, .tank, at: P(4, 3))],
                    result: "置けませんでした。T と B は、初期配置では使えません。",
                    focus: .cells([P(4, 3)]),
                    after: [
                        .rejected(.numberRequiredInSetup), .cell(P(4, 3), .empty),
                        .whatIfRejected(.place(.first, .bomb, at: P(4, 3)), .numberRequiredInSetup),
                    ])),
            step(
                "初期配置の 6 手",
                "初期配置は先行と後攻が交互に 6 手。まず赤マスへ 1 枚ずつ、次に青マスへ 2 枚ずつ、それぞれ自分の陣に数字の駒を置きます。この間は駒を裏返す判定がありません。",
                focus: .cells([P(4, 3), P(3, 4), P(5, 2), P(2, 5), P(6, 6), P(1, 1)]),
                before: [.phase(.setup(step: 0))],
                demo: demo(
                    "6 手を進める",
                    [
                        .place(.first, .number(5), at: P(4, 3)),
                        .place(.second, .number(5), at: P(3, 4)),
                        .place(.first, .number(4), at: P(5, 2)),
                        .place(.second, .number(4), at: P(2, 5)),
                        .place(.first, .number(6), at: P(6, 6)),
                        .place(.second, .number(6), at: P(1, 1)),
                    ],
                    result: "6 手が終わりました。1 枚も裏返らず、先行 3 枚・後攻 3 枚が並びます。ここから本戦で、次は先行の番です。",
                    focus: .placed,
                    after: [
                        .flipped([]), .phase(.playing), .current(.first),
                        .score(.first, 3), .score(.second, 3),
                        .cell(P(4, 3), a(5)), .zone(P(4, 3), .red), .side(P(4, 3), .first),
                        .cell(P(3, 4), b(5)), .zone(P(3, 4), .red), .side(P(3, 4), .second),
                        .cell(P(5, 2), a(4)), .zone(P(5, 2), .blue), .side(P(5, 2), .first),
                        .cell(P(2, 5), b(4)), .zone(P(2, 5), .blue), .side(P(2, 5), .second),
                        .cell(P(6, 6), a(6)), .zone(P(6, 6), .blue), .side(P(6, 6), .first),
                        .cell(P(1, 1), b(6)), .zone(P(1, 1), .blue), .side(P(1, 1), .second),
                    ])),
            step(
                "青マスと赤マス（本戦）",
                "内側の 32 マスは青マスです。赤マスと青マスは、本戦では空いていれば、陣に関係なくいつでも置けます（自陣に限られるのは初期配置のときだけです）。",
                focus: .zones([.blue, .red]),
                before: [
                    .zoneCount(.blue, 32), .phase(.playing),
                    .canPlaceAnywhere(.blue, .number(5)), .canPlaceAnywhere(.red, .number(5)),
                ]),
            step(
                "灰マス",
                "外周の 28 マスは灰マスです。ここには、置いた駒で相手の駒を 1 枚以上裏返せるときにしか置けません（くわしくは「灰マスのルール」で）。",
                focus: .zones([.gray]),
                before: [.zoneCount(.gray, 28)]),
        ])

    // MARK: - 2. 数字駒の裏返り n ⇔ 10−n（spec §3.1, §5.3 / 原文例）

    static let flip = TutorialScenario(
        id: .flip,
        title: "数字駒の裏返り（n と 10−n）",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow, emptyRow,
                ". . b6 b3 . . . .",
                ". a5 . . . . . .",
                emptyRow,
            ]), current: .first),
        steps: [
            step(
                "この盤面",
                "先行の 5 と、後攻の 6 があります。先行の番です。",
                focus: .cells([P(5, 2), P(6, 1)]),
                before: [.cell(P(5, 2), b(6)), .cell(P(6, 1), a(5)), .current(.first)]),
            step(
                "6 が 4 に裏返る",
                "先行が 9 を置くと、斜めに「9 と 5」で後攻の 6 を挟む形になります。",
                focus: .cells([P(4, 3), P(5, 2), P(6, 1)]),
                demo: demo(
                    "先行が 9 を置く",
                    [.place(.first, .number(9), at: P(4, 3))],
                    result: "自軍の合計 9 + 5 = 14 が、相手の 6 を上回ります。挟まれた後攻の 6 は、先行の 4（10 − 6）に裏返りました。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(4, 3), direction: dir(1, -1), behind: 9, far: 5, enemy: 6),
                        .flipped([P(5, 2)]), .cell(P(5, 2), a(4)), .cell(P(4, 3), a(9)),
                    ])),
            step(
                "数字駒は裏返ると 10 − n",
                "数字の駒は両面あり、表と裏の数字を足すと 10 になります（6 の裏は 4）。今度は後攻が 3 を置いて、先行の 4 を挟み返します。",
                focus: .cells([P(5, 1), P(5, 2), P(5, 3)]),
                before: [.cell(P(5, 2), a(4)), .cell(P(5, 3), b(3)), .current(.second)],
                demo: demo(
                    "後攻が 3 を置く",
                    [.place(.second, .number(3), at: P(5, 1))],
                    result: "自軍の合計 3 + 3 = 6 が、相手の 4 を上回ります。先行の 4 は、後攻の 6 に戻りました。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(5, 1), direction: dir(0, 1), behind: 3, far: 3, enemy: 4),
                        .flipped([P(5, 2)]), .cell(P(5, 2), b(6)),
                    ])),
        ])

    // MARK: - 3. 同値は裏返らない（spec §5.1 「>」）

    static let tie = TutorialScenario(
        id: .tie,
        title: "同じ合計では裏返らない",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". a3 b5 . . . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "この形",
                "先行の 3 と、後攻の 5 が並んでいます。5 の反対側に置けば、挟むことができます。",
                focus: .cells([P(4, 1), P(4, 2)]),
                before: [.cell(P(4, 1), a(3)), .cell(P(4, 2), b(5)), .current(.first)]),
            step(
                "同じ合計は裏返らない",
                "先行が 2 を置くと、2 と 3 で後攻の 5 を挟みます。自軍の合計は 2 + 3 = 5、相手も 5 です。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3)]),
                demo: demo(
                    "先行が 2 を置く",
                    [.place(.first, .number(2), at: P(4, 3))],
                    result: "裏返りませんでした。数字の駒では、同じ合計では裏返らず、自軍の合計が相手を「上回った」ときだけ裏返ります。もし 3 を置いていれば、3 + 3 = 6 が 5 を上回り、裏返っていました。",
                    focus: .cells([P(4, 2)]),
                    after: [
                        .sandwich(from: P(4, 3), direction: dir(0, -1), behind: 2, far: 3, enemy: 5),
                        .flipped([]), .cell(P(4, 2), b(5)), .cell(P(4, 3), a(2)),
                        .whatIf(.place(.first, .number(3), at: P(4, 3)), flipped: [P(4, 2)]),
                        .whatIfSums(.place(.first, .number(3), at: P(4, 3)), direction: dir(0, -1), behind: 3, far: 3, enemy: 5),
                    ])),
        ])

    // MARK: - 4. 背後の自軍も合計に入る（spec §5.1, R-1）

    static let behindArmy = TutorialScenario(
        id: .behindArmy,
        title: "置いた駒の背後も自軍",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". a3 . b9 a5 . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "軍とは",
                "同じ色の駒が一列に連なったものを「軍」と呼びます（1 枚だけでも軍です）。先行の 3 と 5、後攻の 9 があります。",
                focus: .cells([P(4, 1), P(4, 3), P(4, 4)]),
                before: [.cell(P(4, 1), a(3)), .cell(P(4, 3), b(9)), .cell(P(4, 4), a(5)), .current(.first)]),
            step(
                "背後の自軍も足す",
                "先行が 2 を置くと、後攻の 9 は 2 と 5 に挟まれます。置いた 2 の後ろに連なる 3 も、自軍に数えます。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3), P(4, 4)]),
                demo: demo(
                    "先行が 2 を置く",
                    [.place(.first, .number(2), at: P(4, 2))],
                    result: "自軍の合計は 3 + 2 + 5 = 10 で、相手の 9 を上回ります。後攻の 9 は先行の 1 に裏返りました（背後の 3 を数えないと 2 + 5 = 7 で、9 には届きません）。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(4, 2), direction: dir(0, 1), behind: 5, far: 5, enemy: 9),
                        .flipped([P(4, 3)]), .cell(P(4, 3), a(1)), .cell(P(4, 1), a(3)),
                        // 背後の 3 が無ければ 2 + 5 = 7 で 9 に届かず、裏返らない
                        .whatIfSums(
                            .place(.first, .number(2), at: P(4, 2)), removing: [P(4, 1)],
                            direction: dir(0, 1), behind: 2, far: 5, enemy: 9),
                        .whatIf(.place(.first, .number(2), at: P(4, 2)), removing: [P(4, 1)], flipped: []),
                    ])),
        ])

    // MARK: - 5. 相手の軍はまとめて数える（spec §1, §5.1）

    static let enemyArmy = TutorialScenario(
        id: .enemyArmy,
        title: "相手の軍はまとめて比べる",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". a9 b4 b5 . . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "連なった相手",
                "後攻の 4 と 5 が連なっています（後攻の軍）。左側には先行の 9 がいます。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3)]),
                before: [.cell(P(4, 1), a(9)), .cell(P(4, 2), b(4)), .cell(P(4, 3), b(5)), .current(.first)]),
            step(
                "軍ごと裏返る",
                "先行が 1 を置くと、後攻の軍（4 + 5 = 9）を、1 と 9 で挟みます。相手の軍は、連なった駒すべての合計で比べます。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3), P(4, 4)]),
                demo: demo(
                    "先行が 1 を置く",
                    [.place(.first, .number(1), at: P(4, 4))],
                    result: "自軍の合計 1 + 9 = 10 が、相手の軍の 9 を上回ります。軍がまとめて裏返り、4 は先行の 6 に、5 は先行の 5 になりました。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(4, 4), direction: dir(0, -1), behind: 1, far: 9, enemy: 9),
                        .flipped([P(4, 2), P(4, 3)]), .cell(P(4, 2), a(6)), .cell(P(4, 3), a(5)),
                    ])),
        ])

    // MARK: - 6. T（戦車）（spec §3.2, §5.3, R-3）

    static let tank = TutorialScenario(
        id: .tank,
        title: "T（戦車）",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow,
                ". b7 . . . . . .",
                ". . b9 b9 a1 . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "T は 1 枚だけ",
                "T（戦車）は、先行も後攻も 1 枚ずつ持っています。盤には後攻の 9 が 2 枚並び、右側を先行の 1 が押さえています。",
                focus: .cells([P(4, 2), P(4, 3), P(4, 4)]),
                before: [
                    .handCount(.first, .tank, 1), .handCount(.second, .tank, 1),
                    .cell(P(4, 2), b(9)), .cell(P(4, 3), b(9)), .cell(P(4, 4), a(1)), .current(.first),
                ]),
            step(
                "T は数を無視する",
                "先行が 9 の左に T を置きます。相手の合計は 9 + 9 = 18。数字の 9 を置いても、自軍は 9 + 1 = 10 で届きません。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3), P(4, 4)]),
                demo: demo(
                    "先行が T を置く",
                    [.place(.first, .tank, at: P(4, 1))],
                    result: "T は、置いたときに挟んだ相手の駒を、数の大小に関係なくすべて裏返します。後攻の 9 が 2 枚とも、先行の 1 になりました。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(4, 1), direction: dir(0, 1), behind: 0, far: 1, enemy: 18),
                        .flipped([P(4, 2), P(4, 3)]), .cell(P(4, 2), a(1)), .cell(P(4, 3), a(1)),
                        .whatIf(.place(.first, .number(9), at: P(4, 1)), flipped: []),
                        .whatIfSums(.place(.first, .number(9), at: P(4, 1)), direction: dir(0, 1), behind: 9, far: 1, enemy: 18),
                    ])),
            step(
                "T は裏返ると ×",
                "T の守備値は 0 です。後攻が T の下に 1 を置くと、上にいる後攻の 7 と 1 で T を挟みます。",
                focus: .cells([P(3, 1), P(4, 1), P(5, 1)]),
                before: [.cell(P(4, 1), .piece(Piece(.first, .tank))), .cell(P(3, 1), b(7)), .current(.second)],
                demo: demo(
                    "後攻が 1 を置く",
                    [.place(.second, .number(1), at: P(5, 1))],
                    result: "自軍の合計 1 + 7 = 8 が T の 0 を上回り、T は裏返って × になりました。× はどちらの色の駒でもありません。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(5, 1), direction: dir(-1, 0), behind: 1, far: 7, enemy: 0),
                        .flipped([P(4, 1)]), .cell(P(4, 1), .wasteland),
                    ])),
        ])

    // MARK: - 7. B（爆弾）も通常の駒として挟める（spec §3.2, R-4）

    static let bombCapture = TutorialScenario(
        id: .bombCapture,
        title: "B（爆弾）も挟んで裏返せる",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". a9 b1 . . . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "B（爆弾）",
                "B（爆弾）は、先行が 1 枚、後攻が 2 枚使えます。盤には、先行の 9 と後攻の 1 が並んでいます。",
                focus: .cells([P(4, 1), P(4, 2)]),
                before: [
                    .handCount(.first, .bomb, 1), .handCount(.second, .bomb, 2),
                    .cell(P(4, 1), a(9)), .cell(P(4, 2), b(1)), .current(.first),
                ]),
            step(
                "B は軍の合計に 0 として加わる",
                "後攻の 1 の右側は、先行の 9 と挟める位置です。B 自身は合計に 0 として数えられますが、背後の 9 と合わせれば挟めます。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3)]),
                demo: demo(
                    "先行が B を置く",
                    [.place(.first, .bomb, at: P(4, 3))],
                    result: "B は 0、その背後の 9 を合わせた自軍の合計 9 が、相手の 1 を上回りました。B も通常の駒と同じ挟み判定で裏返せます。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(4, 3), direction: dir(0, -1), behind: 0, far: 9, enemy: 1),
                        .flipped([P(4, 2)]), .cell(P(4, 3), .piece(Piece(.first, .bomb))), .cell(P(4, 2), a(9)),
                    ])),
        ])

    // MARK: - 8. B が裏返されると爆発（spec §5.4, R-5, R-7）

    static let bombExplosion = TutorialScenario(
        id: .bombExplosion,
        title: "B（爆弾）の爆発",
        initial: GameState(
            board: Board(diagram: [
                ". . a2 . . . . .",
                ". . . . . a8 . .",
                ". . b3 . . . . .",
                emptyRow,
                ". a9 bB . . a4 . .",
                emptyRow,
                ". . . . a2 . . .",
                ". . a7 . . . . .",
            ]), current: .first),
        steps: [
            step(
                "B が裏返されると",
                "盤上に、後攻の B があります。B は、相手に裏返されると爆発します。",
                focus: .cells([P(4, 2)]),
                before: [.cell(P(4, 2), .piece(Piece(.second, .bomb))), .cell(P(4, 1), a(9)), .current(.first)]),
            step(
                "B を挟む",
                "先行が B の右に 1 を置くと、1 と 9 で B を挟みます。B の守備値は 0 なので、自軍の合計 1 + 9 = 10 が上回り、裏返ります。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3)]),
                demo: demo(
                    "先行が 1 を置く",
                    [.place(.first, .number(1), at: P(4, 3))],
                    result: "B は × になり、爆発します。爆発の方向を選ぶのは B の持ち主の後攻です（今の手番の先行ではありません）。",
                    focus: .cells([P(4, 2)]),
                    after: [
                        .sandwich(from: P(4, 3), direction: dir(0, -1), behind: 1, far: 9, enemy: 0),
                        .flipped([P(4, 2)]), .cell(P(4, 2), .wasteland),
                        .phase(.awaitingBombDirection(owner: .second, at: P(4, 2))), .current(.first),
                    ])),
            step(
                "爆発の方向",
                "後攻は「上下左右」か「斜め」を選びます。ここでは上下左右を選びます。",
                focus: .cells([P(4, 2)]),
                before: [.phase(.awaitingBombDirection(owner: .second, at: P(4, 2)))],
                demo: demo(
                    "後攻が上下左右を選ぶ",
                    [.chooseBomb(.second, .cross)],
                    result: "B の位置から上下左右それぞれの方向で、最初に見つかった駒だけが対象です。空きマスは飛ばして進みますが、自分（後攻）の駒に当たるとその方向は不発になります。左・右・下の 3 方向は先行の駒が最初に見つかったので後攻の駒に裏返り、上は後攻自身の駒が先にあったため、その先の先行の駒（0,2）には届きませんでした。",
                    focus: .flipped,
                    after: [
                        .flipped([P(7, 2), P(4, 1), P(4, 3)]),
                        .cell(P(7, 2), b(3)), .cell(P(4, 1), b(1)), .cell(P(4, 3), b(9)),
                        // 上方向は自駒（2,2）で不発。右方向も (4,3) で止まるため、その先の (4,5) は裏返らない
                        .cell(P(2, 2), b(3)), .cell(P(0, 2), a(2)), .cell(P(4, 5), a(4)),
                        .whatIf(.chooseBomb(.second, .diagonal), flipped: [P(1, 5), P(6, 4)]),
                        .phase(.playing), .current(.second),
                    ])),
        ])

    // MARK: - 9. ×（荒地）（spec §1, §4.2, §4.3）

    static let wasteland = TutorialScenario(
        id: .wasteland,
        title: "×（荒地）",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". a9 x b1 . . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "× は誰のものでもない",
                "盤面の × は荒地です。どちらの陣地でもなく、駒の数（スコア）にも数えません。T や B が裏返されると、× になります。",
                focus: .cells([P(4, 2)]),
                before: [.cell(P(4, 2), .wasteland), .score(.first, 1), .score(.second, 1), .current(.first)]),
            step(
                "× は軍を分断する",
                "後攻の 1 の左隣は × です。先行が右から 9 を置いても、× の向こうの 9 とは軍がつながらないので、1 を挟めません。",
                focus: .cells([P(4, 1), P(4, 2), P(4, 3), P(4, 4)]),
                demo: demo(
                    "先行が 9 を置く",
                    [.place(.first, .number(9), at: P(4, 4))],
                    result: "何も裏返りません。1 の向こう側は × で、自軍の駒がいないので挟めません。× は軍を分断します。",
                    focus: .cells([P(4, 3)]),
                    after: [
                        .sandwich(from: P(4, 4), direction: dir(0, -1), behind: 9, far: 0, enemy: 1),
                        .flipped([]), .cell(P(4, 3), b(1)),
                    ])),
            step(
                "× には置けない",
                "× のマスは空きマスではないので、駒を置けません。後攻が × のマスへ置こうとすると…",
                focus: .cells([P(4, 2)]),
                before: [.current(.second)],
                demo: demo(
                    "× に置いてみる",
                    [.place(.second, .number(1), at: P(4, 2))],
                    result: "置けませんでした。",
                    focus: .cells([P(4, 2)]),
                    after: [.rejected(.occupied), .cell(P(4, 2), .wasteland)])),
        ])

    // MARK: - 10. 灰マスのルール（spec §4.2, R-2, R-4）

    static let grayCell = TutorialScenario(
        id: .grayCell,
        title: "灰マスのルール",
        initial: GameState(
            board: Board(diagram: [
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". b9 a1 . . . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first),
        steps: [
            step(
                "外周は灰マス",
                "左端のマスは灰マスです。灰マスには、置いた駒で相手の駒を 1 枚以上裏返せるときだけ置けます。盤には、後攻の 9 と先行の 1 が並んでいます。",
                focus: .cells([P(4, 0)]),
                before: [
                    .zone(P(4, 0), .gray), .cell(P(4, 1), b(9)), .cell(P(4, 2), a(1)), .current(.first),
                ]),
            step(
                "形だけ挟めても置けない",
                "先行が灰マスへ 1 を置くと、1 と 1 で後攻の 9 を挟む形になります。",
                focus: .cells([P(4, 0), P(4, 1), P(4, 2)]),
                demo: demo(
                    "1 を置いてみる",
                    [.place(.first, .number(1), at: P(4, 0))],
                    result: "置けませんでした。挟む形でも、自軍の合計 1 + 1 = 2 は相手の 9 を上回れず、1 枚も裏返せないからです。",
                    focus: .cells([P(4, 0), P(4, 1), P(4, 2)]),
                    after: [
                        .sandwich(from: P(4, 0), direction: dir(0, 1), behind: 1, far: 1, enemy: 9),
                        .rejected(.grayRequiresCapture), .cell(P(4, 0), .empty),
                    ])),
            step(
                "B も合計が足りなければ置けない",
                "B（爆弾）も同じ判定です。B 自身は合計に 0 として加わるので、灰マスへ B を置こうとすると…",
                focus: .cells([P(4, 0)]),
                demo: demo(
                    "B を置いてみる",
                    [.place(.first, .bomb, at: P(4, 0))],
                    result: "置けませんでした。自軍の合計 0 + 1 = 1 は相手の 9 を上回れず、1 枚も裏返せないからです。",
                    focus: .cells([P(4, 0), P(4, 1), P(4, 2)]),
                    after: [
                        .sandwich(from: P(4, 0), direction: dir(0, 1), behind: 0, far: 1, enemy: 9),
                        .rejected(.grayRequiresCapture), .cell(P(4, 0), .empty),
                    ])),
            step(
                "裏返せるなら置ける",
                "では 9 を置くと？ 自軍の合計は 9 + 1 = 10 になります。",
                focus: .cells([P(4, 0), P(4, 1), P(4, 2)]),
                demo: demo(
                    "9 を置く",
                    [.place(.first, .number(9), at: P(4, 0))],
                    result: "10 が相手の 9 を上回るので、後攻の 9 は先行の 1 に裏返りました。裏返せるので、灰マスに置けました。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(4, 0), direction: dir(0, 1), behind: 9, far: 1, enemy: 9),
                        .flipped([P(4, 1)]), .cell(P(4, 0), a(9)), .cell(P(4, 1), a(1)),
                    ])),
        ])

    // MARK: - 11. パスとゲーム終了（spec §4.3, R-9, R-10）

    /// 上 4 行が後攻の陣、下 4 行が先行の陣。空きは青マス (6,3) と灰マス (0,3)・(7,7) だけ。
    /// (7,7) は周囲がすべて × なので、誰も裏返せず最後まで空く
    static let passAndEnd = TutorialScenario(
        id: .passAndEnd,
        title: "パスとゲーム終了",
        initial: GameState(
            board: Board(diagram: [
                "b1 b4 b6 . b5 b2 b3 b8",
                "b2 b7 b3 b1 b8 b4 b5 b6",
                "b9 b5 b4 b2 b3 b7 b1 b2",
                "b6 b3 b8 b1 b4 b5 b9 b7",
                "a5 a4 a6 a3 a2 a8 a1 a2",
                "a7 a1 a9 a4 a6 a5 a3 a8",
                "a2 a6 a4 . a7 a1 x x",
                "a9 a3 a5 a1 a8 a2 x .",
            ]), current: .first),
        steps: [
            step(
                "終盤の盤面",
                "盤はほぼ埋まっています。空いているのは、青マスが 1 つと、灰マスが 2 つだけです。先行の番です。",
                focus: .cells([P(6, 3), P(0, 3), P(7, 7)]),
                before: [
                    .emptyCells([P(6, 3), P(0, 3), P(7, 7)]),
                    .zone(P(6, 3), .blue), .zone(P(0, 3), .gray), .zone(P(7, 7), .gray), .current(.first),
                ]),
            step(
                "置ける場所が無ければパス",
                "先行が青マスを埋めると、残りは灰マスだけになります。後攻には、裏返せる灰マスがありません。",
                focus: .cells([P(6, 3)]),
                demo: demo(
                    "先行が 1 を置く",
                    [.place(.first, .number(1), at: P(6, 3))],
                    result: "後攻には置ける場所がないので、手番は自動的にパスされ、先行がもう一度置きます。",
                    focus: .cells([P(0, 3)]),
                    after: [
                        .flipped([]), .passed(.second), .current(.first), .phase(.playing),
                        .emptyCells([P(0, 3), P(7, 7)]),
                    ])),
            step(
                "ゲーム終了と勝敗",
                "先行が上の灰マスへ 9 を置くと、縦に並んだ後攻の 1・2・1（合計 4）を、9 と先行の駒で挟めます。",
                focus: .cells([P(0, 3), P(1, 3), P(2, 3), P(3, 3), P(4, 3)]),
                before: [.current(.first)],
                demo: demo(
                    "先行が 9 を置く",
                    [.place(.first, .number(9), at: P(0, 3))],
                    result: "3 枚が裏返りました。残る灰マスは誰にも裏返せないので、両者とも置けなくなり、盤が埋まらなくてもゲーム終了です。勝敗は盤上の自分の駒の数で決まり（× は数えません。同数なら引き分けです）、先行が 32 対 28 で勝ちです。",
                    focus: .flipped,
                    after: [
                        .sandwich(from: P(0, 3), direction: dir(1, 0), behind: 9, far: 9, enemy: 4),
                        .flipped([P(1, 3), P(2, 3), P(3, 3)]),
                        .cell(P(1, 3), a(9)), .cell(P(2, 3), a(8)), .cell(P(3, 3), a(9)),
                        .emptyCells([P(7, 7)]), .phase(.finished),
                        .score(.first, 32), .score(.second, 28), .outcome(.win(.first)),
                    ])),
        ])
}
