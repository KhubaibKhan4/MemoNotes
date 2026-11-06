//
//  RichText.swift
//  Notes
//

import SwiftUI

/// One stretch of note text that shares the same formatting.
///
/// SwiftUI fonts can't be saved directly, so formatting is stored as these runs
/// (encoded as JSON in `NotesItem.richText`). The plain text is always kept in
/// `NotesItem.desc` too, for search, previews, reminders and backups.
struct RichTextRun: Codable, Equatable {
    var text: String
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false
    var heading = false

    func hasSameStyle(as other: RichTextRun) -> Bool {
        bold == other.bold && italic == other.italic && underline == other.underline
            && strikethrough == other.strikethrough && heading == other.heading
    }

    var isPlain: Bool { !bold && !italic && !underline && !strikethrough && !heading }
}

enum RichTextCoder {

    /// Headings are this much larger than body text.
    static let headingScale: CGFloat = 1.35

    static func font(bold: Bool, italic: Bool, heading: Bool, baseSize: CGFloat) -> Font {
        var font = Font.system(size: heading ? baseSize * headingScale : baseSize, weight: heading ? .bold : .regular)
        if bold && !heading { font = font.bold() }
        if italic { font = font.italic() }
        return font
    }

    /// Builds the formatted text for display or editing. Falls back to the plain text
    /// when the note has no saved formatting.
    static func decode(_ data: Data?, fallback plainText: String, baseSize: CGFloat) -> AttributedString {
        guard let data, let runs = try? JSONDecoder().decode([RichTextRun].self, from: data) else {
            var plain = AttributedString(plainText)
            plain.font = .system(size: baseSize)
            return plain
        }
        var result = AttributedString()
        for run in runs {
            var piece = AttributedString(run.text)
            piece.font = font(bold: run.bold, italic: run.italic, heading: run.heading, baseSize: baseSize)
            if run.underline { piece.underlineStyle = .single }
            if run.strikethrough { piece.strikethroughStyle = .single }
            result.append(piece)
        }
        return result
    }

    /// Converts edited text into runs. Returns `nil` when nothing is formatted,
    /// so plain notes stay plain.
    static func encode(_ text: AttributedString, context: Font.Context, baseSize: CGFloat) -> Data? {
        let baseFont = Font.system(size: baseSize)
        var runs: [RichTextRun] = []
        for run in text.runs {
            let piece = String(text[run.range].characters)
            guard !piece.isEmpty else { continue }
            let resolved = (run.font ?? baseFont).resolve(in: context)
            let heading = resolved.pointSize > baseSize * 1.15
            let entry = RichTextRun(
                text: piece,
                bold: resolved.isBold && !heading,
                italic: resolved.isItalic,
                underline: run.underlineStyle != nil,
                strikethrough: run.strikethroughStyle != nil,
                heading: heading
            )
            if let last = runs.last, last.hasSameStyle(as: entry) {
                runs[runs.count - 1].text += piece
            } else {
                runs.append(entry)
            }
        }
        guard runs.contains(where: { !$0.isPlain }) else { return nil }
        return try? JSONEncoder().encode(runs)
    }

    /// Splits formatted text into lines, keeping each line's formatting.
    static func lines(of text: AttributedString) -> [AttributedString] {
        var result: [AttributedString] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            if text.characters[index] == "\n" {
                result.append(AttributedString(text[start..<index]))
                start = text.characters.index(after: index)
            }
            index = text.characters.index(after: index)
        }
        result.append(AttributedString(text[start..<text.endIndex]))
        return result
    }

    /// Trims leading/trailing whitespace while keeping formatting.
    static func trimmed(_ text: AttributedString) -> AttributedString {
        let characters = text.characters
        guard let first = characters.firstIndex(where: { !$0.isWhitespace }),
              let last = characters.lastIndex(where: { !$0.isWhitespace }) else {
            return AttributedString()
        }
        return AttributedString(text[first...last])
    }
}

/// A formatted text editor with a Bold / Italic / Underline / Strikethrough / Heading / Bullet toolbar.
struct RichTextEditor: View {
    @Binding var text: AttributedString
    var baseSize: CGFloat
    var placeholder: LocalizedStringKey = "Description"

    @State private var selection = AttributedTextSelection()
    @FocusState private var isFocused: Bool
    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.characters.isEmpty {
                Text(placeholder)
                    .font(.system(size: baseSize))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text, selection: $selection)
                .font(.system(size: baseSize))
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
        }
        // Format buttons sit above the keyboard, where the system edit menu can't cover them.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFocused {
                    toolbar
                }
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            formatButton("bold", label: "Bold", isOn: allSelected { $0.isBold && !isHeading($0) }) { toggleBold() }
            formatButton("italic", label: "Italic", isOn: allSelected { $0.isItalic }) { toggleItalic() }
            formatButton("underline", label: "Underline", isOn: allUnderlined) { toggleUnderline() }
            formatButton("strikethrough", label: "Strikethrough", isOn: allStruckThrough) { toggleStrikethrough() }
            Divider().frame(height: 20)
            formatButton("textformat.size.larger", label: "Heading", isOn: allSelected { isHeading($0) }) { toggleHeading() }
            formatButton("list.bullet", label: "Bulleted line", isOn: false) { insertBullet() }
            Spacer()
        }
        .buttonStyle(.borderless)
    }

    private func formatButton(_ symbol: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: symbol)
                .frame(width: 34, height: 30)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.12))
                )
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: State of the selection

    private var baseFont: Font { .system(size: baseSize) }

    private func isHeading(_ resolved: Font.Resolved) -> Bool {
        resolved.pointSize > baseSize * 1.15
    }

    /// Fonts across the selection, or the typing attributes at the cursor.
    private var selectedFonts: [Font.Resolved] {
        let fonts = Array(selection.attributes(in: text)[\.font])
        let list = fonts.isEmpty ? [selection.typingAttributes(in: text).font] : fonts
        return list.map { ($0 ?? baseFont).resolve(in: fontContext) }
    }

    private func allSelected(_ check: (Font.Resolved) -> Bool) -> Bool {
        let fonts = selectedFonts
        return !fonts.isEmpty && fonts.allSatisfy(check)
    }

    private var allUnderlined: Bool {
        let styles = Array(selection.attributes(in: text)[\.underlineStyle])
        let list = styles.isEmpty ? [selection.typingAttributes(in: text).underlineStyle] : styles
        return !list.isEmpty && list.allSatisfy { $0 != nil }
    }

    private var allStruckThrough: Bool {
        let styles = Array(selection.attributes(in: text)[\.strikethroughStyle])
        let list = styles.isEmpty ? [selection.typingAttributes(in: text).strikethroughStyle] : styles
        return !list.isEmpty && list.allSatisfy { $0 != nil }
    }

    // MARK: Actions

    /// Rebuilds each run's font from its current style, with `change` applied.
    private func restyle(_ change: (inout (bold: Bool, italic: Bool, heading: Bool)) -> Void) {
        text.transformAttributes(in: &selection) { container in
            let resolved = (container.font ?? baseFont).resolve(in: fontContext)
            let heading = isHeading(resolved)
            var style = (bold: resolved.isBold && !heading, italic: resolved.isItalic, heading: heading)
            change(&style)
            container.font = RichTextCoder.font(bold: style.bold, italic: style.italic, heading: style.heading, baseSize: baseSize)
        }
    }

    private func toggleBold() {
        let makeBold = !allSelected { $0.isBold && !isHeading($0) }
        restyle { $0.bold = makeBold; if makeBold { $0.heading = false } }
    }

    private func toggleItalic() {
        let makeItalic = !allSelected { $0.isItalic }
        restyle { $0.italic = makeItalic }
    }

    private func toggleHeading() {
        let makeHeading = !allSelected { isHeading($0) }
        restyle { $0.heading = makeHeading; $0.bold = false }
    }

    private func toggleUnderline() {
        let underline = !allUnderlined
        text.transformAttributes(in: &selection) { $0.underlineStyle = underline ? .single : nil }
    }

    private func toggleStrikethrough() {
        let strike = !allStruckThrough
        text.transformAttributes(in: &selection) { $0.strikethroughStyle = strike ? .single : nil }
    }

    /// Puts "• " at the start of the line the cursor (or selection) begins on.
    private func insertBullet() {
        let cursor: AttributedString.Index
        switch selection.indices(in: text) {
        case .insertionPoint(let index):
            cursor = index
        case .ranges(let ranges):
            cursor = ranges.ranges.first?.lowerBound ?? text.endIndex
        }
        let characters = text.characters
        var lineStart = cursor
        while lineStart > characters.startIndex {
            let previous = characters.index(before: lineStart)
            if characters[previous] == "\n" { break }
            lineStart = previous
        }
        if characters[lineStart...].starts(with: "• ") { return }

        var bullet = AttributedString("• ")
        bullet.font = baseFont
        text.transform(updating: &selection) { text in
            text.insert(bullet, at: lineStart)
        }
    }
}
