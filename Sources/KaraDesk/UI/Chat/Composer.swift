import PhotosUI
import SwiftUI

struct Composer: View {
    @Bindable var model: ChatModel

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showsPhotos = false
    @State private var showsFiles = false
    @FocusState private var focused: Bool
    @Environment(\.karaDeskTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notice = model.notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }

            if !model.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.attachments) { attachment in
                            PendingAttachmentView(attachment: attachment) {
                                model.remove(attachment)
                            }
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                if model.attachmentRules.enabled {
                    attachMenu
                }

                TextField(Strings.messagePlaceholder, text: $model.draft, axis: .vertical)
                    .lineLimit(1 ... 6)
                    .focused($focused)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .onChange(of: model.draft) {
                        model.draftChanged()
                    }

                Button {
                    Task {
                        if let id = await model.send() {
                            _ = id
                        }
                    }
                } label: {
                    Group {
                        if model.isSending {
                            ProgressView().tint(theme.onAccent)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent, in: Circle())
                    .opacity(model.canSend ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!model.canSend)
                .accessibilityLabel(Strings.send)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassBar()
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .photosPicker(isPresented: $showsPhotos, selection: $photoItems, maxSelectionCount: ChatModel.maximumAttachments, matching: .images)
        .onChange(of: photoItems) {
            let items = photoItems
            photoItems = []

            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        model.addImage(data, contentType: item.supportedContentTypes.first)
                    }
                }
            }
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                urls.forEach(model.addFile)
            }
        }
    }

    private var attachMenu: some View {
        Menu {
            Button {
                showsPhotos = true
            } label: {
                Label(Strings.photos, systemImage: "photo.on.rectangle")
            }

            Button {
                showsFiles = true
            } label: {
                Label(Strings.files, systemImage: "folder")
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .tint(.secondary)
        .accessibilityLabel(Strings.attach)
    }
}

private struct PendingAttachmentView: View {
    let attachment: ChatModel.PendingAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let preview = attachment.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Group {
                    switch attachment.status {
                    case .uploading:
                        Text(Strings.uploading)
                    case .failed:
                        Text(Strings.uploadFailed).foregroundStyle(.red)
                    case .ready:
                        Text(Formatting.byteCount(attachment.byteSize))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 120, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.remove)
        }
        .padding(6)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
