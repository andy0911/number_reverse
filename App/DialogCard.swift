import SwiftUI

/// 爆弾方向の選択・ゲーム終了などで使う中央ダイアログ
struct DialogCard<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            Theme.dialogScrim.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.subheadline).multilineTextAlignment(.center)
                HStack(spacing: 12) { actions }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}
