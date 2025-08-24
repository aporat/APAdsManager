// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APAdsManager",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "APAdsManager",
            targets: ["APAdsManager"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SwifterSwift/SwifterSwift.git", from: "7.0.0"),
        .package(url: "https://github.com/sunshinejr/SwiftyUserDefaults.git", from: "5.0.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
        .package(url: "https://github.com/devicekit/DeviceKit.git", from: "5.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "12.0.0")
   ],
    targets: [
        .target(
            name: "APAdsManager",
            dependencies: [
                "SwifterSwift",
                "SwiftyUserDefaults",
                "SnapKit",
                "DeviceKit",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ]
        )
    ]
)
