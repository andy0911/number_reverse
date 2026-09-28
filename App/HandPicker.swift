import SwiftUI
import NumberOthelloCore

/// 手番プレイヤーの手駒一覧。選択中の駒はハイライトし、置けない駒は無効化する
struct HandPicker: View {
    let model: GameViewModel

    var body: some View {
        let player: Player = switch model.mode {
        case .vsCPU(let human): human
        case .twoPlayers, .cpuOnly: model.actingPlayer ?? model.state.current
        }
        let hand = model.state.hand(of: player)
        let selectable = Set(model.selectableKinds)
        let enabled = model.isHumanTurn && model.state.phase != .finished
        VStack(alignment: .leading, spacing: 6) {
            Text(enabled ? "\(player.displayName)の手駒（選んでから盤をタップ）" : "\(player.displayName)の手駒（相手の番です）")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(PieceKind.allKinds, id: \.self) { kind in
                    let count = hand.count(of: kind)
                    let isSelected = model.selectedKind == kind
                    Button {
                        model.selectedKind = isSelected ? nil : kind
                    } label: {
                        VStack(spacing: 0) {
                            Text(kind.description).font(.headline)
                            Text("×\(count)").font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isSelected ? player.color : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isSelected ? Theme.chipText : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled || !selectable.contains(kind))
                    .opacity(!enabled || !selectable.contains(kind) ? 0.35 : 1)
                }
            }
        }
    }
}
