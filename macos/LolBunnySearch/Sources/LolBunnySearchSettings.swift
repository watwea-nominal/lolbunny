import Foundation

private let baseURLDefaultsKey = "baseURL"

/// Where this install points, persisted across launches.
///
/// Empty until someone sets it: the same app is pointed at whichever LolBunny a
/// team runs, so the address is a setting rather than a constant in the source.
/// A managed host can seed it by writing `baseURL` into this app's defaults
/// domain.
@MainActor
final class LolBunnySearchSettings: ObservableObject {
    static let shared = LolBunnySearchSettings()

    private let defaults: UserDefaults

    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: baseURLDefaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        baseURL = defaults.string(forKey: baseURLDefaultsKey) ?? ""
    }
}
