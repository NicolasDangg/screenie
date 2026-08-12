# LaTeX Response Rendering Design

## Goal

Render mathematical notation in screenie's AI responses without changing its prompt, screenshot, OCR, provider, history, or conversation behavior.

## Supported Input

The response renderer recognizes the common delimiters emitted by AI models:

- Inline math: `$...$` and `\(...\)`
- Display math: `$$...$$` and `\[...\]`

Escaped dollar signs remain ordinary text. Unclosed or invalid math remains visible as its original source instead of disappearing.

## Rendering

`OverlayAnswerView` delegates response content to a small segmented renderer. Plain segments keep the existing native `AttributedString` Markdown treatment. Math segments use the native macOS view supplied by SwiftMath, wrapped with `NSViewRepresentable`.

Inline equations use text mode and match the surrounding response font. Display equations use display mode, centered with modest vertical spacing. Equations constrain or wrap to the overlay width so they do not expand the floating panel horizontally.

The dependency is bundled into the signed app through Swift Package Manager. Nothing is fetched at runtime, and no WebView or JavaScript process is introduced.

## Streaming and History

The same renderer handles completed messages and the streaming response. A formula renders only after its closing delimiter arrives; until then, its source remains readable text. Conversation history continues to store only the original prompt and response strings, preserving the LaTeX source for later rendering.

## Failure Behavior

Unsupported or malformed LaTeX falls back to its source text. A rendering problem must not suppress the rest of the answer or interrupt the conversation.

## Verification

Automated tests cover all four delimiter forms, escaped dollar signs, mixed Markdown/math, and unmatched delimiters. The packaged Release app is then checked with a removable mock response containing inline and display equations.

## Out of Scope

- Editing LaTeX
- Equation export
- Math input assistance
- Web-based KaTeX or MathJax
- Changes to the AI request or persistence format
