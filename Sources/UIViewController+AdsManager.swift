import UIKit
import SwifterSwift
import DeviceKit
import GoogleMobileAds
@preconcurrency import SwiftyUserDefaults
import SnapKit

@MainActor
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
        let adsManager = AdsManager.shared
        adsManager.incrementInterstitialActionsCounter()
        
        guard let appLastInterstitialShown = adsManager.getLastInterstitialShown() else {
            adsManager.updateLastInterstitialShown(Date())
            return
        }
        
        let actionsPerInterstitial = adsManager.currentActionsPerInterstitial
        
        // Show an ad every few actions, no more than 1 per 20 minutes
        if !adsManager.isInterstitialLoading,
           actionsPerInterstitial > 0,
           Int.random(in: 0 ... 2) == 0,
           appLastInterstitialShown < Date().adding(.minute, value: -20), // last shown > 20 min ago
           adsManager.getInterstitialActionsCounter() > actionsPerInterstitial
        {
            if adsManager.currentInterstitial != nil {
                showInterstitial()
            } else {
                adsManager.loadInterstitial()
            }
        }
    }
    
    public func showInterstitial() {
        let adsManager = AdsManager.shared
        let actionsPerInterstitial = adsManager.currentActionsPerInterstitial
        
        if let currentInterstitial = adsManager.currentInterstitial,
           actionsPerInterstitial > 0
        {
            adsManager.resetInterstitialActionsCounter()
            adsManager.updateLastInterstitialShown(Date())
            
            DispatchQueue.main.async {
                currentInterstitial.present(from: self)
            }
        }
    }
}
