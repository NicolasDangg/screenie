import AppKit
import SwiftUI

/// A run of assistant output: either prose or a fenced code block.
enum ResponseSegment: Equatable {
    case prose(String)
    case code(language: String, code: String)

    /// Splits Markdown into prose and fenced code blocks. An unclosed fence,
    /// common while a response is still streaming, runs to the end of the text.
    static func split(_ text: String) -> [ResponseSegment] {
        var segments: [ResponseSegment] = []
        var prose: [Substring] = []
        var code: [Substring] = []
        var fence: (character: Character, indent: Int, language: String)?

        func flushProse() {
            let joined = prose.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.prose(joined))
            }
            prose = []
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if let open = fence {
                let marker = String(repeating: open.character, count: 3)
                if trimmed.hasPrefix(marker), trimmed.drop(while: { $0 == open.character }).allSatisfy(\.isWhitespace) {
                    segments.append(.code(language: open.language, code: code.joined(separator: "\n")))
                    code = []
                    fence = nil
                } else {
                    code.append(removingIndent(open.indent, from: line))
                }
            } else if let character = fenceCharacter(of: trimmed) {
                flushProse()
                let info = trimmed.drop { $0 == character }.trimmingCharacters(in: .whitespaces)
                let language = info.split(separator: " ").first.map(String.init) ?? ""
                fence = (character, line.count - trimmed.count, language)
            } else {
                prose.append(line)
            }
        }

        if let open = fence {
            segments.append(.code(language: open.language, code: code.joined(separator: "\n")))
        }
        flushProse()
        return segments
    }

    private static func fenceCharacter(of line: Substring) -> Character? {
        if line.hasPrefix("```") { return "`" }
        if line.hasPrefix("~~~") { return "~" }
        return nil
    }

    private static func removingIndent(_ indent: Int, from line: Substring) -> Substring {
        var result = line
        var removed = 0
        while removed < indent, let first = result.first, first == " " || first == "\t" {
            result = result.dropFirst()
            removed += 1
        }
        return result
    }
}

struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language.lowercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: copy) {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))

            ScrollView(.horizontal) {
                Text(SyntaxHighlighter.highlight(code, language: language))
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(3)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(12)
            }
            .scrollIndicators(.never)
        }
        .background(Color.black.opacity(0.22), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}

/// A small, language-agnostic highlighter for comments, strings, numbers, and keywords.
enum SyntaxHighlighter {
    private static let hashCommentLanguages: Set<String> = [
        "python", "py", "ruby", "rb", "sh", "bash", "zsh", "shell", "yaml", "yml", "toml", "r", "perl", "pl", "makefile", "dockerfile"
    ]

    private static let keywords: Set<String> = [
        "and", "as", "async", "await", "break", "case", "catch", "class", "const", "continue", "def", "default", "defer",
        "del", "do", "elif", "else", "enum", "except", "export", "extends", "extension", "false", "False", "final",
        "finally", "fn", "for", "from", "func", "function", "global", "guard", "if", "impl", "import", "in", "interface",
        "is", "lambda", "let", "match", "mut", "new", "nil", "None", "nonlocal", "not", "null", "or", "package", "pass",
        "private", "protocol", "pub", "public", "raise", "return", "self", "Self", "static", "struct", "super", "switch",
        "this", "throw", "throws", "true", "True", "try", "typeof", "undefined", "use", "var", "void", "where", "while",
        "with", "yield"
    ]

    private static let keywordPattern = #"\b(?:"# + keywords.sorted().joined(separator: "|") + #")\b"#

    static func highlight(_ code: String, language: String) -> AttributedString {
        let full = NSRange(code.startIndex..., in: code)
        var colored: [(NSRange, Color)] = []
        var claimed = IndexSet()

        // Earlier patterns win, so comments and strings shield their contents.
        func apply(_ pattern: String, _ color: Color) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            for match in regex.matches(in: code, range: full) {
                let span = match.range.location..<NSMaxRange(match.range)
                guard !span.isEmpty, !claimed.intersects(integersIn: span) else { continue }
                claimed.insert(integersIn: span)
                colored.append((match.range, color))
            }
        }

        let string = Color(nsColor: .systemOrange)
        let comment = Color.secondary
        let lang = language.lowercased()

        apply(#"\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''"#, string)
        if hashCommentLanguages.contains(lang) {
            apply(#"#[^\n]*"#, comment)
        } else if lang == "sql" {
            apply(#"--[^\n]*"#, comment)
        } else {
            apply(#"//[^\n]*|/\*[\s\S]*?\*/"#, comment)
        }
        apply(#""(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`"#, string)
        apply(#"\b(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?)\b"#, Color(nsColor: .systemPurple))
        apply(keywordPattern, Color(nsColor: .systemPink))

        var result = AttributedString(code)
        for (range, color) in colored {
            guard let stringRange = Range(range, in: code),
                  let attributedRange = Range(stringRange, in: result) else { continue }
            result[attributedRange].foregroundColor = color
        }
        return result
    }
}
