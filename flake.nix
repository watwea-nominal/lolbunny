{
  description = "LolBunny - Nominal search launcher for macOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # The macOS companion is the only Nix-packaged output here, so there is
      # nothing to offer on Linux.
      darwinSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forDarwin = fn: nixpkgs.lib.genAttrs darwinSystems (system: fn nixpkgs.legacyPackages.${system});

      # Xcode is Apple's licensed toolchain and cannot be added to the Nix build
      # sandbox, so these outputs package the build and test recipes as scripts
      # that run on the host rather than derivations that produce the app.
      # `nix build` still checks them: `writeShellApplication` runs shellcheck.
      projectArguments = ''
        source_dir="$PWD/macos/LolBunnySearch"
        # Deliberately outside `builds/`, which a consumer's activation manages
        # per revision and prunes: a local build tree kept there would be
        # deleted on the next rebuild.
        derived_data="$HOME/Library/Caches/LolBunnySearch/dev/DerivedData"

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --source)
              source_dir="$2"
              shift 2
              ;;
            --derived-data)
              derived_data="$2"
              shift 2
              ;;
            --help)
              echo "usage: $0 [--source DIR] [--derived-data DIR]"
              exit 0
              ;;
            *)
              echo >&2 "$0: unexpected argument '$1'"
              exit 2
              ;;
          esac
        done

        project="$source_dir/LolBunnySearch.xcodeproj"
        if [ ! -d "$project" ]; then
          echo >&2 "$0: no Xcode project at $project"
          exit 1
        fi
      '';
    in
    {
      packages = forDarwin (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          default = self.packages.${system}.lolbunny-search-build;

          # Builds the app bundle and prints its path. Build chatter goes to
          # stderr so a caller can consume the path on stdout.
          lolbunny-search-build = pkgs.writeShellApplication {
            name = "lolbunny-search-build";
            text = ''
              ${projectArguments}

              # `CODE_SIGNING_ALLOWED=NO` keeps xcodebuild from reaching for a
              # developer identity. Whoever installs the bundle signs it at its
              # final path, since the signature covers that location.
              /usr/bin/xcrun xcodebuild \
                -project "$project" \
                -scheme LolBunnySearch \
                -configuration Release \
                -derivedDataPath "$derived_data" \
                -destination "platform=macOS,arch=$(/usr/bin/uname -m)" \
                CODE_SIGNING_ALLOWED=NO \
                build >&2

              printf '%s\n' "$derived_data/Build/Products/Release/LolBunnySearch.app"
            '';
          };

          lolbunny-search-test = pkgs.writeShellApplication {
            name = "lolbunny-search-test";
            text = ''
              ${projectArguments}

              /usr/bin/xcrun xcodebuild \
                -project "$project" \
                -scheme LolBunnySearch \
                -destination "platform=macOS,arch=$(/usr/bin/uname -m)" \
                -derivedDataPath "$derived_data" \
                test
            '';
          };
        }
      );

      apps = forDarwin (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          app = name: {
            type = "app";
            program = "${self.packages.${system}.${name}}/bin/${name}";
          };
        in
        {
          default = app "lolbunny-search-build";
          lolbunny-search-build = app "lolbunny-search-build";
          lolbunny-search-test = app "lolbunny-search-test";
        }
      );
    };
}
