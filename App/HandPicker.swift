import SwiftUI
import NumberOthelloCore

/// 手番プレイヤーの手駒一覧。盤上と同じ駒（`ChipView`）で並べ、残り枚数をバッジで示す。
/// 選択中の駒は持ち上げて光らせ、置けない駒は無効化する
struct HandPicker: View {
    let model: GameViewModel
    var compact = false

    var body: some View {
        let player: Player = switch model.mode {
        case .vsCPU(let human, _): human
        case .twoPlayers, .cpuOnly: model.actingPlayer ?? model.state.current
        }
        let hand = model.state.hand(of: player)
        let selectable = Set(model.selectableKinds)
        let enabled = model.isHumanTurn && model.state.phase != .finished
        VStack(alignment: .leading, spacing: 6) {
            Text(enabled ? "\(player.displayName)の手駒（選んでから盤をタップ）" : "\(player.displayName)の手駒（相手の番です）")
                .font(.caption)
                .foregroundStyle(.secondary)
            if compact {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(PieceKind.allKinds, id: \.self) { kind in
                            slot(kind, player: player, count: hand.count(of: kind),
                                 enabled: enabled && selectable.contains(kind))
                                .frame(width: 48)
                        }
                    }
                }.scrollIndicators(.visible)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(PieceKind.allKinds, id: \.self) { kind in
                        slot(kind, player: player, count: hand.count(of: kind),
                             enabled: enabled && selectable.contains(kind))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        // ガラスは背景のコンテナにだけ適用する（各駒の選択表現が弱まらないように）
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sensoryFeedback(.selection, trigger: model.selectedKind)
    }

    /// 手駒 1 種。タップ領域は高さ 44pt 以上を保つ
    private func slot(_ kind: PieceKind, player: Player, count: Int, enabled: Bool) -> some View {
        let isSelected = model.selectedKind == kind
        return Button {
            model.selectedKind = isSelected ? nil : kind
        } label: {
            ZStack(alignment: .bottomTrailing) {
                // 高さは従来の手駒ボタン（44pt）に合わせ、盤の縦幅を削らない
                ChipView(piece: Piece(player, kind), isFlipped: false, isLastPlaced: false)
                    .frame(width: 42, height: 42)
                    .background {
                        if isSelected {
                            Circle().fill(player.color.opacity(0.55)).blur(radius: 7).padding(2)
                        }
                    }
                    .scaleEffect(isSelected ? 1.12 : 1)
                    .offset(y: isSelected ? -2 : 0)
                Text("×\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.65), in: Capsule())
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel("\(kind.description)")
        .accessibilityValue("残り\(count)枚")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
