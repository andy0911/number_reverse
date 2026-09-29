import UIKit

extension UIViewController {
    /// インタースティシャル広告の提示元に使う、現在表示中のシーンの最前面 ViewController
    @MainActor
    static func topMost() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController?.topMostPresented
    }

    private var topMostPresented: UIViewController {
        presentedViewController?.topMostPresented ?? self
    }
}
