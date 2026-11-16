import SwiftUI

extension KaraDeskError {
    var title: String {
        switch self {
        case .unavailable, .identityVerificationFailed:
            return Strings.messengerUnavailable
        case _ where isOffline:
            return Strings.offlineTitle
        default:
            return Strings.loadFailedTitle
        }
    }

    var userMessage: String {
        switch self {
        case .unavailable, .identityVerificationFailed:
            return Strings.unavailableDetail
        default:
            return localizedDescription
        }
    }

    var detail: String {
        isOffline ? Strings.offlineDetail : userMessage
    }

    var symbol: String {
        switch self {
        case .unavailable, .identityVerificationFailed:
            return "bubble.left.and.exclamationmark.bubble.right"
        case _ where isOffline:
            return "wifi.slash"
        default:
            return "exclamationmark.triangle"
        }
    }
}

struct ErrorStateView: View {
    let error: KaraDeskError
    var title: String?
    var retry: (() async -> Void)?

    @State private var retrying = false

    var body: some View {
        ContentUnavailableView {
            Label(title ?? error.title, systemImage: error.symbol)
        } description: {
            Text(error.detail)
        } actions: {
            if error.isRetryable, let retry {
                Button {
                    Task {
                        retrying = true
                        await retry()
                        retrying = false
                    }
                } label: {
                    if retrying {
                        ProgressView()
                            .padding(.horizontal, 24)
                    } else {
                        Text(Strings.retry)
                            .padding(.horizontal, 6)
                    }
                }
                .prominentButton()
                .disabled(retrying)
            }
        }
    }
}

struct InlineErrorRow: View {
    let error: KaraDeskError
    let retry: () async -> Void

    @State private var retrying = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: error.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(error.userMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if error.isRetryable {
                    Button {
                        Task {
                            retrying = true
                            await retry()
                            retrying = false
                        }
                    } label: {
                        Text(Strings.retry)
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(retrying)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct OfflineBanner: View {
    var body: some View {
        Label(Strings.offlineBanner, systemImage: "wifi.slash")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray), ignoresSafeAreaEdges: .top)
            .accessibilityAddTraits(.isStaticText)
    }
}
