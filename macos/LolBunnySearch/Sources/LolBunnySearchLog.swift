import Foundation
import OSLog

/// One home for the subsystem so every category lines up under a single
/// `log show --predicate 'subsystem == "<the bundle identifier>"'`.
///
/// Taken from the bundle rather than written here: an installer can rebuild this
/// app under its own identifier, and its logs should arrive under that name.
enum LolBunnySearchLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "LolBunnySearch"

    static let hotKey = Logger(subsystem: subsystem, category: "hotkey")
    static let window = Logger(subsystem: subsystem, category: "window")
}
