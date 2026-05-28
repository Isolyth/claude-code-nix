# claude-code-nix

A Nix flake that packages [Claude Code](https://github.com/anthropics/claude-code)
straight from Anthropic's official distribution bucket — so you can run the
newest release the moment it's published, **without waiting for nixpkgs to
repackage it**.

## Why this exists

The nixpkgs `claude-code` derivation just downloads a prebuilt binary from
Anthropic's public release bucket, addressed by version with a per-platform
checksum. But the nixpkgs package only updates once a maintainer bumps it,
which lags the actual release — sometimes by days.

This flake vendors the same derivation and a `manifest.json` pin, plus a `bump`
command that pulls a fresh manifest directly from the bucket. Updating is a
one-liner and doesn't depend on nixpkgs (or even on nixpkgs shipping
`claude-code` at all).

### The `latest` pointer vs. published versions

Anthropic uploads versioned binaries to the bucket *before* promoting the
`latest` pointer (a staged rollout). So at any moment:

- `…/releases/latest` → the **promoted** version (what the public changelog shows)
- `…/releases/<version>/manifest.json` → exists for every **published** version,
  including ones newer than `latest`

`nix run .#bump` with no argument tracks the promoted `latest`. Pass an explicit
version to grab a published-but-not-yet-promoted build:

```sh
nix run .#bump              # track the promoted `latest`
nix run .#bump -- 2.1.156   # pin a specific (possibly pre-promotion) version
```

## Usage

### Run it directly

```sh
nix run github:Isolyth/claude-code-nix          # run claude
nix run github:Isolyth/claude-code-nix#bump     # update the pinned manifest
```

### Install into a profile

```sh
nix profile install github:Isolyth/claude-code-nix
```

### Use the overlay in a NixOS / home-manager flake

```nix
{
  inputs.claude-code-nix.url = "github:Isolyth/claude-code-nix";

  # in your nixosSystem / homeConfiguration modules:
  { nixpkgs.overlays = [ inputs.claude-code-nix.overlays.default ]; }
  # now `pkgs.claude-code` is the bucket-tracked build
}
```

### Use the package output directly

```nix
inputs.claude-code-nix.packages.${system}.claude-code
```

## Updating the pin

```sh
# from a checkout of this repo:
nix run .#bump            # → latest promoted
nix run .#bump -- 2.1.156 # → specific version
git commit -am "claude-code: 2.1.156"
```

The pin is the vendored `manifest.json`. `bump` overwrites it with the bucket's
manifest for the chosen version; the build reads the checksum for your platform
out of it.

## Supported platforms

`x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin` (the manifest
also carries musl and Windows entries, mapped by Nix's platform key).

## License

The packaging in this repo is MIT (see [LICENSE](LICENSE)). Claude Code itself
is distributed by Anthropic under its own proprietary license — this flake only
fetches and wraps the official binary.
