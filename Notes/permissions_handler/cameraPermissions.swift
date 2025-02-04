//
//  cameraPermissions.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 01/01/2025.
//

import SwiftUI
import AVFoundation


struct CameraPermissions: View {
    
    @State private var cameraPermissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    
    
    
    var body: some View {
        VStack {
            if cameraPermissionStatus == .authorized {
                Text("Camera Permission Granted")
            }else{
                Text("Camera Permissions Required")
                Button("Provide Camera Permissions", systemImage: "camera") {
                    requestPermissions()
                }
            }
            
        }.onAppear {
            cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}
