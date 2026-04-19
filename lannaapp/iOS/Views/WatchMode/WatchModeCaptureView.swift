//
//  WatchModeCaptureView.swift
//  lannaapp
//
//  Created by Codex on 02/15/2026.
//

#if os(iOS)
import SwiftUI
import UIKit
import AVFoundation

struct WatchModeCaptureView: UIViewControllerRepresentable {
    let onComplete: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .video
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        picker.videoMaximumDuration = 120 // keep files manageable
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: WatchModeCaptureView

        init(parent: WatchModeCaptureView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.parent.onCancel()
            }
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true) {
                if let mediaURL = info[.mediaURL] as? URL {
                    self.parent.onComplete(mediaURL)
                } else {
                    self.parent.onCancel()
                }
            }
        }
    }
}
#endif
