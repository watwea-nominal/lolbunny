import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    /// Broadcast when the global keystroke asks for a fresh search, so the field
    /// can clear and take focus wherever the window happens to be.
    static let lolBunnySearchRequested = Notification.Name(
        "\(Bundle.main.bundleIdentifier ?? "LolBunnySearch").searchRequested"
    )
}

@main
struct LolBunnySearchApp: App {
    @NSApplicationDelegateAdaptor(LolBunnySearchAppDelegate.self) private var delegate

    /// The name this bundle was built with, so the window matches whatever an
    /// installer chose rather than a name fixed in source.
    private static let displayName =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "LolBunny Search"

    var body: some Scene {
        Window(Self.displayName, id: "search") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

/// Owns the global keystroke, which arrives whether or not a window is open and
/// so cannot be handled from a view that may not exist at the time.
@MainActor
final class LolBunnySearchAppDelegate: NSObject, NSApplicationDelegate {
    /// Passed by the login agent, whose only job is to keep this process alive to
    /// own the keystroke.
    static let backgroundLaunchArgument = "--background"

    func applicationDidFinishLaunching(_ notification: Notification) {
        GlobalSearchHotKey.shared.install {
            LolBunnySearchAppDelegate.presentSearch()
        }

        guard ProcessInfo.processInfo.arguments.contains(Self.backgroundLaunchArgument) else {
            return
        }
        // Login must not be interrupted by a search window. The second pass runs
        // after the first run loop turn because SwiftUI may not have built the
        // scene's window yet when this delegate callback fires.
        hideAllWindows()
        Task { @MainActor in
            hideAllWindows()
        }
    }

    /// The window is a way in, not the app itself: quitting with it would drop the
    /// global keystroke, which is the whole point of staying resident.
    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        false
    }

    private func hideAllWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        NSApp.hide(nil)
    }

    /// Asking the workspace to open our own bundle is the one route onto the
    /// screen that works from every state the app can be in, including the hidden
    /// login launch, and it lands the window in well under a tenth of a second.
    /// Reaching into `NSApp.windows` instead would have to unhide, activate, and
    /// rebuild a scene window that SwiftUI owns.
    private static func presentSearch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error {
                LolBunnySearchLog.window.error("Could not raise the search window: \(error.localizedDescription)")
            }
            Task { @MainActor in
                NotificationCenter.default.post(name: .lolBunnySearchRequested, object: nil)
            }
        }
    }
}

private struct ContentView: View {
    @StateObject private var settings = LolBunnySearchSettings.shared
    @State private var query = ""
    @State private var status: String?
    @State private var showingSettings = false
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search LolBunny", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($queryFocused)
                    .onSubmit(search)
                Button("Search", action: search)
                    .keyboardShortcut(.defaultAction)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // The address differs per deployment and is not shipped, so it has
            // to be reachable here, and opens on its own until it is set.
            DisclosureGroup("Settings", isExpanded: $showingSettings) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LolBunny address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(LolBunnySearchURL.placeholderBaseURL, text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                    Text("Searches open at this address under /search/.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            if let status {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Text(hotKeyHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 460)
        .onAppear {
            showingSettings = settings.baseURL.isEmpty
            queryFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .lolBunnySearchRequested)) { _ in
            query = ""
            status = nil
            queryFocused = true
        }
    }

    private var hotKeyHint: String {
        let keystroke = GlobalSearchHotKey.displayName
        return GlobalSearchHotKey.shared.isRegistered
            ? "Press \(keystroke) from anywhere to search."
            : "\(keystroke) is taken by another app, so searching starts here."
    }

    private func search() {
        do {
            try LolBunnySearchURL.openSearch(for: query, baseURL: settings.baseURL) { url in
                NSWorkspace.shared.open(url)
            }
            status = nil
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? "The search could not be opened."
        }
    }
}
