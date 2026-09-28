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
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(ResponseSegment.split(renderableText).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let prose):
                    LaTeX(prose)
                        .font(NSFont.systemFont(ofSize: 17))
                        .script(.custom(1.3))
                        .parsingMode(.onlyEquations)
                        .blockMode(.blockViews)
                        .errorMode(.original)
                        .processEscapes()
                        .renderingStyle(.original)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }
}

/// Lightweight rendering for in-flight responses: plain prose, but code blocks
/// appear as soon as their fence opens.
struct StreamingResponseText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(ResponseSegment.split(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let prose):
                    Text(Self.inlineMarkdown(prose))
                        .font(.system(size: 17))
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }

    private static func inlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
