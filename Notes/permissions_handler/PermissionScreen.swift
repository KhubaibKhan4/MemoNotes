//
//  PermissionScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 01/01/2025.
//

import SwiftUI
import AVFoundation

struct PermissionScreen: View {
    
    @State var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State var cameraPermissionText: String =  "Allow Camera"
    @State var photosPermissionText: String = "Allow Photos"
    @State var locationPermissionText: String = "Allow Location"
    
    @AppStorage("isPermissionGranted") private var isPermissionGranted = false
    @State var isCroppingEnabled: Bool = false
    
    @State var capturedImage: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .center, spacing: CGFloat(6)) {
            Image("notes")
                .resizable()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text("Please allow Notes to access your Camera, Photos, and Location.")
                .padding(.all)
                .frame(alignment: .center)
            
            
        
            Button {
                requestCameraPermission()
                if cameraPermission == .authorized {
                    //isPermissionGranted = true
                    
                    ImagePicker(sourceType: .camera, completion: { image in
                        capturedImage = image
                    }, isCropping: $isCroppingEnabled)
                    
                } else {
                    cameraPermissionText = "Allow Camera"
                }
            } label: {
                Label("\(cameraPermissionText)", systemImage: "camera")
            }

            Button {
                
            } label: {
                Label("Allow Photos", systemImage: "photo")
            }
            
            Button {
                
            } label: {
                Label("Allow Location", systemImage: "location")
            }
        }
        .onAppear {
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { isGranted in
            DispatchQueue.main.async {
                cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
    
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var completion: (UIImage) -> Void
    @Binding var isCropping: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
                parent.isCropping = true
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}


