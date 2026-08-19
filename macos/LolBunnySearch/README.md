# LolBunny Search for macOS

`LolBunnySearch` opens the existing LolBunny search route in the default
browser. Press Option-Command-L from any app to bring up its search field, or
open the app to search and to point it at a different LolBunny deployment. It
supports macOS 15 and later.

The keystroke is registered by the app's own process through Carbon's
`RegisterEventHotKey`, so it lives only as long as the app runs. The app does
not quit when its window closes, and a `--background` launch keeps the window
off the screen so a login agent can start it without interrupting login.

There is deliberately no App Intent. An ad-hoc signed build carries no team
identifier, and macOS then refuses to reach the intent handler: Spotlight lists
the action but running it fails with "Shortcuts couldn't communicate with the
app". A build signed with a Developer ID could offer one again.

## Local validation

Run the unit tests without signing:

```sh
nix run .#lolbunny-search-test
```

## Installation

Build the app bundle, which prints the bundle path on stdout:

```sh
nix run .#lolbunny-search-build
```

Both recipes accept `--source` and `--derived-data`, and the build also takes
`--bundle-id` and `--display-name`, so an installer can ship this app under its
own identity without editing the project file. They shell out to Xcode, which
cannot join the Nix build sandbox, so they are host scripts rather than
derivations.

Move the resulting `LolBunnySearch.app` to `/Applications` and launch it once.
Set the LolBunny address in Settings: the app ships pointed at nothing, because
which LolBunny an install talks to belongs to that deployment rather than to
this source tree. A managed host can seed it by writing `baseURL` into this
app's defaults domain, which is its bundle identifier.

Keep the app running: quitting it releases the keystroke until the app starts
again.

For distribution to other Macs, sign and notarize the app with a Developer ID
certificate.

The app only constructs the LolBunny search URL locally. It does not fetch,
cache, or index LolBunny data.
