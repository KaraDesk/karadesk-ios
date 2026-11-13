import SwiftUI

struct RichText: View {
    let node: RichNode
    let baseURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(node.content.enumerated()), id: \.offset) { _, child in
                RichBlock(node: child, baseURL: baseURL)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RichBlock: View {
    let node: RichNode
    let baseURL: URL?

    var body: some View {
        switch node.type {
        case "paragraph":
            if !node.content.isEmpty {
                Text(RichInline.text(node.content, baseURL: baseURL))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case "heading":
            Text(RichInline.text(node.content, baseURL: baseURL))
                .font(level <= 1 ? .title3.weight(.bold) : .headline)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
        case "bulletList", "orderedList":
            list
        case "blockquote":
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.separator)
                    .frame(width: 3)
                RichText(node: node, baseURL: baseURL)
                    .foregroundStyle(.secondary)
            }
        case "codeBlock":
            ScrollView(.horizontal, showsIndicators: false) {
                Text(RichInline.plain(node))
                    .font(.system(.footnote, design: .monospaced))
                    .padding(12)
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case "horizontalRule":
            Divider().padding(.vertical, 6)
        case "image":
            RichImage(node: node, baseURL: baseURL)
        case "table":
            RichTable(node: node, baseURL: baseURL)
        default:
            if !node.content.isEmpty {
                RichText(node: node, baseURL: baseURL)
            }
        }
    }

    private var level: Int {
        Int(node.attrs["level"]?.numberValue ?? 1)
    }

    private var list: some View {
        let ordered = node.type == "orderedList"
        let start = Int(node.attrs["start"]?.numberValue ?? 1)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(node.content.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ordered ? "\(start + index)." : "•")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                    RichText(node: item, baseURL: baseURL)
                }
            }
        }
        .padding(.leading, 4)
    }
}

private struct RichImage: View {
    let node: RichNode
    let baseURL: URL?

    var body: some View {
        if let url = RichInline.resolve(node.attrs["src"]?.stringValue, baseURL: baseURL) {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color(uiColor: .secondarySystemBackground)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                }
            }
            .frame(maxWidth: width)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: .infinity, alignment: alignment)
            .accessibilityLabel(node.attrs["alt"]?.stringValue ?? "")
        }
    }

    private var width: CGFloat? {
        node.attrs["width"]?.numberValue.map { CGFloat($0) }
    }

    private var aspectRatio: CGFloat {
        guard let width = node.attrs["width"]?.numberValue, let height = node.attrs["height"]?.numberValue, height > 0 else {
            return 16 / 9
        }

        return width / height
    }

    private var alignment: Alignment {
        switch node.attrs["align"]?.stringValue {
        case "left": .leading
        case "right": .trailing
        default: .center
        }
    }
}

private struct RichTable: View {
    let node: RichNode
    let baseURL: URL?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(node.content.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.content.enumerated()), id: \.offset) { _, cell in
                            RichText(node: cell, baseURL: baseURL)
                                .font(cell.type == "tableHeader" ? .subheadline.weight(.semibold) : .subheadline)
                                .padding(8)
                                .frame(minWidth: 100, alignment: .leading)
                                .border(.separator, width: 0.5)
                        }
                    }
                }
            }
        }
    }
}

enum RichInline {
    static func text(_ nodes: [RichNode], baseURL: URL?) -> AttributedString {
        nodes.reduce(into: AttributedString()) { result, node in
            switch node.type {
            case "text":
                result += styled(node, baseURL: baseURL)
            case "hardBreak":
                result += AttributedString("\n")
            default:
                result += text(node.content, baseURL: baseURL)
            }
        }
    }

    static func plain(_ node: RichNode) -> String {
        node.text ?? node.content.map(plain).joined()
    }

    static func resolve(_ value: String?, baseURL: URL?) -> URL? {
        guard let value, !value.isEmpty else {
            return nil
        }

        if value.hasPrefix("/"), let baseURL {
            return URL(string: value, relativeTo: baseURL)?.absoluteURL
        }

        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["http", "https", "mailto", "tel"].contains(scheme) else {
            return nil
        }

        return url
    }

    private static func styled(_ node: RichNode, baseURL: URL?) -> AttributedString {
        var text = AttributedString(node.text ?? "")
        var intent = InlinePresentationIntent()

        for mark in node.marks {
            switch mark.type {
            case "bold":
                intent.insert(.stronglyEmphasized)
            case "italic":
                intent.insert(.emphasized)
            case "code":
                intent.insert(.code)
            case "strike":
                text.strikethroughStyle = .single
            case "underline":
                text.underlineStyle = .single
            case "link":
                text.link = resolve(mark.attrs["href"]?.stringValue, baseURL: baseURL)
            default:
                break
            }
        }

        if !intent.isEmpty {
            text.inlinePresentationIntent = intent
        }

        return text
    }
}
