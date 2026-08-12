import CoreGraphics
import Vision

enum VisionOCR {
    static func recognize(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = (request.results ?? []).sorted { left, right in
            if abs(left.boundingBox.maxY - right.boundingBox.maxY) > 0.02 {
                return left.boundingBox.maxY > right.boundingBox.maxY
            }
            return left.boundingBox.minX < right.boundingBox.minX
        }
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

