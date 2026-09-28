import SwiftUI
import NumberOthelloCore

/// コーチモード（遊び方）の画面。シナリオを 1 手順ずつ進め、盤面のコーチマークと吹き出しでルールを説明する。
/// 状態は `CoachSession` が持ち、本編のゲーム状態とは完全に分離している。
struct CoachModeView: View {
    let exit: () -> Void

    @State private var session = CoachSession()
    @State private var anchorX: CGFloat?

    var body: some View {
        VStack(spacing: 10) {
            header
            legend
            CoachBoardView(
                state: session.boardState,
                focus: session.focus,
                focusCells: session.focusCells,
                flipped: session.flipped,
                placed: session.placed,
                rejectedCell: session.rejectedCell,
                anchorX: $anchorX
            )
            // 盤面を最優先で幅いっぱいに描く（吹き出しの矢印は盤面と同じ左端・幅を前提に位置を合わせる）
            .layoutPriority(1)
            CoachBubble(session: session, anchorX: anchorX)
                .padding(.top, 8)
            controls
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - ヘッダー（終了・スキップ・レッスン一覧）

    private var header: some View {
        VStack(spacing: 2) {
            HStack {
                Button("終了", systemImage: "xmark", action: exit)
                    .labelStyle(.titleAndIcon)
                Spacer()
                Button(session.isLastLesson ? "スキップ（終了）" : "スキップ", systemImage: "forward.end") {
                    if session.isLastLesson { exit() } else { session.skipLesson() }
                }
                .labelStyle(.titleAndIcon)
            }
            Menu {
                ForEach(Array(session.lessonTitles.enumerated()), id: \.offset) { index, title in
                    Button {
                        session.jump(to: index)
                    } label: {
                        if index == session.lessonIndex {
                            Label("\(index + 1). \(title)", systemImage: "checkmark")
                        } else {
                            Text("\(index + 1). \(title)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("遊び方 \(session.lessonIndex + 1) / \(session.lessonCount)")
                        .foregroundStyle(.secondary)
                    Text(session.scenario.title).fontWeight(.bold)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding(.top, 4)
    }

    /// 駒の色と先行・後攻の対応（盤面の下が先行、上が後攻）
    private var legend: some View {
        HStack(spacing: 16) {
            ForEach([Player.first, .second], id: \.self) { player in
                HStack(spacing: 4) {
                    Circle().fill(player.color).frame(width: 12, height: 12)
                    Text("\(player.displayName)（\(player == .first ? "下側" : "上側")）")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 操作ボタン

    private var controls: some View {
        HStack(spacing: 10) {
            Button("戻る", systemImage: "chevron.left") { session.back() }
                .buttonStyle(.bordered)
                .disabled(session.isFirstStep)
            if let demo = session.step.demo, session.canPerform {
                Button {
                    session.perform()
                } label: {
                    Label(demo.buttonTitle, systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                if session.step.demo != nil {
                    Button("もう一度", systemImage: "arrow.counterclockwise") { session.replay() }
                        .buttonStyle(.bordered)
                }
                Button {
                    if session.isLastStep { exit() } else { session.next() }
                } label: {
                    Text(session.isLastStep ? "完了" : "次へ").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
    }
}
