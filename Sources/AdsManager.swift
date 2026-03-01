import DeviceKit
@preconcurrency import GoogleMobileAds
import AppTrackingTransparency
import AdSupport
import UIKit
import SwifterSwift

public protocol AdsManagerRewardAdDelegate: AnyObject {
    func rewardVideoDidReceive()
    func rewardVideoDidClose()
    func rewardVideoDidRewardUser()
    func rewardVideoDidFailToLoad()
}

public protocol AdsManagerBannerDelegate: AnyObject {
    func bannerDidReceive(_ bannerView: UIView)
    func bannerDidFailToReceive(_ bannerView: UIView)
}

@MainActor
public final class AdsManager: NSObject {
    public static let shared = AdsManager()
    
    weak var rewardVideoDelegate: AdsManagerRewardAdDelegate?
    fileprivate weak var bannerDelegate: AdsManagerBannerDelegate?
    
    var currentInterstitial: InterstitialAd?
    var currentRewardAd: RewardedAd?
    fileprivate var currentBannerView: BannerView?
    
    fileprivate var isSDKLoaded = false
    var isInterstitialLoading = false
    var isRewardAdLoading = false
    
    fileprivate var AdMobInterstitialUnitId: String?
    fileprivate var AdMobRewardAdUnitId: String?
    fileprivate var AdMobBannerUnitId: String?
    
    public var userIdentifier: String?
    
    // Interstitial tracking
    private var lastInterstitialShown: Date?
    private var interstitialActionsCounter: Int = 0
    
    // Remote Config values
    private var coinsPerRewardVideo: Int = 0
    private var actionsPerInterstitial: Int = 0
    private var bannersEnabled: Bool = true
    
    // Public accessors for remote config values
    public var currentActionsPerInterstitial: Int {
        return actionsPerInterstitial
    }
    
    public func startSDK(
        interstitialUnitId: String?,
        bannerUnitId: String? = nil,
        rewardVideoUnitId: String? = nil
    ) {
        AdMobBannerUnitId = bannerUnitId
        AdMobInterstitialUnitId = interstitialUnitId
        AdMobRewardAdUnitId = rewardVideoUnitId
        
        if !isSDKLoaded {
            isSDKLoaded = true
            MobileAds.shared.start()
        }
    }
    
    /// Update remote config values dynamically
    public func updateRemoteConfigValues(
        coinsPerRewardVideo: Int,
        actionsPerInterstitial: Int,
        bannersEnabled: Bool
    ) {
        self.coinsPerRewardVideo = coinsPerRewardVideo
        self.actionsPerInterstitial = actionsPerInterstitial
        self.bannersEnabled = bannersEnabled
    }
    
    // MARK: - Interstitial Counter Management
    
    public func incrementInterstitialActionsCounter() {
        interstitialActionsCounter += 1
    }
    
    public func resetInterstitialActionsCounter() {
        interstitialActionsCounter = 0
    }
    
    public func getInterstitialActionsCounter() -> Int {
        return interstitialActionsCounter
    }
    
    public func updateLastInterstitialShown(_ date: Date) {
        lastInterstitialShown = date
    }
    
    public func getLastInterstitialShown() -> Date? {
        return lastInterstitialShown
    }
    
    @discardableResult
    public func askForPermission() async -> ATTrackingManager.AuthorizationStatus {
        if ATTrackingManager.trackingAuthorizationStatus != .notDetermined {
            return ATTrackingManager.trackingAuthorizationStatus
        }

        return await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    public func loadRewardAd(delegate: AdsManagerRewardAdDelegate?) {
        if isSDKLoaded,
           coinsPerRewardVideo > 0,
           !isRewardAdLoading,
           let adUnitId = AdMobRewardAdUnitId
        {
            isRewardAdLoading = true
            if let currentDelegate = delegate { rewardVideoDelegate = currentDelegate }
            
            let request = Request()
            let currentAdUnitId = UIApplication.shared.inferredEnvironment == .debug
                ? "ca-app-pub-3940256099942544/1712485313"
                : adUnitId
            
            RewardedAd.load(with: currentAdUnitId, request: request) { [weak self] ad, error in
                nonisolated(unsafe) let unsafeAd = ad
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    
                    if error != nil {
                        self.rewardVideoDelegate?.rewardVideoDidFailToLoad()
                    } else {
                        self.rewardVideoDelegate?.rewardVideoDidReceive()
                    }
                    
                    self.isRewardAdLoading = false
                    self.currentRewardAd = unsafeAd
                    
                    if let ad = self.currentRewardAd {
                        let options = ServerSideVerificationOptions()
                        options.userIdentifier = self.userIdentifier
                        ad.serverSideVerificationOptions = options
                        ad.fullScreenContentDelegate = self
                    }
                }
            }
        }
    }
    
    func loadBanner(delegate: AdsManagerBannerDelegate, rootViewController: UIViewController) {
        if bannersEnabled,
           isSDKLoaded,
           let adUnitId = AdMobBannerUnitId
        {
            bannerDelegate = delegate
            
            currentBannerView = BannerView()
            currentBannerView?.rootViewController = rootViewController
            
            let currentAdUnitId = UIApplication.shared.inferredEnvironment == .debug
                ? "ca-app-pub-3940256099942544/2934735716"
                : adUnitId
            currentBannerView?.adUnitID = currentAdUnitId
            
            let viewWidth = rootViewController.view.frame.inset(by: rootViewController.view.safeAreaInsets).width
            currentBannerView?.adSize = currentOrientationAnchoredAdaptiveBanner(width: viewWidth)
            
            currentBannerView?.delegate = self
            currentBannerView?.load(Request()) 
        }
    }
    
    public func loadInterstitial() {
        if isSDKLoaded,
           !isInterstitialLoading,
           actionsPerInterstitial > 0,
           let adUnitId = AdMobInterstitialUnitId
        {
            isInterstitialLoading = true
            
            let currentAdUnitId = UIApplication.shared.inferredEnvironment == .debug
                ? "ca-app-pub-3940256099942544/4411468910"
                : adUnitId
            
            let request = Request()
            InterstitialAd.load(with: currentAdUnitId, request: request) { [weak self] ad, error in
                nonisolated(unsafe) let unsafeAd = ad
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let ad = unsafeAd, error == nil {
                        self.currentInterstitial = ad
                        self.currentInterstitial?.fullScreenContentDelegate = self
                    }
                    self.isInterstitialLoading = false
                }
            }
        }
    }
}

// MARK: - FullScreenContentDelegate

extension AdsManager: FullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if ad is InterstitialAd {
            AdsManager.shared.currentInterstitial = nil
            loadInterstitial()
        } else {
            AdsManager.shared.currentRewardAd = nil
            AdsManager.shared.loadRewardAd(delegate: nil)
            rewardVideoDelegate?.rewardVideoDidClose()
        }
    }
}

// MARK: - BannerViewDelegate

extension AdsManager: BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        bannerDelegate?.bannerDidReceive(bannerView)
    }
    
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        bannerDelegate?.bannerDidFailToReceive(bannerView)
    }
}

