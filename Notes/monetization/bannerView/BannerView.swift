//
//  BannerView.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 04/02/2025.
//
import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    private let adUnitId = "ca-app-pub-3940256099942544/2435281174i"
    
    func makeUIView(context: Context) -> UIView {
        @AppStorage("isSubscribed") var isSubscribed: Bool = false
        
        let containerView = UIView()
        
        if !isSubscribed {
            containerView.backgroundColor = UIColor.systemGray5
            
            let bannerView = BannerView(adSize: AdSizeLargeBanner)
            bannerView.adUnitID = adUnitId
            bannerView.rootViewController = UIApplication.shared.windows.first?.rootViewController
            bannerView.load(Request())
            
            containerView.addSubview(bannerView)
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                bannerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                bannerView.widthAnchor.constraint(equalToConstant: 320),
                bannerView.heightAnchor.constraint(equalToConstant: 100)
            ])
        } else {
            containerView.backgroundColor = .clear
            containerView.isHidden = true
        }
        
        return containerView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

