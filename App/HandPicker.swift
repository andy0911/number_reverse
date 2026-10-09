import SwiftUI
import NumberOthelloCore

/// 手番プレイヤーの手駒一覧。選択中の駒はハイライトし、置けない駒は無効化する
struct HandPicker: View {
    let model: GameViewModel
    var compact = false

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
            if compact {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
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
                        .frame(width: 48, height: 44)
                        .background(isSelected ? player.color : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isSelected ? Theme.chipText : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled || !selectable.contains(kind))
                    .opacity(!enabled || !selectable.contains(kind) ? 0.35 : 1)
                }
                    }
                }.scrollIndicators(.visible)
            } else {
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
                        .frame(maxWidth: .infinity, minHeight: 44)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        // ガラスは背景のコンテナにだけ適用する（各駒ボタンの選択中の塗りが弱まらないように）
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
