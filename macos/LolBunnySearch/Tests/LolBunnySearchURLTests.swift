import XCTest
@testable import LolBunnySearch

private let address = "https://lolbunny.example.com"

final class LolBunnySearchURLTests: XCTestCase {
    func testEncodesQueryForSearchPath() throws {
        let url = try LolBunnySearchURL.make(for: "dash launch / \u{2603}", baseURL: address)

        XCTAssertEqual(
            url.absoluteString,
            "https://lolbunny.example.com/search/dash%20launch%20%2F%20%E2%98%83"
        )
    }

    func testTrimsAndRejectsEmptyQuery() {
        XCTAssertThrowsError(try LolBunnySearchURL.make(for: "  \n\t ", baseURL: address)) { error in
            XCTAssertEqual(error as? LolBunnySearchURLError, .emptyQuery)
        }
    }

    func testOpensEncodedSearchURL() throws {
        var openedURL: URL?

        try LolBunnySearchURL.openSearch(for: "dash launch / \u{2603}", baseURL: address) { url in
            openedURL = url
            return true
        }

        XCTAssertEqual(
            openedURL?.absoluteString,
            "https://lolbunny.example.com/search/dash%20launch%20%2F%20%E2%98%83"
        )
    }

    func testReportsWhenSearchURLCannotOpen() {
        XCTAssertThrowsError(
            try LolBunnySearchURL.openSearch(for: "dash launch", baseURL: address) { _ in false }
        ) { error in
            XCTAssertEqual(error as? LolBunnySearchURLError, .couldNotOpenURL)
        }
    }
}

final class LolBunnySearchBaseURLTests: XCTestCase {
    func testUsesAConfiguredAddress() throws {
        let url = try LolBunnySearchURL.make(for: "dash launch", baseURL: address)

        XCTAssertEqual(url.absoluteString, "https://lolbunny.example.com/search/dash%20launch")
    }

    func testDropsTrailingSlashesSoThePathNeverDoubles() throws {
        let url = try LolBunnySearchURL.make(for: "dash", baseURL: "https://lolbunny.example.com///")

        XCTAssertEqual(url.absoluteString, "https://lolbunny.example.com/search/dash")
    }

    func testRejectsAnAddressThatWouldOpenNothing() {
        for bad in ["", "   ", "lolbunny.example.com", "ftp://lolbunny.example.com", "https://"] {
            XCTAssertThrowsError(try LolBunnySearchURL.make(for: "dash", baseURL: bad), "accepted \(bad)") { error in
                XCTAssertEqual(error as? LolBunnySearchURLError, .invalidBaseURL)
            }
        }
    }
}

final class LolBunnySearchSettingsTests: XCTestCase {
    /// Guards the reason the address is a setting: a deployment hardcoded here
    /// would ship inside a public source tree.
    @MainActor
    func testShipsWithNoAddressSoNoDeploymentIsBakedIn() {
        let defaults = UserDefaults(suiteName: "LolBunnySearchTests.\(UUID().uuidString)")!

        XCTAssertEqual(LolBunnySearchSettings(defaults: defaults).baseURL, "")
    }
}
