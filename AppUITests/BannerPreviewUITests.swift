import XCTest

final class BannerPreviewUITests: XCTestCase {
    @MainActor
    func testOfficialDemoInGameAndExit() throws {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "Dismiss simulator account prompts") { alert in
            for label in ["キャンセル", "Cancel"] {
                let cancel = alert.buttons[label]
                if cancel.exists { cancel.tap(); return true }
            }
            return false
        }
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["qaBannerPreviewStart"]
        guard start.waitForExistence(timeout: 15) else {
            throw XCTSkip("Run this UI test with MEDIATION_QA; the entry is intentionally absent from Release.")
        }
        let reject = app.buttons["Do not consent"].firstMatch
        if reject.waitForExistence(timeout: 45) {
            let choices = app.buttons.matching(identifier: "Do not consent").allElementsBoundByIndex
            print("Consent buttons: \(choices.map { "\($0.frame) hittable=\($0.isHittable)" })")
            (choices.last(where: { $0.isHittable }) ?? choices.last!).tap()
        }
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyTracking = system.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label == %@", "トラッキングしない", "Ask App Not to Track")).firstMatch
        if denyTracking.waitForExistence(timeout: 8) { denyTracking.tap() }
        start.tap()
        XCTAssertTrue(app.buttons["qaBannerStatus"].waitForExistence(timeout: 10))
        let banner = app.descendants(matching: .any)["qaPreviewBannerContainer"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        let loaded = NSPredicate(format: "value == %@", "loaded")
        let received = XCTNSPredicateExpectation(predicate: loaded, object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [received], timeout: 100), .completed, app.debugDescription)
        XCTAssertEqual(banner.frame.width, app.frame.height < 850 ? 320 : app.frame.width - 24, accuracy: 2)
        XCTAssertGreaterThan(banner.frame.height, 0)
        XCTAssertLessThanOrEqual(banner.frame.maxY, app.frame.maxY - (app.frame.height < 750 ? 0 : 20))
        // 受信済みバナーを前面復帰後も維持する。広告自体はタップしない。
        XCUIDevice.shared.press(.home)
        app.activate()
        let foregroundBanner = XCTNSPredicateExpectation(predicate: loaded, object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [foregroundBanner], timeout: 15), .completed)
        let board = app.descendants(matching: .any)["qaGameBoard"].firstMatch
        XCTAssertTrue(board.exists)
        XCTAssertLessThan(board.frame.maxY, banner.frame.minY)
        let piece = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1")).firstMatch
        print("Geometry screen=\(app.frame) board=\(board.frame) banner=\(banner.frame) piece=\(piece.frame)")
        XCTAssertGreaterThanOrEqual(board.frame.height, 280)
        XCTAssertGreaterThanOrEqual(piece.frame.height, 44)
        XCTAssertTrue(piece.isHittable)
        piece.tap()
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.4375, dy: 0.5625)).tap()
        let nextTurn = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "初期配置 2-2")).firstMatch
        XCTAssertTrue(nextTurn.waitForExistence(timeout: 5))
        if app.frame.height < 750 {
            let handScroll = app.scrollViews.firstMatch
            handScroll.swipeLeft()
            let lastPiece = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "B、")).firstMatch
            XCTAssertTrue(lastPiece.exists)
            XCTAssertGreaterThanOrEqual(lastPiece.frame.minX, 12)
            XCTAssertLessThanOrEqual(lastPiece.frame.maxX, app.frame.maxX - 12)
            handScroll.swipeRight()
        }
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Google-demo-banner-in-game"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["qaBannerStatus"].tap()
        XCTAssertTrue(app.staticTexts["テスト広告の状態"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["状態: 受信済み"].exists)
        app.buttons["閉じる"].tap()
        for scenario in ["noFill", "offline", "initializing", "consentBlocked"] {
            app.buttons["qaBannerStatus"].tap()
            app.buttons["qaScenario_" + scenario].tap()
            let promo = app.buttons["localRemoveAdsPromo"]
            XCTAssertTrue(promo.waitForExistence(timeout: 5), scenario)
            XCTAssertEqual(banner.value as? String, "local-promo")
            XCTAssertGreaterThanOrEqual(promo.frame.minY, board.frame.maxY)
            XCTAssertLessThanOrEqual(promo.frame.maxY, app.frame.maxY - (app.frame.height < 750 ? 0 : 15))
        }
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["localRemoveAdsPromo"].waitForExistence(timeout: 5))
        let fallbackShot = XCTAttachment(screenshot: app.screenshot())
        fallbackShot.name = "Local-promo-without-network"; fallbackShot.lifetime = .keepAlways; add(fallbackShot)
        // 失敗後に同じcontrollerを保持できれば、5秒後の公式テスト広告を受信する。
        app.buttons["qaBannerStatus"].tap()
        app.buttons["qaScenario_recovering"].tap()
        XCTAssertTrue(app.buttons["localRemoveAdsPromo"].waitForExistence(timeout: 3))
        let afterFailure = XCTNSPredicateExpectation(predicate: loaded, object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [afterFailure], timeout: 100), .completed)
        for scenario in ["purchased", "restored"] {
            app.buttons["qaBannerStatus"].tap()
            app.buttons["qaScenario_" + scenario].tap()
            XCTAssertFalse(banner.exists)
            XCTAssertFalse(app.buttons["localRemoveAdsPromo"].exists)
        }
        app.buttons["qaBannerStatus"].tap()
        app.buttons["qaScenario_liveDemo"].tap()
        let recovered = XCTNSPredicateExpectation(predicate: loaded, object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [recovered], timeout: 100), .completed)
        let back = app.buttons["タイトルへ"].firstMatch
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.buttons["2人で対戦"].tap()
        XCTAssertFalse(app.buttons["qaBannerStatus"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["qaPreviewBannerContainer"].firstMatch.exists)
        app.buttons["タイトルへ"].firstMatch.tap()
        start.tap()
        XCTAssertTrue(app.buttons["qaBannerStatus"].waitForExistence(timeout: 10))
        let reloaded = XCTNSPredicateExpectation(predicate: loaded, object: app.descendants(matching: .any)["qaPreviewBannerContainer"].firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [reloaded], timeout: 100), .completed)
    }
    @MainActor
    func testFirstConsentFailureRecoversAfterCooldown() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-qaFailFirstConsent"]
        app.launch()
        let start = app.buttons["qaBannerPreviewStart"]
        guard start.waitForExistence(timeout: 15) else {
            throw XCTSkip("Requires DEBUG MEDIATION_QA")
        }
        let firstAttempt = NSPredicate(format: "value == %@", "起動試行: 1 / SDK: 待機")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: firstAttempt, object: start)], timeout: 10), .completed)
        XCUIDevice.shared.press(.home)
        app.activate()
        // 30秒経過前のforegroundでは再試行しない。
        XCTAssertEqual(start.value as? String, "起動試行: 1 / SDK: 待機")
        let reject = app.buttons["Do not consent"].firstMatch
        if reject.waitForExistence(timeout: 50) {
            let choices = app.buttons.matching(identifier: "Do not consent").allElementsBoundByIndex
            (choices.last(where: { $0.isHittable }) ?? choices.last!).tap()
        }
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyTracking = system.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label == %@", "トラッキングしない", "Ask App Not to Track")).firstMatch
        if denyTracking.waitForExistence(timeout: 8) { denyTracking.tap() }
        let recovered = NSPredicate(format: "value == %@", "起動試行: 2 / SDK: 完了")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: recovered, object: start)], timeout: 60), .completed, app.debugDescription)
        start.tap()
        let banner = app.descendants(matching: .any)["qaPreviewBannerContainer"].firstMatch
        let loaded = NSPredicate(format: "value == %@", "loaded")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: loaded, object: banner)], timeout: 100), .completed)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Consent-failure-recovered-to-Google-demo"; shot.lifetime = .keepAlways; add(shot)
    }
}
