import SwiftUI
import NumberOthelloCore

struct TitleView: View {
    let start: (GameMode) -> Void
    @Environment(Monetization.self) private var monetization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCoach = false
    @State private var showsAdPrivacy = false
    @State private var showsCPUSetup = false
    @State private var appeared = false
    #if MEDIATION_QA && !BANNER_PREVIEW_QA
    @State private var showsQA = false
    #endif

    var body: some View {
        GeometryReader { geometry in
            // iPhone SE 相当の高さでは紋章を小さくして、メニューが画面内に収まるようにする
            let compact = geometry.size.height < 700
            ZStack {
                TitleDecoration()
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 8)
                        hero(compact: compact)
                        Spacer(minLength: compact ? 16 : 28)
                        menu
                            .reveal(appeared, delay: 0.25)
                        Spacer(minLength: compact ? 12 : 20)
                        footer
                            .reveal(appeared, delay: 0.4)
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation { appeared = true } }
        }
        #if MEDIATION_QA && !BANNER_PREVIEW_QA
        .sheet(isPresented: $showsQA) { QADiagnosticsView() }
        #endif
        .sheet(isPresented: $showsAdPrivacy) { AdPrivacyView() }
        // コーチモード（遊び方）。本編のゲーム状態とは独立
        .fullScreenCover(isPresented: $showsCoach) {
            CoachModeView { showsCoach = false }
        }
        // CPU 対戦の設定（自分の側と難易度）
        .sheet(isPresented: $showsCPUSetup) {
            CPUSetupSheet { human, difficulty in
                #if MEDIATION_QA
                monetization.ads.isQABannerPreviewEnabled = false
                #endif
                start(.vsCPU(human: human, difficulty: difficulty))
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            // 背後のタイトル画面が透けて文字が読みにくくならないよう、アプリ共通の背景を敷く
            .presentationBackground { ChromeBackdrop() }
        }
    }

    // MARK: - ヒーロー

    private func hero(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            HeroChip()
                .frame(width: compact ? 120 : 172, height: compact ? 120 : 172)
                .accessibilityHidden(true)
            Text("トオカエシ")
                .font(.system(size: compact ? 38 : 46, weight: .heavy, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                ChipDot(owner: .first).frame(width: 14, height: 14)
                Text("十返し").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                ChipDot(owner: .second).frame(width: 14, height: 14)
            }
            Text("数字の合計で相手の軍を挟んで裏返せ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .reveal(appeared, delay: 0.05)
    }

    // MARK: - メニュー

    private var menu: some View {
        VStack(spacing: 12) {
            Button {
                showsCPUSetup = true
            } label: {
                // 強調色（brandTint）の塗りの上の文字。ライトは白、ダークは暗色（chipText と同じ向き）
                menuLabel("cpu", title: "CPUと対戦", subtitle: "強さと先行・後攻を選べます")
                    .foregroundStyle(Theme.chipText)
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("CPUと対戦")
            .accessibilityHint("強さと先行・後攻を選べます")

            Button {
                #if MEDIATION_QA
                monetization.ads.isQABannerPreviewEnabled = false
                #endif
                start(.twoPlayers)
            } label: {
                menuLabel("person.2.fill", title: "2人で対戦", subtitle: "1台を交代で使って遊ぶ")
            }
            .buttonStyle(.glass)
            .accessibilityLabel("2人で対戦")
            .accessibilityHint("1台を交代で使って遊ぶ")

            Button {
                showsCoach = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                    Text("遊び方を見る")
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.glass)
        }
        .controlSize(.large)
    }

    private func menuLabel(_ symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).opacity(0.85)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .opacity(0.7)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - フッター（課金・プライバシー・QA）

    private var footer: some View {
        VStack(spacing: 8) {
            #if MEDIATION_QA
            Button("テスト広告を表示して対局") {
                monetization.ads.qaBannerScenario = .liveDemo
                monetization.ads.isQABannerPreviewEnabled = true
                start(.twoPlayers)
            }
            .accessibilityIdentifier("qaBannerPreviewStart")
            .accessibilityValue("起動試行: \(monetization.ads.qaStartupAttempts) / SDK: \(monetization.ads.isSDKReady ? "完了" : "待機")")
            .font(.footnote)
            Text("Google公式テスト広告の見え方を確認します。購入状態は変更しません。")
                .font(.caption2)
            #if !BANNER_PREVIEW_QA
            Button("広告QA（テスト端末専用）") { showsQA = true }
                .font(.footnote)
            #endif
            Text("広告表示確認 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                .font(.caption2)
            #endif
            removeAdsSection
            Button("広告のプライバシー設定") { showsAdPrivacy = true }
                .font(.footnote)
        }
    }

    /// 広告を削除（非消耗型課金）と購入の復元（spec §11.2）。購入済みなら何も出さない
    @ViewBuilder private var removeAdsSection: some View {
        if !monetization.store.hasRemovedAds {
            VStack(spacing: 8) {
                Button {
                    Task { await monetization.store.purchaseRemoveAds() }
                } label: {
                    if let product = monetization.store.removeAdsProduct {
                        Text("広告を削除（\(product.displayPrice)）")
                    } else {
                        Text("広告を削除")
                    }
                }
                .chromeButtonStyle()
                .disabled(monetization.store.removeAdsProduct == nil || monetization.store.isLoading)

                Button("購入を復元") {
                    Task { await monetization.store.restore() }
                }
                .font(.footnote)
                .disabled(monetization.store.isLoading)

                if let error = monetization.store.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - CPU 対戦の設定

/// 自分の側（先行/後攻）と難易度を 1 画面で選ぶ。難易度を押すと対局を始める。
/// 前回の選択を覚えておき、「前回」の印を付ける
private struct CPUSetupSheet: View {
    let onStart: (Player, CPUDifficulty) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cpuSetup.humanIsSecond") private var humanIsSecond = false
    /// 前回選んだ難易度の番号。まだ遊んでいないときは -1（「おすすめ」を ふつう に付ける）
    @AppStorage("cpuSetup.difficultyIndex") private var difficultyIndex = -1

    private var human: Player { humanIsSecond ? .second : .first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CPUと対戦").font(.title2.bold())
                Spacer()
                Button("キャンセル") { dismiss() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("あなたの側").font(.subheadline.weight(.semibold))
                Picker("あなたの側", selection: $humanIsSecond) {
                    Text("先行").tag(false)
                    Text("後攻").tag(true)
                }
                .pickerStyle(.segmented)
                Text(humanIsSecond
                     ? "後から打ちます。爆弾を 2 枚使えます。"
                     : "先に打てます。爆弾は 1 枚まで使えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CPUの強さ").font(.subheadline.weight(.semibold))
                ForEach(Array(CPUDifficulty.allCases.enumerated()), id: \.offset) { index, difficulty in
                    Button {
                        difficultyIndex = index
                        onStart(human, difficulty)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(difficulty.displayName).font(.headline)
                                    if let badge = badge(for: index) {
                                        Text(badge)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Theme.brandTint.opacity(0.18), in: Capsule())
                                            .foregroundStyle(Theme.brandTint)
                                    }
                                }
                                Text(difficulty.summary).font(.caption).foregroundStyle(Color.primary.opacity(0.7))
                            }
                            .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            HStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { dot in
                                    Circle()
                                        .fill(dot <= index ? Theme.brandTint : Color.secondary.opacity(0.3))
                                        .frame(width: 9, height: 9)
                                }
                            }
                            .accessibilityHidden(true)
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityLabel(difficulty.displayName)
                    .accessibilityHint(difficulty.summary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 20)
    }

    /// 前回の難易度には「前回」、初回は ふつう に「おすすめ」
    private func badge(for index: Int) -> String? {
        if index == difficultyIndex { return "前回" }
        if difficultyIndex < 0 && index == 1 { return "おすすめ" }
        return nil
    }
}

private extension CPUDifficulty {
    /// 難易度の説明（読みの深さは CPUProfile のプリセットに対応）
    var summary: String {
        switch self {
        case .easy: "ときどき読み違えます。まずはここから"
        case .normal: "2 手先まで読んで、着実に打ちます"
        case .hard: "3 手先まで読み、終盤は読み切ります"
        }
    }
}

// MARK: - 紋章・装飾

/// タイトルの紋章。アプリアイコンと同じ、先行（橙）と後攻（緑）で塗り分けた駒に「十」。
/// 開いたときに 1 回転し、タップでもう一度回る（動きを減らす設定では回らない）
struct HeroChip: View {
    @State private var spin: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            ZStack {
                half(.first, d: d, leading: true)
                half(.second, d: d, leading: false)
                Circle()
                    .fill(Theme.heroPaper)
                    .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: d * 0.025))
                    .frame(width: d * 0.5, height: d * 0.5)
                    .shadow(color: .black.opacity(0.2), radius: d * 0.02, y: d * 0.015)
                    .overlay {
                        Text("十")
                            .font(.system(size: d * 0.34, weight: .black))
                            .foregroundStyle(Theme.heroInk)
                    }
                    .offset(y: -d * 0.015)
            }
            .shadow(color: .black.opacity(0.28), radius: d * 0.07, y: d * 0.05)
            .frame(width: d, height: d)
            .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
            .contentShape(Circle())
            .onTapGesture {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { spin += 360 }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            guard !reduceMotion else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(response: 0.9, dampingFraction: 0.65)) { spin += 360 }
            }
        }
    }

    /// 駒の左半分（先行）か右半分（後攻）。同じ駒を 2 枚重ねて半分ずつ切り出すと、縦の継ぎ目で色が分かれる
    private func half(_ owner: Player, d: CGFloat, leading: Bool) -> some View {
        ChipBase(color: owner.color, thickness: d * 0.035) {
            ZStack {
                Circle().strokeBorder(Theme.chipShade, lineWidth: d * 0.05)
                ChipNotches(count: 12, inset: d * 0.065, depth: d * 0.1, width: d * 0.075)
                    .fill(Theme.chipInlay)
                    .rotationEffect(.degrees(15))
            }
        } top: {}
        .frame(width: d, height: d)
        .mask {
            HStack(spacing: 0) {
                Rectangle().fill(leading ? .black : .clear)
                Rectangle().fill(leading ? .clear : .black)
            }
        }
    }
}

/// タイトル背景の装飾。足すと 10 になる駒（7+3、4+6）を、画面の端にぼかして散らす。
/// ガラスのボタンの背後に色を作る役目も兼ねる
private struct TitleDecoration: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                chip(.first, 7, size: 96, x: 0.10, y: 0.09, angle: -14, in: geometry.size)
                chip(.second, 3, size: 72, x: 0.92, y: 0.17, angle: 12, in: geometry.size)
                chip(.second, 4, size: 88, x: 0.04, y: 0.80, angle: 10, in: geometry.size)
                chip(.first, 6, size: 78, x: 0.97, y: 0.72, angle: -8, in: geometry.size)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func chip(_ owner: Player, _ number: Int, size: CGFloat, x: CGFloat, y: CGFloat, angle: Double, in area: CGSize) -> some View {
        ChipView(piece: Piece(owner, .number(number)), isFlipped: false, isLastPlaced: false)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
            .opacity(0.32)
            .blur(radius: 1)
            .position(x: area.width * x, y: area.height * y)
    }
}

private extension View {
    /// 画面を開いたときに、下からふわっと現れる。`appeared` が true になるまでは透明
    func reveal(_ appeared: Bool, delay: Double) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }
}
