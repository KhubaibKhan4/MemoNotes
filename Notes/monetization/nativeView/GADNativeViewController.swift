//
//  NativeAdView.swift
//  Ai Translator Pro
//
//  Created by Muhammad Khubaib Imtiaz on 29/01/2025.
//
import SwiftUI
import GoogleMobileAds


// This sample code is based on Google's examples
// https://github.com/googleads/googleads-mobile-ios-examples/releases/tag/7.22

class GADNativeViewController: UIViewController {

  /// The height constraint applied to the ad view, where necessary.
  var heightConstraint: NSLayoutConstraint?

  /// The ad loader. You must keep a strong reference to the GADAdLoader during the ad loading
  /// process.
    var adLoader: AdLoader!

  /// The native ad view that is being presented.
    var nativeAdView: NativeAdView!

  /// The ad unit ID.
  let adUnitID = "ca-app-pub-3940256099942544/3986624511"

  override func viewDidLoad() {
    super.viewDidLoad()

    guard
      let nibObjects = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil),
      let adView = nibObjects.first as? NativeAdView
    else {
      assert(false, "Could not load nib file for adView")
        return
    }
    setAdView(adView)
    refreshAd()
  }

    func setAdView(_ view: NativeAdView) {

    nativeAdView = view
    self.view.addSubview(nativeAdView)
    nativeAdView.translatesAutoresizingMaskIntoConstraints = false

    // Layout constraints for positioning the native ad view to stretch the entire width and height
    // of the nativeAdPlaceholder.
    let viewDictionary = ["_nativeAdView": nativeAdView!]
    self.view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[_nativeAdView]|",
        options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: viewDictionary)
    )
    self.view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[_nativeAdView]|",
        options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: viewDictionary)
    )
  }

  // MARK: - Actions

  /// Refreshes the native ad.
  func refreshAd() {
      adLoader = AdLoader(
      adUnitID: adUnitID, rootViewController: self,
      adTypes: [.native], options: nil)
    adLoader.delegate = self
      adLoader.load(Request())
  }

  /// Returns a `UIImage` representing the number of stars from the given star rating; returns `nil`
  /// if the star rating is less than 3.5 stars.
  func imageOfStars(from starRating: NSDecimalNumber?) -> UIImage? {
    guard let rating = starRating?.doubleValue else {
      return nil
    }
    if rating >= 5 {
      return UIImage(named: "stars_5")
    } else if rating >= 4.5 {
      return UIImage(named: "stars_4_5")
    } else if rating >= 4 {
      return UIImage(named: "stars_4")
    } else if rating >= 3.5 {
      return UIImage(named: "stars_3_5")
    } else {
      return nil
    }
  }
}

extension GADNativeViewController: VideoControllerDelegate {

    func videoControllerDidEndVideoPlayback(_ videoController: VideoController) {
    print("Video playback has ended.")
  }
}

extension GADNativeViewController: NativeAdLoaderDelegate {

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {

    // Set ourselves as the native ad delegate to be notified of native ad events.
    nativeAd.delegate = self

    // Deactivate the height constraint that was set when the previous video ad loaded.
    heightConstraint?.isActive = false

    // Populate the native ad view with the native ad assets.
    // The headline and mediaContent are guaranteed to be present in every native ad.
    (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
    nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

    // Some native ads will include a video asset, while others do not. Apps can use the
    // GADVideoController's hasVideoContent property to determine if one is present, and adjust their
    // UI accordingly.
    let mediaContent = nativeAd.mediaContent
    if mediaContent.hasVideoContent {
      // By acting as the delegate to the GADVideoController, this ViewController receives messages
      // about events in the video lifecycle.
      mediaContent.videoController.delegate = self
      print("Ad contains a video asset.")
    } else {
      print("Ad does not contain a video.")
    }

    // This app uses a fixed width for the GADMediaView and changes its height to match the aspect
    // ratio of the media it displays.
    if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
      heightConstraint = NSLayoutConstraint(
        item: mediaView,
        attribute: .height,
        relatedBy: .equal,
        toItem: mediaView,
        attribute: .width,
        multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
        constant: 0)
      heightConstraint?.isActive = true
    }

    // These assets are not guaranteed to be present. Check that they are before
    // showing or hiding them.
    (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
    nativeAdView.bodyView?.isHidden = nativeAd.body == nil

    (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
    nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

    (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
    nativeAdView.iconView?.isHidden = nativeAd.icon == nil

    (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(from: nativeAd.starRating)
    nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

    (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
    nativeAdView.storeView?.isHidden = nativeAd.store == nil

    (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
    nativeAdView.priceView?.isHidden = nativeAd.price == nil

    (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
    nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

    // In order for the SDK to process touch events properly, user interaction should be disabled.
    nativeAdView.callToActionView?.isUserInteractionEnabled = false

    // Associate the native ad view with the native ad object. This is
    // required to make the ad clickable.
    // Note: this should always be done after populating the ad views.
    nativeAdView.nativeAd = nativeAd
  }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    print("\(adLoader) failed with error: \(error.localizedDescription)")
  }
}

// MARK: - GADNativeAdDelegate implementation

extension GADNativeViewController: NativeAdDelegate {

    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

    func nativeAdIsMuted(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }
}
