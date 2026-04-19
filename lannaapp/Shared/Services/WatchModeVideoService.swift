//
//  WatchModeVideoService.swift
//  lannaapp
//
//  Created by Codex on 02/15/2026.
//

import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum WatchModeVideoError: Error {
    case exportFailed
    case thumbnailGenerationFailed
}

struct WatchModeVideoService {
    static func compressVideo(at inputURL: URL, preset: String = AVAssetExportPresetMediumQuality) async throws -> URL {
        let asset = AVAsset(url: inputURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw WatchModeVideoError.exportFailed
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-mode-compressed-\(UUID().uuidString).mp4")
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed, .cancelled:
                    continuation.resume(throwing: exporter.error ?? WatchModeVideoError.exportFailed)
                default:
                    break
                }
            }
        }
    }

    static func generateThumbnail(for url: URL) throws -> URL {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.25, preferredTimescale: 600)
        let imageRef = try generator.copyCGImage(at: time, actualTime: nil)

        #if os(iOS)
        let image = UIImage(cgImage: imageRef)
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw WatchModeVideoError.thumbnailGenerationFailed
        }
        #else
        let bitmapRep = NSBitmapImageRep(cgImage: imageRef)
        guard let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            throw WatchModeVideoError.thumbnailGenerationFailed
        }
        #endif

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-mode-thumb-\(UUID().uuidString).jpg")
        try data.write(to: outputURL)
        return outputURL
    }

    static func duration(of url: URL) -> TimeInterval {
        let asset = AVAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}
