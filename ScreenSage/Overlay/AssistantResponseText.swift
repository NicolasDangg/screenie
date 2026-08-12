import AppKit
import LaTeXSwiftUI
import SwiftUI

struct AssistantResponseText: View {
    let text: String

    var body: some View {
        LaTeX(text)
            .font(NSFont.systemFont(ofSize: 14))
            .script(.custom(1.3))
            .parsingMode(.onlyEquations)
            .blockMode(.blockViews)
            .errorMode(.original)
            .processEscapes()
            .renderingStyle(.original)
    }
}
