import CoreGraphics
import Foundation

struct ScreenContext: Sendable {
    let imageData: Data
    let ocrText: String
}


struct CapturedScreenshot: Sendable {
    let imageData: Data
    let image: CGImage
}
