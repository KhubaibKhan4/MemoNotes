//
//  SplashScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 03/02/2025.
//
import SwiftUI

struct SplashScreen: View {
    @EnvironmentObject var appManager: AppManager
    
    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appManager.isDark ? .black : .white)
        .preferredColorScheme(appManager.isDark ? .dark : .light)
    }
}
