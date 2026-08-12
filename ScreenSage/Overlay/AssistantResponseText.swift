import LaTeXSwiftUI
import SwiftUI

struct AssistantResponseText: View {
    let text: String

    var body: some View {
        LaTeX(text)
            .parsingMode(.onlyEquations)
            .blockMode(.blockViews)
            .errorMode(.original)
            .processEscapes()
            .renderingStyle(.original)
    }
}
