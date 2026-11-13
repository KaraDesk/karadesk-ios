import Foundation

enum Strings {
    static let home = String(localized: "nav.home", defaultValue: "Home", bundle: .module)
    static let messages = String(localized: "nav.messages", defaultValue: "Messages", bundle: .module)
    static let help = String(localized: "nav.help", defaultValue: "Help", bundle: .module)
    static let close = String(localized: "action.close", defaultValue: "Close", bundle: .module)
    static let back = String(localized: "action.back", defaultValue: "Back", bundle: .module)
    static let retry = String(localized: "action.retry", defaultValue: "Try again", bundle: .module)
    static let send = String(localized: "action.send", defaultValue: "Send", bundle: .module)
    static let attach = String(localized: "action.attach", defaultValue: "Attach", bundle: .module)
    static let photos = String(localized: "action.photos", defaultValue: "Photo Library", bundle: .module)
    static let files = String(localized: "action.files", defaultValue: "Files", bundle: .module)
    static let remove = String(localized: "action.remove", defaultValue: "Remove", bundle: .module)
    static let sendUsAMessage = String(localized: "home.send_message", defaultValue: "Send us a message", bundle: .module)
    static let recentMessage = String(localized: "home.recent_message", defaultValue: "Recent message", bundle: .module)
    static let searchForHelp = String(localized: "help.search", defaultValue: "Search for help", bundle: .module)
    static let noResults = String(localized: "help.no_results", defaultValue: "No articles match your search.", bundle: .module)
    static let noArticles = String(localized: "help.empty", defaultValue: "There are no articles yet.", bundle: .module)
    static let noConversations = String(localized: "messages.empty.title", defaultValue: "No messages", bundle: .module)
    static let noConversationsDetail = String(localized: "messages.empty.detail", defaultValue: "Messages from the team will show up here.", bundle: .module)
    static let messagePlaceholder = String(localized: "composer.placeholder", defaultValue: "Message…", bundle: .module)
    static let askUsAnything = String(localized: "chat.empty.title", defaultValue: "Ask us anything", bundle: .module)
    static let wellReply = String(localized: "chat.empty.detail", defaultValue: "We'll reply here. You can close this and come back anytime.", bundle: .module)
    static let conversationEnded = String(localized: "chat.ended", defaultValue: "This conversation has ended.", bundle: .module)
    static let continuesElsewhere = String(localized: "chat.merged", defaultValue: "This conversation continues in another one.", bundle: .module)
    static let continueConversation = String(localized: "chat.merged.action", defaultValue: "Continue conversation", bundle: .module)
    static let startNewConversation = String(localized: "chat.new", defaultValue: "Start a new conversation", bundle: .module)
    static let activeNow = String(localized: "presence.active", defaultValue: "Active now", bundle: .module)
    static let replySoon = String(localized: "presence.soon", defaultValue: "Will reply as soon as possible", bundle: .module)
    static let poweredBy = String(localized: "branding.powered_by", defaultValue: "Powered by KaraDesk", bundle: .module)
    static let team = String(localized: "author.team", defaultValue: "Team", bundle: .module)
    static let you = String(localized: "author.you", defaultValue: "You", bundle: .module)
    static let aiAgent = String(localized: "author.ai_agent", defaultValue: "AI Agent", bundle: .module)
    static let uploading = String(localized: "attachment.uploading", defaultValue: "Uploading…", bundle: .module)
    static let uploadFailed = String(localized: "attachment.failed", defaultValue: "Upload failed", bundle: .module)
    static let fileTooLarge = String(localized: "attachment.too_large", defaultValue: "That file is too large to send.", bundle: .module)
    static let fileTypeNotAllowed = String(localized: "attachment.type", defaultValue: "That type of file can't be sent.", bundle: .module)
    static let rateConversation = String(localized: "csat.prompt", defaultValue: "How would you rate your conversation?", bundle: .module)
    static let addRemark = String(localized: "csat.remark", defaultValue: "Tell us more (optional)", bundle: .module)
    static let thanksForRating = String(localized: "csat.thanks", defaultValue: "Thanks for your feedback!", bundle: .module)
    static let wasThisHelpful = String(localized: "article.reaction", defaultValue: "Did this answer your question?", bundle: .module)
    static let thanksForReaction = String(localized: "article.reaction.thanks", defaultValue: "Thanks for letting us know.", bundle: .module)
    static let messengerUnavailable = String(localized: "messenger.unavailable", defaultValue: "Messaging isn't available right now.", bundle: .module)

    static func replyExpectation(_ replyTime: String?) -> String {
        guard let replyTime, !replyTime.isEmpty else {
            return replySoon
        }

        return String(localized: "presence.reply_time", defaultValue: "We typically reply in \(replyTime)", bundle: .module)
    }

    static func articleCount(_ count: Int) -> String {
        String(localized: "help.article_count", defaultValue: "\(count) articles", bundle: .module)
    }
}
