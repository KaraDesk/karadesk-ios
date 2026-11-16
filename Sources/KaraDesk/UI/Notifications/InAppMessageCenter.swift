import SwiftUI
import UIKit

@MainActor
@Observable
final class InAppMessageModel {
    struct Item: Equatable, Identifiable {
        let id: String
        let conversationID: Int
        let author: Message.Author
        let preview: String
        let createdAt: Date
    }

    var item: Item?
    var cardFrame: CGRect = .zero
}

@MainActor
final class InAppMessageCenter {
    static let shared = InAppMessageCenter()

    private let model = InAppMessageModel()
    private var window: PassthroughWindow?
    private var hideTask: Task<Void, Never>?

    private static let visibleDuration: Duration = .seconds(8)

    func show(_ message: Message, onOpen: @escaping @MainActor (Int) -> Void) {
        show(id: message.id, conversationID: message.conversationId, author: message.author, body: message.previewText, createdAt: message.createdAt, onOpen: onOpen)
    }

    func show(id: String, conversationID: Int, author: Message.Author, body: String, createdAt: Date, onOpen: @escaping @MainActor (Int) -> Void) {
        guard let scene = Self.activeScene() else {
            return
        }

        let window = window(for: scene, onOpen: onOpen)
        window.isHidden = false

        let preview = String(Formatting.markdown(body).characters)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            model.item = InAppMessageModel.Item(
                id: id,
                conversationID: conversationID,
                author: author,
                preview: preview.isEmpty ? Strings.sentAnAttachment : preview,
                createdAt: createdAt
            )
        }

        UIAccessibility.post(
            notification: .announcement,
            argument: "\(author.name ?? Strings.team): \(preview)"
        )

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else {
                return
            }
            self?.dismiss()
        }
    }

    func dismiss() {
        hideTask?.cancel()

        guard model.item != nil else {
            return
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            model.item = nil
        }

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self, self.model.item == nil else {
                return
            }
            self.window?.isHidden = true
        }
    }

    private func window(for scene: UIWindowScene, onOpen: @escaping @MainActor (Int) -> Void) -> PassthroughWindow {
        if let window, window.windowScene === scene {
            return window
        }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        window.model = model

        let host = UIHostingController(rootView: InAppMessageOverlay(
            model: model,
            onOpen: { [weak self] id in
                self?.dismiss()
                onOpen(id)
            },
            onDismiss: { [weak self] in self?.dismiss() }
        ))
        host.view.backgroundColor = .clear
        window.rootViewController = host

        self.window = window
        return window
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

final class PassthroughWindow: UIWindow {
    weak var model: InAppMessageModel?

    override var canBecomeKey: Bool {
        false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let model, model.item != nil, model.cardFrame.contains(point) else {
            return nil
        }

        return super.hitTest(point, with: event)
    }
}

private struct InAppMessageOverlay: View {
    let model: InAppMessageModel
    let onOpen: (Int) -> Void
    let onDismiss: () -> Void

    @State private var drag: CGFloat = 0

    var body: some View {
        VStack {
            Spacer()

            if let item = model.item {
                InAppMessageCard(item: item, onDismiss: onDismiss)
                    .onTapGesture { onOpen(item.conversationID) }
                    .offset(y: max(0, drag))
                    .gesture(
                        DragGesture()
                            .onChanged { drag = $0.translation.height }
                            .onEnded { value in
                                if value.translation.height > 40 || value.predictedEndTranslation.height > 120 {
                                    onDismiss()
                                }
                                withAnimation(.spring) { drag = 0 }
                            }
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        model.cardFrame = frame
                    }
                    .id(item.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

private struct InAppMessageCard: View {
    let item: InAppMessageModel.Item
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.author.kind == .bot {
                BotAvatar(size: 40)
            } else {
                Avatar(name: item.author.name, url: item.author.avatarURL, size: 40)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(authorName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(Strings.now)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.preview)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.close)
        }
        .padding(14)
        .modifier(CardBackground())
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Strings.openConversation)
    }

    private var authorName: String {
        if let name = item.author.name, !name.isEmpty {
            return name
        }
        return item.author.kind == .bot ? "Kara" : Strings.team
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 18, y: 6)
        }
    }
}
