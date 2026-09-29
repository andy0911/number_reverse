import SwiftUI
import NumberOthelloCore

/// コーチマークの吹き出し。矢印で盤面の指し示す位置（`anchorX`）を示し、説明文を表示する
struct CoachBubble: View {
    let session: CoachSession
    let anchorX: CGFloat?

    private static let arrowSize = CGSize(width: 22, height: 11)
    private static let cardColor = Color(uiColor: .secondarySystemBackground)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("手順 \(session.stepIndex + 1) / \(session.scenario.steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(session.step.title)
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let rejection = session.rejection {
                        // 本編で実際に表示されるメッセージ（GameViewModel.describe）をそのまま見せる
                        Label("ゲームでの表示: 「\(GameViewModel.describe(rejection))」", systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if session.hasVerificationFailure {
                        // 説明が実エンジンの結果と食い違ったときの安全弁（テストで防いでいるため通常は出ない）
                        Label("この説明は実際の動きと一致しませんでした", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Self.cardColor, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topLeading) { arrow }
    }

    /// 盤面の指し示す位置へ向かう矢印（吹き出しの上端に付く）
    private var arrow: some View {
        GeometryReader { geo in
            if let anchorX {
                let x = min(max(anchorX, 24), geo.size.width - 24)
                Triangle()
                    .fill(Self.cardColor)
                    .frame(width: Self.arrowSize.width, height: Self.arrowSize.height)
                    .position(x: x, y: -Self.arrowSize.height / 2 + 0.5)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
