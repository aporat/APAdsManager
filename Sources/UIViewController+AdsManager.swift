import UIKit
import SwifterSwift
import DeviceKit
import GoogleMobileAds
import SwiftyUserDefaults
import SnapKit

extension UIViewController {
    public func loadBannerIfNeeded(delegate: AdsManagerBannerDelegate) {
        AdsManager.shared.loadBanner(delegate: delegate, rootViewController: self)
    }
    
    public func reloadBannerIfNeeded(delegate: AdsManagerBannerDelegate, containerView: UIView) {
        DispatchQueue.main.async { [weak self] in
            self?.hideBanner(containerView)
            self?.loadBannerIfNeeded(delegate: delegate)
        }
    }
    
    public func showBannerIfNeeded(_ containerView: UIView, _ bannerView: UIView) {
        DispatchQueue.main.async { [weak self] in
            self?.showBanner(containerView, bannerView)
        }
    }
    
    public func hideBannerIfNeeded(_ containerView: UIView) {
        DispatchQueue.main.async { [weak self] in
            self?.hideBanner(containerView)
        }
    }
    
    public func showBanner(_ containerView: UIView, _ bannerView: UIView) {
        guard let currentBannerView = bannerView as? BannerView else {
            hideBanner(containerView)
            return
        }
        
        currentBannerView.rootViewController = self
        
        if !bannerView.isDescendant(of: containerView) {
            containerView.removeSubviews()
            containerView.addSubview(currentBannerView)
        }
        
        // Snap the container to safe-area bottom and to the banner intrinsic ad size
        containerView.snp.remakeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.width.equalTo(currentBannerView.adSize.size.width)
            make.height.equalTo(currentBannerView.adSize.size.height)
        }
        
        currentBannerView.snp.remakeConstraints { make in
            make.center.equalTo(containerView)
        }
    }
    
    public func hideBanner(_ containerView: UIView) {
        containerView.snp.remakeConstraints { make in
            make.height.equalTo(0)
            make.width.equalTo(0)
            make.bottom.equalToSuperview()
        }
        containerView.removeSubviews()
    }
    
    public var isRewardVideoReady: Bool {
        return AdsManager.shared.currentRewardAd != nil
    }
    
    @objc public func showRewardVideo() {
        DispatchQueue.main.async { [weak self] in
            if let self = self, let currentRewardAd = AdsManager.shared.currentRewardAd {
                currentRewardAd.present(from: self) {
                    AdsManager.shared.rewardVideoDelegate?.rewardVideoDidRewardUser()
                }
            }
        }
    }
    
    public func showInterstitialIfNeeded() {
        Defaults.appInterstitialActionsCounter = Defaults.appInterstitialActionsCounter + 1
        
        guard let appLastInterstitialShown = Defaults.appLastInterstitialShown else {
            Defaults.appLastInterstitialShown = Date()
            return
        }
        
        // Show an ad every few actions, no more than 1 per 20 minutes
        if !AdsManager.shared.isInterstitialLoading,
           Defaults.actionsPerInterstitial > 0,
           Int.random(in: 0 ... 2) == 0,
           appLastInterstitialShown < Date().adding(.minute, value: -20), // last shown > 20 min ago
           Defaults.appInterstitialActionsCounter > Defaults.actionsPerInterstitial
        {
            if AdsManager.shared.currentInterstitial != nil {
                showInterstitial()
            } else {
                AdsManager.shared.loadInterstitial()
            }
        }
    }
    
    public func showInterstitial() {
        if let currentInterstitial = AdsManager.shared.currentInterstitial,
           Defaults.actionsPerInterstitial > 0,
           Defaults.admob
        {
            Defaults.appInterstitialActionsCounter = 0
            Defaults.appLastInterstitialShown = Date()
            
            DispatchQueue.main.async {
                currentInterstitial.present(from: self)
            }
        }
    }
}
