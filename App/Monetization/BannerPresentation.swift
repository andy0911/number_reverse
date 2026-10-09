import Foundation
import Observation
import os

/// ローカル案内の露出は広告SDKのインプレッション/収益イベントとは別系統。
/// 外部送信や永続識別子は追加しない。セッション内の診断カウンタとOSログのみ。
@MainActor @Observable
final class BannerMetrics {
    private(set) var localPromos = 0
    private(set) var networkImpressions = 0
    private(set) var demoImpressions = 0
    private(set) var paidEvents = 0
    func promo() { localPromos += 1; adsLogger.info("banner_local_promo_display") }
    func impression(isDemo: Bool) {
        if isDemo { demoImpressions += 1 } else { networkImpressions += 1 }
        adsLogger.info("banner_sdk_impression demo=\(isDemo, privacy: .public)")
    }
    func paid(isDemo: Bool) {
        guard !isDemo else { return }
        paidEvents += 1
        adsLogger.info("banner_sdk_paid_event")
    }
}

@MainActor @Observable
final class BannerPresentation {
    enum Phase: Equatable { case loading, received, failed(String), stopped }
    private(set) var phase: Phase = .loading
    var showsAd: Bool { phase == .received }
    var failure: String? { if case .failed(let message) = phase { message } else { nil } }
    func receive() { guard phase != .stopped else { return }; phase = .received }
    func fail(_ message: String) { guard phase != .stopped else { return }; phase = .failed(message) }
    func restartIfStopped() { guard phase == .stopped else { return }; phase = .loading }
    func stop() { phase = .stopped }
}

/// 所有権の初回照合中は、既購入者へ案内や広告を一瞬表示しない。
enum BannerVisibility {
    static func showsSlot(entitlementsLoaded: Bool, hasRemovedAds: Bool) -> Bool {
        entitlementsLoaded && !hasRemovedAds
    }
}

#if MEDIATION_QA
enum QABannerScenario: String, CaseIterable, Identifiable {
    case liveDemo = "Google公式テスト広告"
    case noFill = "在庫なし（模擬）"
    case offline = "通信失敗（模擬）"
    case recovering = "失敗→Googleテスト広告（模擬）"
    case initializing = "SDK準備中（模擬）"
    case consentBlocked = "同意変更・要求停止（模擬）"
    case purchased = "購入済み（模擬）"
    case restored = "復元済み（模擬）"
    var id: String { rawValue }
    var removesAds: Bool { self == .purchased || self == .restored }
    var allowsRequest: Bool { self == .liveDemo || self == .noFill || self == .offline || self == .recovering }
    var simulatedFailure: String? {
        switch self {
        case .noFill: "QA no-fill / code 1（通信なし）"
        case .offline: "QA offline / code -1009（通信なし）"
        case .recovering: "QA recovery（初回失敗を模擬・5秒後に公式テスト広告）"
        default: nil
        }
    }
}
#endif
