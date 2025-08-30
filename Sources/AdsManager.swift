import DeviceKit
import GoogleMobileAds
import SwiftyUserDefaults
import AppTrackingTransparency
import AdSupport
import UIKit
import SwifterSwift

extension DefaultsKeys {
    var admob: DefaultsKey<Bool> { .init("kServiceAdMob", defaultValue: true) }
    var ATTrackingManagerPermissions: DefaultsKey<Bool> { .init("kATTrackingManagerPermissions", defaultValue: true) }
    var banners: DefaultsKey<Bool> { .init("kServiceBanners", defaultValue: true) }
    var actionsPerInterstitial: DefaultsKey<Int> { .init("kServiceActionsPerInterstitial", defaultValue: 15) }
    var appLastInterstitialShown: DefaultsKey<Date?> { .init("AppLastInterstitialShown") }
    var appInterstitialActionsCounter: DefaultsKey<Int> { .init("AppInterstitialActionsCounter", defaultValue: 0) }
}

public extension DefaultsKeys {
    var adsMode: DefaultsKey<Bool> { .init("kAdsMode", defaultValue: false) }
    var coinsPerRewardVideo: DefaultsKey<Int> { .init("kServiceCoinsPerRewardVideo", defaultValue: 0) }
}

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
    
    public func startSDK(interstitialUnitId: String?, bannerUnitId: String? = nil, rewardVideoUnitId: String? = nil) {
        AdMobBannerUnitId = bannerUnitId
        AdMobInterstitialUnitId = interstitialUnitId
        AdMobRewardAdUnitId = rewardVideoUnitId
        
        if Defaults.admob, !isSDKLoaded {
            isSDKLoaded = true
            MobileAds.shared.start()
        }
    }
    
    public func askForPermissions(
        completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void
    ) {
        DispatchQueue.main.async {
            let request: () -> Void = {
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    ATTrackingManager.requestTrackingAuthorization { status in
                        DispatchQueue.main.async { completion(status) }
                    }
                } else {
                    completion(ATTrackingManager.trackingAuthorizationStatus)
                }
            }

            if UIApplication.shared.applicationState == .active {
                request()
            } else {
                var token: NSObjectProtocol?
                token = NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { [token] _ in
                    if let observer = token {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    request()
                }
            }
        }
    }
    
    public func loadRewardAd(delegate: AdsManagerRewardAdDelegate?) {
        if Defaults.admob,
           isSDKLoaded,
           Defaults.coinsPerRewardVideo > 0,
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
                guard let self else { return }
                
                if error != nil {
                    self.rewardVideoDelegate?.rewardVideoDidFailToLoad()
                } else {
                    self.rewardVideoDelegate?.rewardVideoDidReceive()
                }
                
                self.isRewardAdLoading = false
                self.currentRewardAd = ad
                
                let options = ServerSideVerificationOptions()
                options.userIdentifier = self.userIdentifier
                self.currentRewardAd?.serverSideVerificationOptions = options
                self.currentRewardAd?.fullScreenContentDelegate = self
            }
        }
    }
    
    func loadBanner(delegate: AdsManagerBannerDelegate, rootViewController: UIViewController) {
        if Defaults.banners,
           Defaults.admob,
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
            currentBannerView?.load(Request())   // use explicit load instead of isAutoloadEnabled
        }
    }
    
    public func loadInterstitial() {
        if Defaults.admob,
           isSDKLoaded,
           !isInterstitialLoading,
           Defaults.actionsPerInterstitial > 0,
           let adUnitId = AdMobInterstitialUnitId
        {
            isInterstitialLoading = true
            
            let currentAdUnitId = UIApplication.shared.inferredEnvironment == .debug
                ? "ca-app-pub-3940256099942544/4411468910"
                : adUnitId
            
            let request = Request()
            InterstitialAd.load(with: currentAdUnitId, request: request) { [weak self] ad, error in
                guard let self else { return }
                if let currentAd = ad, error == nil {
                    self.currentInterstitial = currentAd
                    self.currentInterstitial?.fullScreenContentDelegate = self
                }
                self.isInterstitialLoading = false
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
