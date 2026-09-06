# Rash

Rash is a small zsh/tmux launcher for Clash RS and sing-box on macOS and Linux.
It runs a private profile in the background, exposes a local HTTP/SOCKS5 proxy,
and serves Yacd-meta without installing a system daemon. Both clients use the
same commands; Clash RS is the default.

Rash supports HTTP/SOCKS5 proxy access and optional macOS system proxy settings.
TUN has been removed from the project.

## Quick start

Install [Homebrew](https://brew.sh) and add it to your shell's `PATH` first.
Then install the command-line dependencies on macOS or Linux:

```zsh
brew install zsh tmux yq
```

Also ensure `curl`, `unzip`, `openssl`, and `lsof` are available. On Linux,
`rash ui` uses `xdg-open` when installed; a headless host can open the displayed
URL manually. Clone and bootstrap the runtime assets:

```zsh
git clone https://github.com/Aethergrids/Rash.git
cd Rash
./scripts/download-assets.zsh
```

The bootstrap checks for Homebrew before installing anything and uses
`brew install sing-box` for the second client. It reuses an existing Homebrew
installation of sing-box. The other assets use verified release downloads.

Place a Clash RS-compatible profile at `configs/SG/config.yaml`, then start:

```zsh
./rash start --config SG --select
```

Or place a native sing-box profile at `configs/SG/sing-box.json` and run:

```zsh
./rash start --config SG --client sing-box --select
```

On macOS, add `--system-proxy` to either start command to enable the system
HTTP/HTTPS proxy. On Linux, use explicit proxy settings, `rash env`, or
`rash exec`.

Open `http://127.0.0.1:9090/ui/` to manage the active connection. Stop Rash
when finished so any macOS proxy settings are restored:

```zsh
./rash stop
```

To use `rash` outside the repository:

```zsh
mkdir -p ~/.local/bin
ln -sfn "$PWD/rash" ~/.local/bin/rash
```

## What Rash runs

- the selected client in a project-scoped tmux session
- a mixed HTTP/SOCKS5 proxy at `127.0.0.1:7890`
- a Clash-compatible controller and Yacd-meta at `127.0.0.1:9090`
- a local DNS listener at `127.0.0.1:1053`

Only one client runs at a time because both share these ports. Run `rash stop`
before switching clients. The selected client serves the static Yacd-meta UI.

## Private profiles

No working profile or credentials are published. The launcher accepts this
local paths:

```text
configs/SG/config.yaml      # Clash RS
configs/SG/sing-box.json    # sing-box
```

To migrate an existing Clash Verge Rev or Mihomo profile, place a copy under
`templates/` and ask an agent to follow `templates/AGENTS.md`. The repository
includes an English `clash-rs-config-expert` skill and
`templates/config.template` as the compatibility baseline.

For sing-box, start from `templates/sing-box.template` and follow
[`docs/sing-box-config.md`](docs/sing-box-config.md). It is a native JSON
configuration, not a renamed Clash YAML file. The launcher does not convert
subscriptions or credentials automatically. Only the selected client's file
is required.

Profile YAML and JSON under the repository root, `configs/`, and `templates/`
are ignored intentionally. Never use `git add -f` for these files.

## Commands

| Command | Purpose |
| --- | --- |
| `rash start --config SG` | Start one profile without changing macOS proxy settings |
| `rash start --config SG --client sing-box` | Start the native sing-box profile |
| `rash start --config SG --select` | Start and choose a Selector member after latency tests |
| `rash start --config SG --select --system-proxy` | Start and enable the default `Wi-Fi` HTTP/HTTPS proxy |
| `rash select` | Change the active Selector member |
| `rash status` | Show the client, profile, UI URL, and selected connection |
| `rash system-proxy status` | Show Rash and effective macOS proxy state |
| `rash system-proxy on\|off` | Enable or restore macOS proxy settings |
| `rash exec -- COMMAND` | Run a terminal command through Rash |
| `rash env` / `rash env --unset` | Print shell commands that set or clear proxy variables |
| `rash ui` | Open Yacd-meta |
| `rash logs` | Print the retained tmux output |
| `rash attach` | Attach to the tmux session; detach with `Ctrl-b`, then `d` |
| `rash secret` | Print the private controller secret for Yacd-meta |
| `rash stop` | Stop the active client and restore macOS proxy settings |

All commands operate on the active client. Selector choices are stored
separately for each client. A change made in Yacd-meta is
immediately reflected by `rash status` and `rash system-proxy status`:

```text
Connection: Proxy -> <selected member>
```

Clash RS 0.10.8 flushes its selection cache every 10 seconds. Allow that
interval after changing a node before stopping it if you need the choice to
survive a restart.

## macOS system proxy

Regular startup leaves macOS settings unchanged. Applications can use
`127.0.0.1:7890` directly, or Rash can manage the HTTP and HTTPS proxy for the
`Wi-Fi` network service:

```zsh
rash start --config SG --select --system-proxy
rash system-proxy status
rash stop
```

`rash stop` restores the previous settings. For another network service, start
Rash first and then specify its exact name:

```zsh
rash system-proxy on --service "USB 10/100/1000 LAN"
```

Another VPN or network extension can override the effective system proxy.
Rash reports that condition instead of claiming the setting is active.

## OpenVPN and Cisco Secure Client

Connect the organization VPN first, then start Rash in regular mode:

```zsh
rash start --config SG --select --system-proxy
```

Rash does not create a tunnel, replace routes, or hijack system DNS, so the VPN
keeps ownership of private routes and resolvers. Re-run `rash system-proxy
status` after the VPN reconnects because its network extension may replace
macOS proxy settings.

Terminal programs do not consistently read the macOS proxy. Run one command
through Rash:

```zsh
rash exec -- git pull
```

Or configure the current shell until you clear it:

```zsh
eval "$(rash env)"
eval "$(rash env --unset)"
```

Add organization-specific hosts to `NO_PROXY`, and keep private destinations
on `DIRECT` rules, when corporate traffic must bypass the public proxy.

## Runtime assets and releases

`./scripts/download-assets.zsh` installs and verifies:

- Homebrew's `sing-box` formula, including the `with_clash_api` build capability
- `bin/clash` — the matching Clash RS `v0.10.8` executable
- `assets/yacd-meta/` — a pinned Yacd-meta `gh-pages` snapshot
- `assets/geoip/Country.mmdb` — the pinned GeoIP database used by `GEOIP` rules

The current dependency bundle is attached to release
[`v1.1.0`](https://github.com/Aethergrids/Rash/releases/tag/v1.1.0). It contains
Clash RS binaries for macOS and Linux on arm64 and x86_64, Yacd-meta, upstream
license files, provenance metadata, and `SHA256SUMS`. The downloader verifies
every mirrored file before installation. GeoIP is fetched from its pinned
upstream release and verified against a repository-pinned SHA-256 digest.

To avoid duplicating large third-party binaries, dependency assets are retained
only on the latest Rash release. Historical tags and release notes remain, but
their bootstrap assets may be removed. Use the downloader from the latest
checkout.

Useful asset commands:

```zsh
./scripts/download-assets.zsh --only clash-rs --force
./scripts/download-assets.zsh --only sing-box
./scripts/download-assets.zsh --only sing-box --force
./scripts/download-assets.zsh --only yacd-meta --force
./scripts/download-assets.zsh --only geoip --force
```

`RASH_RELEASE_VERSION`, `RASH_ASSET_BASE_URL`, `CLASH_RS_VERSION`,
`YACD_META_COMMIT`, `GEOIP_VERSION`, `GEOIP_SHA256`, and an optional
`GITHUB_TOKEN` are supported overrides. `BREW_BIN` selects a Homebrew executable;
`--force` uses `brew reinstall sing-box`. Homebrew controls the sing-box version
(tested with 1.14.0); it is not part of the pinned release bundle. Installing
only Clash RS, Yacd, or GeoIP does not require Homebrew. Run
`./scripts/download-assets.zsh --help` for details.

## Controller security

At startup, Rash creates a private runtime copy of the chosen profile. It
injects a loopback-only controller, the vendored UI path, and a random
per-project controller secret. Clash RS also receives the local MMDB path;
sing-box receives local mixed/DNS listeners and its own selection cache.
Runtime files, tmux sockets,
caches, and secrets live under ignored `.rash/` with restrictive permissions.

Do not expose port `9090` outside the machine. If Yacd-meta asks for the API
secret, run `rash secret`.

## Supported scope

Rash runs a user-owned tmux session with HTTP/SOCKS5 listeners. TUN, route
management, and DNS hijacking are outside the project's feature set.
`--tun` is not a recognized option, and runtime rendering removes any `tun`
section from Clash profiles. For sing-box it replaces all source inbounds
with local mixed/DNS listeners and removes endpoints and services. Its
`hijack-dns` routing action handles only requests sent to the explicit local
DNS listener; it does not intercept system DNS. The bundled Yacd settings page has no TUN
panel; the asset downloader reapplies this change after a dashboard refresh.
The historical investigation and removal decision are recorded in
[`TEST_RESULTS.md`](TEST_RESULTS.md).

## Upgrading from clrs

Before updating, stop any running session with the old `clrs stop`. The command
and wrapper are now `rash` and `scripts/rash-session.zsh`; update shell aliases
or recreate your symlink using the quick-start instructions above. There is no
`clrs` alias in the new checkout. Environment overrides previously prefixed
`CLRS_` now use `RASH_` (for example, `RASH_STATE_DIR` and
`RASH_NETWORK_SERVICE`). `CLASH_BIN` remains available, and `SING_BOX_BIN` can
select a sing-box executable outside `PATH`.

New private state lives in `.rash/`, with separate runtime/cache directories
for each client. Old `.clrs/` data remains ignored; it is not migrated. Profiles
stay in `configs/SG/`. Expect a new controller secret and select your preferred
node again after upgrading.

## Validate a profile

The launcher strictly validates a private runtime copy on every start. To check
a profile manually:

```zsh
./bin/clash --directory "$PWD/configs/SG" \
  --config "$PWD/configs/SG/config.yaml" \
  --test-config --strict-config

sing-box check --directory "$PWD/configs/SG" \
  --config "$PWD/configs/SG/sing-box.json"
```

Parser success confirms schema compatibility, not remote credentials or live
connectivity. `HANDOFF.md` contains a concise, privacy-safe smoke-test workflow.
Run `zsh tests/clients.zsh` for isolated launcher/installer regression checks.
The client integration results are recorded in
[`docs/client-test-results.md`](docs/client-test-results.md).

## License

Rash is MIT licensed. See `LICENSE` and `THIRD_PARTY_NOTICES.md` for mirrored
dependency provenance and licenses.
