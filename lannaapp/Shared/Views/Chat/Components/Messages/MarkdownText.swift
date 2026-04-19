//
//  MarkdownText.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        Text(parseMarkdown(text))
            .textSelection(.enabled)
    }

    private func parseMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)

        // Bold text
        let boldPattern = #"\*\*(.*?)\*\*"#
        attributedString = replaceBold(in: attributedString, pattern: boldPattern)

        // Italic text
        let italicPattern = #"\*(.*?)\*"#
        attributedString = replaceItalic(in: attributedString, pattern: italicPattern)

        // Code blocks
        let codePattern = #"`(.*?)`"#
        attributedString = replaceCode(in: attributedString, pattern: codePattern)

        return attributedString
    }

    private func replaceBold(in text: AttributedString, pattern: String) -> AttributedString {
        var result = text
        let regex = try! NSRegularExpression(pattern: pattern)
        let string = String(text.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

        for match in matches.reversed() {
            if let range = Range(match.range, in: string),
               let captureRange = Range(match.range(at: 1), in: string) {
                let replacement = AttributedString(String(string[captureRange]))
                var boldReplacement = replacement
                boldReplacement.font = .boldSystemFont(ofSize: 16)

                let attributedRange = AttributedString.Index(range.lowerBound, within: result)!..<AttributedString.Index(range.upperBound, within: result)!
                result.replaceSubrange(attributedRange, with: boldReplacement)
            }
        }
        return result
    }

    private func replaceItalic(in text: AttributedString, pattern: String) -> AttributedString {
        var result = text
        let regex = try! NSRegularExpression(pattern: pattern)
        let string = String(text.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

        for match in matches.reversed() {
            if let range = Range(match.range, in: string),
               let captureRange = Range(match.range(at: 1), in: string) {
                let replacement = AttributedString(String(string[captureRange]))
                var italicReplacement = replacement
                italicReplacement.font = .italicSystemFont(ofSize: 16)

                let attributedRange = AttributedString.Index(range.lowerBound, within: result)!..<AttributedString.Index(range.upperBound, within: result)!
                result.replaceSubrange(attributedRange, with: italicReplacement)
            }
        }
        return result
    }

    private func replaceCode(in text: AttributedString, pattern: String) -> AttributedString {
        var result = text
        let regex = try! NSRegularExpression(pattern: pattern)
        let string = String(text.characters)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))

        for match in matches.reversed() {
            if let range = Range(match.range, in: string),
               let captureRange = Range(match.range(at: 1), in: string) {
                let replacement = AttributedString(String(string[captureRange]))
                var codeReplacement = replacement
                codeReplacement.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                codeReplacement.backgroundColor = .gray.opacity(0.2)

                let attributedRange = AttributedString.Index(range.lowerBound, within: result)!..<AttributedString.Index(range.upperBound, within: result)!
                result.replaceSubrange(attributedRange, with: codeReplacement)
            }
        }
        return result
    }
}