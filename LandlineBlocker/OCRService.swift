import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct OCRResult: Sendable {
    let observationTexts: [String]
    let fullText: String
}

enum OCRServiceError: LocalizedError {
    case cannotLoadImageData
    case cannotCreateImage

    var errorDescription: String? {
        switch self {
        case .cannotLoadImageData:
            return "无法读取图片数据。"
        case .cannotCreateImage:
            return "无法解析图片。"
        }
    }
}

final class OCRService {
    func recognizeText(from item: PhotosPickerItem) async throws -> OCRResult {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw OCRServiceError.cannotLoadImageData
        }

        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw OCRServiceError.cannotCreateImage
        }

        return try await recognizeText(from: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
    }

    private func recognizeText(from cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let texts = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    let fullText = texts.joined(separator: "\n")
                    continuation.resume(returning: OCRResult(observationTexts: texts, fullText: fullText))
                }

                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["zh-Hans", "en-US"]
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
