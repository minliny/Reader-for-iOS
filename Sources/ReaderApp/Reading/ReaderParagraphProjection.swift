import Foundation
import UIKit

/// Display-only adaptation of Host 33f7c7b2 ReadingParagraphProjection's local
/// TXT lineSeparated mode. Core's string and scalar coordinates stay canonical.
struct ReaderParagraphProjection {
    struct Paragraph {
        let text: String
        let sourceUTF16Range: NSRange
        let sourceScalarRange: Range<UInt64>
        let displayUTF16Range: NSRange
    }

    /// Several hidden separators can occupy one displayed boundary. Retain the
    /// original scalar until the user actually moves away from that boundary.
    struct Anchor {
        let sourceScalarOffset: UInt64
        let displayUTF16Offset: Int
    }

    let text: String
    let paragraphs: [Paragraph]
    let sourceScalarCount: UInt64
    private let displayUTF16Count: Int

    init(content: String) {
        // Foundation's whitespace set plus ECMAScript trim's BOM, minus NEL.
        // Trim is only an emptiness predicate; retained paragraphs are verbatim.
        let blankCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\u{FEFF}"))
            .subtracting(CharacterSet(charactersIn: "\u{0085}"))
        var output = ""
        var ranges: [Paragraph] = []
        var displayCursor = 0
        var sourceCursor = content.startIndex
        var scalarCursor: UInt64 = 0
        // Swift's CRLF Character is consumed as one separator, while both
        // original Unicode scalars remain represented by the source ranges.
        for line in content.split(omittingEmptySubsequences: false, whereSeparator: {
            $0 == "\n" || $0 == "\r" || $0 == "\r\n"
        }) {
            let scalarStart = scalarCursor + UInt64(content[sourceCursor..<line.startIndex].unicodeScalars.count)
            let scalarEnd = scalarStart + UInt64(line.unicodeScalars.count)
            sourceCursor = line.endIndex
            scalarCursor = scalarEnd
            let original = String(line)
            guard !original.trimmingCharacters(in: blankCharacters).isEmpty else { continue }
            if !ranges.isEmpty { output.append("\n"); displayCursor += 1 }
            let width = original.utf16.count
            ranges.append(Paragraph(text: original,
                sourceUTF16Range: NSRange(line.startIndex..<line.endIndex, in: content),
                sourceScalarRange: scalarStart..<scalarEnd,
                displayUTF16Range: NSRange(location: displayCursor, length: width)))
            output.append(original)
            displayCursor += width
        }
        text = output
        paragraphs = ranges
        sourceScalarCount = UInt64(content.unicodeScalars.count)
        displayUTF16Count = displayCursor
    }

    /// Hidden whitespace has forward affinity to the next visible paragraph;
    /// trailing whitespace uses the last visible endpoint.
    func displayUTF16Offset(forSourceScalar offset: UInt64) -> Int {
        let offset = min(offset, sourceScalarCount)
        for paragraph in paragraphs {
            if offset < paragraph.sourceScalarRange.lowerBound { return paragraph.displayUTF16Range.location }
            if offset <= paragraph.sourceScalarRange.upperBound {
                return paragraph.displayUTF16Range.location + ReaderTextCoordinates.utf16Offset(
                    in: paragraph.text, scalarOffset: offset - paragraph.sourceScalarRange.lowerBound)
            }
        }
        return displayUTF16Count
    }

    func sourceScalarOffset(forDisplayUTF16 offset: Int, preserving anchor: Anchor? = nil) -> UInt64 {
        let offset = min(max(0, offset), displayUTF16Count)
        if let anchor, anchor.displayUTF16Offset == offset {
            return min(anchor.sourceScalarOffset, sourceScalarCount)
        }
        for paragraph in paragraphs {
            if offset <= NSMaxRange(paragraph.displayUTF16Range) {
                return paragraph.sourceScalarRange.lowerBound + ReaderTextCoordinates.scalarOffset(
                    in: paragraph.text, utf16Offset: max(0, offset - paragraph.displayUTF16Range.location))
            }
        }
        return paragraphs.last?.sourceScalarRange.upperBound ?? 0
    }

    func anchor(forSourceScalar offset: UInt64) -> Anchor {
        let offset = min(offset, sourceScalarCount)
        return Anchor(sourceScalarOffset: offset, displayUTF16Offset: displayUTF16Offset(forSourceScalar: offset))
    }

    @MainActor
    func attributedBody(fontSize: CGFloat, lineHeight: CGFloat, ink: UIColor) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = fontSize * lineHeight
        style.maximumLineHeight = fontSize * lineHeight
        style.paragraphSpacing = ReaderTypography.defaultParagraphSpacing
        style.alignment = .justified
        // Frozen default indent is none. Original leading spaces remain text.
        style.firstLineHeadIndent = 0
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: ReaderTypography.readingFont(size: fontSize), .foregroundColor: ink,
            .paragraphStyle: style, .kern: ReaderTypography.defaultLetterSpacing
        ])
        if let last = paragraphs.last, let terminalStyle = style.mutableCopy() as? NSMutableParagraphStyle {
            terminalStyle.paragraphSpacing = 0
            result.addAttribute(.paragraphStyle, value: terminalStyle, range: last.displayUTF16Range)
        }
        return result
    }
}
