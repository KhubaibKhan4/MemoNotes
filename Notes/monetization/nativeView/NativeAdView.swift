//
//  NativeAdView.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 04/02/2025.
//

import UIKit
import SwiftUI

struct GADNativeViewControllerWrapper : UIViewControllerRepresentable {
    @AppStorage("isSubscribed") var isSubscribed: Bool = false
    
    func makeUIViewController(context: Context) -> UIViewController {
        if isSubscribed {
            return UIViewController()
        }
        
        let viewController = GADNativeViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isSubscribed {
            uiViewController.view.isHidden = true
        } else {
            uiViewController.view.isHidden = false
        }
    }
    
}
