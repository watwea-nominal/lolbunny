import OSLog

/// One home for the subsystem so every category lines up under a single
/// `log show --predicate 'subsystem == "io.nominal.lolbunny-search"'`.
enum LolBunnySearchLog {
    private static let subsystem = "io.nominal.lolbunny-search"

    static let hotKey = Logger(subsystem: subsystem, category: "hotkey")
    static let window = Logger(subsystem: subsystem, category: "window")
}
