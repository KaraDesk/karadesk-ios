import Foundation
import Testing
@testable import KaraDesk

@Suite("User")
struct UserTests {
    @Test func updatesOnlyWhatChanged() {
        let current = KaraDesk.User(id: "u1", email: "e@example.com", name: "Evangelina", phone: "555", userHash: "h1")
        let updated = current.merging(KaraDesk.User(name: "Evangelina Ruiz", avatarURL: URL(string: "https://example.com/a.png")))

        #expect(updated.id == "u1")
        #expect(updated.email == "e@example.com")
        #expect(updated.name == "Evangelina Ruiz")
        #expect(updated.phone == "555")
        #expect(updated.avatarURL?.absoluteString == "https://example.com/a.png")
        #expect(updated.userHash == "h1")
    }

    @Test func identityCannotChangeThroughAnUpdate() {
        let current = KaraDesk.User(id: "u1")

        #expect(current.merging(KaraDesk.User(id: "someone-else")).id == "u1")
    }

    @Test func needsAnIdentifier() {
        #expect(KaraDesk.User(id: "u1").isIdentifiable)
        #expect(KaraDesk.User(email: "e@example.com").isIdentifiable)
        #expect(!KaraDesk.User(name: "No identifier").isIdentifiable)
        #expect(!KaraDesk.User(id: "", email: "").isIdentifiable)
    }
}
