{
  description = "claude-code packaged straight from Anthropic's distribution bucket, ahead of nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay usable from any nixpkgs: adds `claude-code` built from the
      # vendored manifest.json, regardless of whether nixpkgs ships it yet.
      overlay = final: prev: {
        claude-code = final.callPackage ./package.nix { };
      };
    in
    {
      overlays.default = overlay;
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };

        # `nix run .#bump [-- <version>]` rewrites manifest.json from the
        # bucket. No arg tracks the promoted `latest`; pass a version string
        # (e.g. 2.1.156) to grab a specific build — including ones the bucket
        # has published but not yet promoted to `latest`.
        bump = pkgs.writeShellApplication {
          name = "bump-claude-code";
          runtimeInputs = [ pkgs.curl pkgs.coreutils ];
          text = ''
            base="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
            version="''${1:-$(curl -fsSL "$base/latest")}"
            # Write to the repo checkout you invoke this from. Override with
            # MANIFEST_DIR=/path/to/repo when running from elsewhere.
            target="''${MANIFEST_DIR:-$PWD}/manifest.json"
            echo "fetching claude-code $version manifest -> $target"
            curl -fsSL "$base/$version/manifest.json" --output "$target"
            echo "pinned claude-code to $version"
          '';
        };
      in
      {
        packages = {
          claude-code = pkgs.claude-code;
          default = pkgs.claude-code;
        };

        apps = {
          bump = {
            type = "app";
            program = "${bump}/bin/bump-claude-code";
          };
          default = {
            type = "app";
            program = "${pkgs.claude-code}/bin/claude";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.claude-code bump ];
        };
      });
}
