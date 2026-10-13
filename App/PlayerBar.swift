import SwiftUI
import NumberOthelloCore

/// 手番・スコア・手駒枚数を表示するプレイヤー行
struct PlayerBar: View {
    let model: GameViewModel
    let player: Player
    var compact = false
    /// タップで開く手駒の一覧（相手の残り駒は手駒ピッカーに出ないため、ここで確認できる）
    @State private var showsHand = false

    var body: some View {
        let isActive = model.actingPlayer == player
        let isWinner = model.state.outcome == .win(player)
        let score = model.state.score(of: player)
        HStack {
            ChipDot(owner: player).frame(width: 18, height: 18)
            Text(player.displayName + (model.mode.isCPU(player) ? "（CPU）" : ""))
                .fontWeight(isActive ? .bold : .regular)
            if isActive {
                // 色だけに頼らず、手番であることを文字でも示す
                Text("手番")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.chipText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(player.color, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            if model.state.outcome == .win(player) {
                Text("勝ち")
                    .font(.caption.bold())
                    // 色の上の白文字はコントラスト不足（先行色で約 1.9:1）なので、色は縁と薄い地に使い文字は通常色にする
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(player.color.opacity(0.28), in: Capsule())
                    .overlay(Capsule().strokeBorder(player.color, lineWidth: 1.5))
            }
            Spacer()
            HStack(spacing: 3) {
                Text("手駒 \(model.state.hand(of: player).total)")
                    .contentTransition(.numericText())
                Image(systemName: "chevron.down.circle")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            Text("\(score) マス")
                .font(.title3.monospacedDigit().bold())
                .contentTransition(.numericText(value: Double(score)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 4 : 10)
        // ガラスの上に、手番の強調（プレイヤー色の枠と光）を重ねる
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive || isWinner ? player.color : .clear, lineWidth: 3)
        )
        .shadow(color: isActive || isWinner ? player.color.opacity(0.5) : .clear, radius: 10)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { showsHand = true }
        .popover(isPresented: $showsHand) {
            HandSummary(player: player, hand: model.state.hand(of: player))
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("タップで手駒の内訳を表示")
        .animation(.snappy(duration: 0.3), value: isActive)
        .animation(.snappy(duration: 0.3), value: score)
    }
}

/// プレイヤーの残りの手駒（種類ごとの枚数）。盤上と同じ駒で並べる
private struct HandSummary: View {
    let player: Player
    let hand: Hand

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(player.displayName)の手駒 \(hand.total) 枚")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6), spacing: 8) {
                ForEach(PieceKind.allKinds, id: \.self) { kind in
                    let count = hand.count(of: kind)
                    ZStack(alignment: .bottomTrailing) {
                        ChipView(piece: Piece(player, kind), isFlipped: false, isLastPlaced: false)
                            .frame(width: 40, height: 40)
                        Text("×\(count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.65), in: Capsule())
                    }
                    .frame(width: 44, height: 44)
                    .opacity(count == 0 ? 0.3 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(kind.description)
                    .accessibilityValue("\(count)枚")
                }
            }
        }
        .padding(16)
    }
}
