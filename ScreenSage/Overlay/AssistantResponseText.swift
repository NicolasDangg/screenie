import AppKit
import LaTeXSwiftUI
import SwiftUI

struct AssistantResponseText: View {
    let text: String

    var renderableText: String {
        text
            .replacingOccurrences(
                of: #"\boxed{"#,
                with: #"\enclose{box}{"#
            )
            .replacingOccurrences(
                of: #"\fbox{"#,
                with: #"\enclose{box}{"#
            )
    }

    var body: some View {
        LaTeX(renderableText)
            .font(NSFont.systemFont(ofSize: 17))
            .script(.custom(1.3))
            .parsingMode(.onlyEquations)
            .blockMode(.blockViews)
            .errorMode(.original)
            .processEscapes()
            .renderingStyle(.original)
    }
}
