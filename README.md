# Rash

Rash is a small, inspectable Clash RS client for macOS. It combines a zsh CLI,
a project-scoped tmux session, private local profiles, and the Yacd-meta web UI
without installing a system daemon.

## What it runs

- Clash RS in a background tmux session
- A mixed HTTP/SOCKS5 proxy on `127.0.0.1:7890`
- The Clash controller and vendored Yacd-meta UI on `127.0.0.1:9090`
- Clash DNS on `127.0.0.1:1053`

Only one profile runs at a time because profiles share these ports. Yacd-meta
is static content served by Clash RS, not a second daemon.

## Requirements

Rash expects macOS, zsh, `curl`, `unzip`, `openssl`,
[tmux](https://github.com/tmux/tmux), and
[yq v4](https://github.com/mikefarah/yq). With Homebrew:

```zsh
brew install tmux yq
```

## Bootstrap assets

Download the matching pre-built Clash RS binary and Yacd-meta site into this
project:

```zsh
./scripts/download-assets.zsh
```

The downloader selects the macOS/Linux architecture, fetches the mirrored
dependencies from the Rash release, and verifies them against that release's
`SHA256SUMS`. The mirrored Clash RS checksums are also compared with the
official upstream release before publication. It installs:

- `bin/clash` — local generated executable, ignored by Git
- `assets/yacd-meta/` — vendored UI with upstream provenance in `.rash-source`

Useful update commands:

```zsh
./scripts/download-assets.zsh --only yacd-meta --force
./scripts/download-assets.zsh --only clash-rs --force
```

Release [`v1.0.0`](https://github.com/Aethergrids/Rash/releases/tag/v1.0.0)
contains Clash RS `v0.10.8` for macOS and Linux on arm64 and x86_64, plus the
Yacd-meta `gh-pages` snapshot. `RASH_RELEASE_VERSION`,
`RASH_ASSET_BASE_URL`, `CLASH_RS_VERSION`, `YACD_META_COMMIT`, and an optional
`GITHUB_TOKEN` can be provided as environment variables. Run
`./scripts/download-assets.zsh --help` for the complete interface.

## Add private profiles

No working profile YAML is published with this repository. Put each local,
Clash RS-compatible profile at:

```text
configs/<PROFILE>/config.yaml
```

For example, the launcher currently accepts `JP` and `SG` at
`configs/JP/config.yaml` and `configs/SG/config.yaml`.

To migrate an existing Clash Verge Rev or Mihomo profile, place a copy under
`templates/` and ask an agent to follow `templates/AGENTS.md`. The project
includes an English `clash-rs-config-expert` skill and a safe
`templates/config.template` baseline. Inputs are preserved; converted output
goes to `configs/<PROFILE>/config.yaml`.

The root, `configs/`, and `templates/` YAML ignore rules are intentional.
Never use `git add -f` for profile files.

## Install the command

Run it directly as `./clrs`, or add a symlink to a directory already on your
`PATH`:

```zsh
mkdir -p ~/.local/bin
ln -sfn "$PWD/clrs" ~/.local/bin/clrs
```

## Use Rash

```zsh
clrs start --config JP
clrs start --config SG
clrs start --config JP --tun

clrs status
clrs logs
clrs attach
clrs ui
clrs secret
clrs stop
```

Regular mode does not alter macOS proxy settings. Point applications or the
macOS system proxy at `127.0.0.1:7890` when needed.

TUN mode is macOS-only in the current preset. It requests `sudo`, creates
`utun1989`, uses `198.19.0.1/16` as its gateway, routes all traffic, and
hijacks DNS. Stop it with `clrs stop` so Clash RS can remove routes cleanly.

`clrs attach` opens the tmux session. Detach without stopping it by pressing
`Ctrl-b`, then `d`. If Clash RS exits unexpectedly, the session stays open so
`clrs logs` and `clrs attach` retain the error.

## Controller and UI security

At startup, `clrs` creates a private runtime copy of the selected profile. It
injects a loopback-only controller, the vendored UI path, and a random
per-project controller secret. Runtime files, tmux sockets, caches, and the
secret live under ignored `.clrs/` with restrictive permissions.

Open `http://127.0.0.1:9090/ui/` with `clrs ui`. If Yacd asks for the API
secret, run `clrs secret`. Do not expose port `9090` outside the machine.

## Validate a profile manually

```zsh
./bin/clash --directory "$PWD/configs/JP" \
  --config "$PWD/configs/JP/config.yaml" \
  --test-config --strict-config
```

Strict parser success confirms schema compatibility, not that remote proxy
credentials or live connectivity work.

## License

Rash is MIT licensed. See `LICENSE` and `THIRD_PARTY_NOTICES.md` for mirrored
dependency provenance and licenses.
