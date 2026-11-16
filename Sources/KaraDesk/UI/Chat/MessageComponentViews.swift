import SwiftUI

struct ComponentHandlers {
    var interact: @MainActor (Message, ComponentInteraction) async -> String?
    var openLink: @MainActor (Message, ComponentInteraction, URL) -> Void
    var openArticle: @MainActor (MessageComponent.Article) -> Void
}

struct MessageComponentsView: View {
    let message: Message
    let handlers: ComponentHandlers

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(message.components.filter(\.isRenderable)) { component in
                MessageComponentView(message: message, component: component, handlers: handlers)
            }
        }
    }
}

private enum ComponentMetrics {
    static let width: CGFloat = 272
    static let radius: CGFloat = 16
    static let control: CGFloat = 36
}

private struct MessageComponentView: View {
    let message: Message
    let component: MessageComponent
    let handlers: ComponentHandlers

    var body: some View {
        switch component.content {
        case let .buttons(buttons):
            VStack(alignment: .leading, spacing: 6) {
                if let prompt = buttons.prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                ComponentButtonList(
                    message: message,
                    componentID: component.id,
                    buttons: buttons.buttons,
                    layout: buttons.layout,
                    answeredID: component.answer?.buttonID,
                    answered: component.isAnswered,
                    handlers: handlers
                )
            }
            .frame(width: ComponentMetrics.width, alignment: .leading)
        case let .articles(articles):
            ArticlesComponentView(articles: articles, onOpen: handlers.openArticle)
        case let .input(input):
            InputComponentView(message: message, component: component, input: input, handlers: handlers)
        case let .card(card):
            CardComponentView(message: message, component: component, card: card, handlers: handlers)
        case .unknown:
            if let text = component.fallbackText {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(uiColor: .secondarySystemBackground), in: BubbleShape(mine: false, tail: false))
            }
        }
    }
}

private struct ComponentCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: ComponentMetrics.width, alignment: .leading)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: ComponentMetrics.radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: ComponentMetrics.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ComponentMetrics.radius, style: .continuous).strokeBorder(.separator))
    }
}

private extension View {
    func componentCard() -> some View {
        modifier(ComponentCard())
    }
}

private struct ComponentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct ComponentError: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .transition(.opacity)
        }
    }
}

private struct ComponentButtonList: View {
    let message: Message
    let componentID: String
    let buttons: [MessageComponent.Button]
    let layout: MessageComponent.Buttons.Layout
    let answeredID: String?
    let answered: Bool
    let handlers: ComponentHandlers

    @State private var pending: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch layout {
            case .row:
                FlowLayout(spacing: 6) {
                    ForEach(buttons) { button in
                        buttonView(button)
                    }
                }
            case .stack:
                VStack(spacing: 6) {
                    ForEach(buttons) { button in
                        buttonView(button)
                    }
                }
            }

            ComponentError(text: error)
        }
        .animation(.snappy, value: answeredID)
        .animation(.snappy, value: error)
    }

    private func buttonView(_ button: MessageComponent.Button) -> some View {
        let link = button.opensURL

        return ComponentPillButton(
            button: button,
            fullWidth: layout == .stack,
            chosen: answeredID == button.id,
            answered: answered,
            pending: pending == button.id,
            isLink: link != nil
        ) {
            tap(button, link: link)
        }
        .disabled(link == nil && (answered || pending != nil))
    }

    private func tap(_ button: MessageComponent.Button, link: URL?) {
        let interaction = ComponentInteraction.button(button.id, in: componentID)

        if let link {
            handlers.openLink(message, interaction, link)
            return
        }

        pending = button.id
        error = nil

        Task {
            error = await handlers.interact(message, interaction)
            pending = nil
        }
    }
}

private struct ComponentPillButton: View {
    let button: MessageComponent.Button
    let fullWidth: Bool
    let chosen: Bool
    let answered: Bool
    let pending: Bool
    let isLink: Bool
    let action: () -> Void

    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if pending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(filled ? theme.onAccent : .secondary)
                } else if chosen {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }

                Text(button.label)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if isLink {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: ComponentMetrics.control)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .foregroundStyle(filled ? theme.onAccent : Color.primary)
            .background(background, in: Capsule())
            .overlay {
                if !filled {
                    Capsule().strokeBorder(Color.primary.opacity(0.15))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(ComponentButtonStyle())
        .opacity(answered && !chosen && !isLink ? 0.4 : 1)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private var filled: Bool {
        chosen || (button.style == .primary && !answered)
    }

    private var background: AnyShapeStyle {
        filled ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color(uiColor: .systemBackground))
    }
}

private struct ArticlesComponentView: View {
    let articles: [MessageComponent.Article]
    let onOpen: @MainActor (MessageComponent.Article) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                if index > 0 {
                    Divider()
                        .padding(.leading, 40)
                }

                Button {
                    onOpen(article)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(article.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)

                            if let description = article.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
        .componentCard()
    }
}

private struct InputComponentView: View {
    let message: Message
    let component: MessageComponent
    let input: MessageComponent.Input
    let handlers: ComponentHandlers

    @State private var text = ""
    @State private var pending = false
    @State private var error: String?
    @FocusState private var focused: Bool
    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        Group {
            if let answer = component.answer {
                answered(answer)
            } else {
                form
            }
        }
        .animation(.snappy, value: component.answer)
        .animation(.snappy, value: error)
    }

    private func answered(_ answer: MessageComponent.Answer) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(input.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(input.label(for: answer) ?? "")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .componentCard()
        .accessibilityElement(children: .combine)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !input.label.isEmpty {
                Text(input.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                field
                sendButton
            }

            ComponentError(text: error)
        }
        .padding(12)
        .componentCard()
    }

    @ViewBuilder
    private var field: some View {
        if input.kind == .select {
            Menu {
                Picker(input.label, selection: $text) {
                    ForEach(input.options) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLabel ?? input.placeholder ?? Strings.chooseOne)
                        .foregroundStyle(selectedLabel == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .frame(height: ComponentMetrics.control)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
            .disabled(pending)
            .accessibilityLabel(input.label)
        } else {
            TextField(input.placeholder ?? "", text: $text)
                .font(.subheadline)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(input.kind == .text ? .sentences : .never)
                .autocorrectionDisabled(input.kind != .text)
                .submitLabel(.send)
                .focused($focused)
                .onSubmit(submit)
                .padding(.horizontal, 12)
                .frame(height: ComponentMetrics.control)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(pending)
                .accessibilityLabel(input.label)
        }
    }

    private var sendButton: some View {
        Button(action: submit) {
            ZStack {
                if pending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.onAccent)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(width: ComponentMetrics.control, height: ComponentMetrics.control)
            .foregroundStyle(theme.onAccent)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(ComponentButtonStyle())
        .opacity(canSubmit || pending ? 1 : 0.4)
        .disabled(!canSubmit)
        .accessibilityLabel(Strings.send)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !pending && !trimmed.isEmpty
    }

    private var selectedLabel: String? {
        input.options.first { $0.value == text }?.label
    }

    private var keyboard: UIKeyboardType {
        switch input.kind {
        case .email:
            return .emailAddress
        case .phone:
            return .phonePad
        case .number:
            return .decimalPad
        case .text, .select:
            return .default
        }
    }

    private var contentType: UITextContentType? {
        switch input.kind {
        case .email:
            return .emailAddress
        case .phone:
            return .telephoneNumber
        case .text, .number, .select:
            return nil
        }
    }

    private var value: JSONValue {
        if input.kind == .number, let number = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
            return .number(number)
        }

        return .string(trimmed)
    }

    private func submit() {
        guard canSubmit else {
            return
        }

        let interaction = ComponentInteraction.value(value, in: component.id)
        pending = true
        error = nil

        Task {
            let failure = await handlers.interact(message, interaction)
            error = failure
            pending = false

            if failure == nil {
                focused = false
            }
        }
    }
}

private struct CardComponentView: View {
    let message: Message
    let component: MessageComponent
    let card: MessageComponent.Card
    let handlers: ComponentHandlers

    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = card.imageURL {
                Color(uiColor: .secondarySystemBackground)
                    .aspectRatio(2, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: imageURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            }
                        }
                    }
                    .clipped()
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !card.title.isEmpty {
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }

                if let body = card.body, !body.isEmpty {
                    Text(Formatting.markdown(body))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .tint(theme.tint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !card.buttons.isEmpty {
                    ComponentButtonList(
                        message: message,
                        componentID: component.id,
                        buttons: card.buttons,
                        layout: .stack,
                        answeredID: component.answer?.buttonID,
                        answered: component.isAnswered,
                        handlers: handlers
                    )
                    .padding(.top, 2)
                }
            }
            .padding(12)
        }
        .componentCard()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)

        for (index, frame) in arrangement.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))

            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }

        return (frames, CGSize(width: widest, height: y + rowHeight))
    }
}
