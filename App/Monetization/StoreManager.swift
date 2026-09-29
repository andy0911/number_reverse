import Foundation
import StoreKit

/// 「広告を削除」（非消耗型）の購入・復元・所有状況を管理する。spec §11.2
@MainActor
@Observable
final class StoreManager {
    private(set) var hasRemovedAds = false
    private(set) var removeAdsProduct: Product?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // アプリ起動と寿命を共にするシングルトンとして扱うため、監視タスクを明示的にキャンセルしない
    // （途中終了しても、アプリ終了とともに破棄される）
    init() {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = update {
                    await self.apply(transaction)
                }
            }
        }
    }

    /// 起動時に 1 回呼ぶ: 商品情報の取得と、既存の所有権（過去の購入）の反映
    func start() async {
        await refreshEntitlements()
        await loadProduct()
    }

    private func loadProduct() async {
        guard removeAdsProduct == nil else { return }
        do {
            let products = try await Product.products(for: [MonetizationConfig.removeAdsProductID])
            removeAdsProduct = products.first
        } catch {
            errorMessage = "商品情報の取得に失敗しました"
        }
    }

    private func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.productID == MonetizationConfig.removeAdsProductID {
                hasRemovedAds = true
            }
        }
    }

    private func apply(_ transaction: Transaction) async {
        if transaction.productID == MonetizationConfig.removeAdsProductID {
            hasRemovedAds = true
        }
        await transaction.finish()
    }

    func purchaseRemoveAds() async {
        guard let product = removeAdsProduct else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await apply(transaction)
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入処理でエラーが発生しました"
        }
    }

    /// 審査要件: 非消耗型課金には復元手段が必須
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "復元に失敗しました"
        }
    }
}
