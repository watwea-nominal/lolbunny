import Foundation

enum LolBunnySearchURLError: Error, Equatable {
    case emptyQuery
    case invalidQuery
    case invalidBaseURL
    case couldNotOpenURL
}

extension LolBunnySearchURLError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            "Enter a search query."
        case .invalidQuery:
            "The search query could not be encoded."
        case .invalidBaseURL:
            "Set a LolBunny address like \(LolBunnySearchURL.placeholderBaseURL)."
        case .couldNotOpenURL:
            "The search URL could not be opened."
        }
    }
}

enum LolBunnySearchURL {
    /// Prompt text for the address field, and the example in the error copy.
    ///
    /// The app ships pointed at nothing on purpose: which LolBunny an install
    /// talks to is a property of that deployment, so it is configured on the
    /// host rather than baked into this source tree.
    static let placeholderBaseURL = "https://lolbunny.example.com"

    private static let unreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func make(for query: String, baseURL: String) throws -> URL {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw LolBunnySearchURLError.emptyQuery
        }
        let root = try normalizedBase(baseURL)
        guard let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: unreservedCharacters),
              let url = URL(string: "\(root)/search/\(encodedQuery)")
        else {
            throw LolBunnySearchURLError.invalidQuery
        }
        return url
    }

    /// Trailing slashes are dropped so the joined path never doubles one, and a
    /// base without an http(s) scheme is refused rather than silently producing
    /// a relative URL that opens nothing.
    private static func normalizedBase(_ baseURL: String) throws -> String {
        var root = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while root.hasSuffix("/") {
            root.removeLast()
        }
        guard !root.isEmpty,
              let parsed = URL(string: root),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              parsed.host?.isEmpty == false
        else {
            throw LolBunnySearchURLError.invalidBaseURL
        }
        return root
    }

    static func openSearch(
        for query: String,
        baseURL: String,
        using opener: (URL) -> Bool
    ) throws {
        let url = try make(for: query, baseURL: baseURL)
        guard opener(url) else {
            throw LolBunnySearchURLError.couldNotOpenURL
        }
    }
}
