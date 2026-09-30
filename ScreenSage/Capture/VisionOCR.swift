import CoreGraphics
import Foundation
import Synchronization
import Vision

enum VisionOCR {
    static let timeout: TimeInterval = 5

    /// Returns recognized text, or an empty string when Vision fails or takes longer than `timeout`.
    /// OCR is supplementary to the screenshot, so it never fails or blocks the request.
    ///
    /// Uses the fast recognizer: on macOS 27.0 the accurate recognizer fails after the first request
    /// in a process (`CRImageReaderError`) or hangs indefinitely waiting on the Neural Engine compiler.
    static func recognize(in image: CGImage) async -> String {
        await withTimeout(timeout) {
            recognize { try perform(on: image) }
        }
    }

    static func recognize(using perform: () throws -> [VNRecognizedTextObservation]) -> String {
        (try? perform()).map(text(from:)) ?? ""
    }

    /// Runs blocking `work` on a background queue and gives up after `seconds`.
    /// Vision requests cannot be cancelled, so a stalled request is abandoned rather than awaited.
    static func withTimeout(
        _ seconds: TimeInterval,
        _ work: @escaping @Sendable () -> String
    ) async -> String {
        await withCheckedContinuation { continuation in
            let pending = PendingResult(continuation)
            DispatchQueue.global(qos: .userInitiated).async { pending.resume(work()) }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { pending.resume("") }
        }
    }

    private static func perform(on image: CGImage) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return request.results ?? []
    }

    private static func text(from observations: [VNRecognizedTextObservation]) -> String {
        observations.sorted { left, right in
            if abs(left.boundingBox.maxY - right.boundingBox.maxY) > 0.02 {
                return left.boundingBox.maxY > right.boundingBox.maxY
            }
            return left.boundingBox.minX < right.boundingBox.minX
        }
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
    }
}

/// Resumes a continuation exactly once, whichever of the work or the timeout finishes first.
private final class PendingResult: Sendable {
    private let continuation: Mutex<CheckedContinuation<String, Never>?>

    init(_ continuation: CheckedContinuation<String, Never>) {
        self.continuation = Mutex(continuation)
    }

    func resume(_ text: String) {
        continuation.withLock { $0.take() }?.resume(returning: text)
    }
}
