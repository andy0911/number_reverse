/// SDK に渡す同意値の判定。情報不足やトラッキング拒否時は許可を推測しない。
enum UnityPrivacyPolicy {
    static func permitsPersonalization(explicitlyAllowed: Bool, gdprApplies: Int?, trackingAuthorized: Bool) -> Bool {
        explicitlyAllowed && gdprApplies == 0 && trackingAuthorized
    }
}
