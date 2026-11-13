import Foundation
@testable import KaraDesk

enum Fixtures {
    static func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
        try Coding.decoder().decode(type, from: Data(json.utf8))
    }

    static let boot = """
    {
      "token": "tok_123",
      "expires_at": "2026-11-20T10:00:00.000Z",
      "app": { "id": "app_ios", "name": "Acme iOS" },
      "space": { "name": "Acme", "avatar": "https://cdn.example.com/a.png" },
      "settings": {
        "color": "#4F46E5",
        "theme": "dark",
        "logo_url": "https://cdn.example.com/logo.png",
        "header_text": "light",
        "background": { "type": "gradient", "color": null, "gradient_from": "#000", "gradient_to": "#222", "image": null, "fade": true },
        "background_image_url": null,
        "dark": { "color": null, "header_text": null, "background": null },
        "rules": {
          "visitors": { "allow_new": true, "single_open": true, "require_search": false, "closed_reply_days": 7 },
          "users": { "allow_new": false, "single_open": false, "require_search": true, "closed_reply_days": null }
        },
        "home_cards": [
          { "id": "c1", "type": "messages" },
          { "id": "c2", "type": "help", "help_center_id": 4, "help_center": { "id": 4, "name": "Help", "url": "https://help.example.com" }, "articles": [{ "id": 9, "title": "Install", "url": "https://help.example.com/articles/9" }] },
          { "id": "c3", "type": "carousel", "slides": [] },
          { "id": "c4", "type": "link", "title": "Status", "url": "https://status.example.com" }
        ],
        "greeting": "Hi there 👋",
        "intro": "How can we help?",
        "show_team": true,
        "show_branding": false,
        "show_help": true,
        "help_center": { "id": 4, "name": "Help", "url": "https://help.example.com", "article_reactions": true },
        "help_centers": [{ "id": 4, "name": "Help", "url": "https://help.example.com" }],
        "availability": { "open": false, "reply_time": "a few hours", "next_open_at": "2026-11-13T14:00:00Z" },
        "attachments": { "enabled": true, "max_bytes": 26214400, "accept": [".png", ".pdf"] },
        "a_future_setting": { "nested": true }
      },
      "identity": { "type": "user", "verified": true, "verification_required": false },
      "team": [{ "id": 1, "name": "Braden", "avatar": null }, { "name": "missing id" }],
      "contact": { "id": "ct_1", "role": "user", "name": "Evangelina", "email": "e@example.com", "avatar": null }
    }
    """

    static let thread = """
    {
      "conversation": {
        "id": 42, "app_id": "app_ios", "channel": "messenger", "state": "open", "title": null,
        "last_message": { "id": "msg_2", "type": "comment", "author_type": "user", "body": "Hello!", "created_at": "2026-11-12T10:01:00Z" },
        "last_message_at": "2026-11-12T10:01:00Z", "unread": true, "unread_count": 1,
        "created_at": "2026-11-12T10:00:00Z", "updated_at": "2026-11-12T10:01:00Z",
        "assignee": { "id": 1, "name": "Braden", "avatar": null, "last_active_at": "2026-11-12T10:00:30Z" }
      },
      "messages": [
        {
          "id": "msg_1", "conversation_id": 42, "type": "comment",
          "author": { "type": "contact", "id": "ct_1", "name": "Evangelina", "avatar": null },
          "body": "", "attachments": [
            { "type": "file", "asset_id": "a1", "name": "photo.png", "content_type": "image/png", "byte_size": 2048, "url": "https://cdn.example.com/a1.png" },
            { "type": "hologram", "id": "x" }
          ],
          "created_at": "2026-11-12T10:00:00.123Z"
        },
        {
          "id": "msg_2", "conversation_id": 42, "type": "comment",
          "author": { "type": "user", "id": 1, "name": "Braden", "avatar": null },
          "body": "Hello!", "attachments": [
            { "type": "article", "article_id": 9, "help_center_id": 4, "title": "Install", "description": null }
          ],
          "created_at": "2026-11-12T10:01:00Z"
        },
        {
          "id": "msg_3", "conversation_id": 42, "type": "poll",
          "author": { "type": "bot", "id": "kara", "name": "Kara", "avatar": null },
          "body": "?", "attachments": [], "created_at": "2026-11-12T10:02:00Z"
        },
        { "id": "broken" }
      ]
    }
    """
}
