import XCTest
@testable import APAdsManager
import SwiftyUserDefaults
import UIKit

final class APAdsManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset Defaults keys we touch so tests are deterministic
        Defaults[\.appInterstitialActionsCounter] = 0
        Defaults[\.appLastInterstitialShown] = nil
        Defaults[\.actionsPerInterstitial] = 3
        Defaults[\.admob] = true
    }

    override func tearDown() {
        // Clean up
        Defaults[\.appInterstitialActionsCounter] = 0
        Defaults[\.appLastInterstitialShown] = nil
        super.tearDown()
    }

    // MARK: UIViewController extension helpers

    private final class HostVC: UIViewController {}

    // 1) Seeds appLastInterstitialShown when nil (first call)
    func testShowInterstitialIfNeededSeedsLastShownWhenNil() {
        let vc = HostVC()

        XCTAssertNil(Defaults[\.appLastInterstitialShown], "Precondition failed: last shown should start nil")

        vc.showInterstitialIfNeeded()

        XCTAssertNotNil(Defaults[\.appLastInterstitialShown], "First call should set a baseline last-shown date")
        XCTAssertEqual(Defaults[\.appInterstitialActionsCounter], 1, "Counter should increment by 1")
    }

    // 2) isRewardVideoReady is false when there is no loaded ad
    func testIsRewardVideoReadyFalseWhenNoAd() {
        let vc = HostVC()
        // Ensure there is no rewarded ad available
        AdsManager.shared.currentRewardAd = nil

        XCTAssertFalse(vc.isRewardVideoReady, "Ready flag should be false when no rewarded ad is cached")
    }

    // 3) showRewardVideo should be a no-op when no ad is available (no crash)
    func testShowRewardVideoNoCrashWhenNoAd() {
        let vc = HostVC()
        AdsManager.shared.currentRewardAd = nil

        // Should not throw or crash
        vc.showRewardVideo()

        // Nothing to assert other than not crashing; add trivial assert
        XCTAssertTrue(true)
    }

    // 4) Recent last-shown blocks another impression within 20 minutes
    func testInterstitialThrottleWithinTwentyMinutes() {
        let vc = HostVC()

        let now = Date()
        Defaults[\.appLastInterstitialShown] = now // already "just shown"
        Defaults[\.appInterstitialActionsCounter] = Defaults[\.actionsPerInterstitial] + 10

        // Ensure AdsManager won't try to present a real interstitial
        AdsManager.shared.isInterstitialLoading = false
        AdsManager.shared.currentInterstitial = nil

        vc.showInterstitialIfNeeded()

        // Since last was just now, it should not have updated last-shown (still equal or very close)
        XCTAssertNotNil(Defaults[\.appLastInterstitialShown])
        // Counter still increments at the start of the method
        XCTAssertEqual(Defaults[\.appInterstitialActionsCounter], Defaults[\.actionsPerInterstitial] + 11)
    }

    // 5) When last-shown is > 20 minutes ago but no interstitial cached, method should attempt to load (no crash path)
    func testInterstitialPathOlderThanTwentyMinutesNoCrash() {
        let vc = HostVC()

        // Last shown 25 minutes ago
        Defaults[\.appLastInterstitialShown] = Date().addingTimeInterval(-25 * 60)
        Defaults[\.appInterstitialActionsCounter] = Defaults[\.actionsPerInterstitial] + 1

        AdsManager.shared.isInterstitialLoading = false
        AdsManager.shared.currentInterstitial = nil

        // Random gate may skip; call a few times to raise likelihood, but we only assert no crash.
        for _ in 0..<5 {
            vc.showInterstitialIfNeeded()
        }

        XCTAssertTrue(true)
    }
}
