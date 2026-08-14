# Rash

Rash is a small, inspectable Clash RS launcher built around zsh and tmux. It
runs a private Clash RS profile in the background, exposes a local HTTP/SOCKS5
proxy, and serves Yacd-meta without installing a system daemon.

Rash currently supports regular proxy mode only. TUN is intentionally disabled
because Clash RS `v0.10.8` has shown repeatable, application-specific failures
on macOS even when mixed-proxy traffic is healthy.

## Quick start

Rash is designed primarily for macOS. Install the command-line dependencies:

```zsh
brew install tmux yq
```

Clone and bootstrap the versioned runtime assets:

```zsh
git clone https://github.com/Aethergrids/Rash.git
cd Rash
./scripts/download-assets.zsh
```

Place a Clash RS-compatible profile at `configs/JP/config.yaml` or
`configs/SG/config.yaml`, then start Rash:

```zsh
./clrs start --config SG --select --system-proxy
```

Open `http://127.0.0.1:9090/ui/` to manage the active connection. Stop Rash
when finished so any macOS proxy settings are restored:

```zsh
./clrs stop
```

To use `clrs` outside the repository:

```zsh
mkdir -p ~/.local/bin
ln -sfn "$PWD/clrs" ~/.local/bin/clrs
```

## What Rash runs

- Clash RS in a project-scoped tmux session
- a mixed HTTP/SOCKS5 proxy at `127.0.0.1:7890`
- the Clash controller and Yacd-meta at `127.0.0.1:9090`
- Clash DNS at `127.0.0.1:1053`

Only one profile runs at a time because profiles share these ports. Yacd-meta
is static content served by Clash RS, not a second daemon.

## Private profiles

No working profile or credentials are published. The launcher accepts these
local paths:

```text
configs/JP/config.yaml
configs/SG/config.yaml
```

To migrate an existing Clash Verge Rev or Mihomo profile, place a copy under
`templates/` and ask an agent to follow `templates/AGENTS.md`. The repository
includes an English `clash-rs-config-expert` skill and
`templates/config.template` as the compatibility baseline.

Profile YAML under the repository root, `configs/`, and `templates/` is ignored
intentionally. Never use `git add -f` for these files.

## Commands

| Command | Purpose |
| --- | --- |
| `clrs start --config JP` | Start one profile without changing macOS proxy settings |
| `clrs start --config SG --select` | Start and choose a Selector member after latency tests |
| `clrs start --config SG --select --system-proxy` | Start and enable the default `Wi-Fi` HTTP/HTTPS proxy |
| `clrs select` | Change the active Selector member |
| `clrs status` | Show the profile, mode, UI URL, and selected connection |
| `clrs system-proxy status` | Show Rash and effective macOS proxy state |
| `clrs system-proxy on\|off` | Enable or restore macOS proxy settings |
| `clrs exec -- COMMAND` | Run a terminal command through Rash |
| `clrs env` / `clrs env --unset` | Print shell commands that set or clear proxy variables |
| `clrs ui` | Open Yacd-meta |
| `clrs logs` | Print the retained tmux output |
| `clrs attach` | Attach to the tmux session; detach with `Ctrl-b`, then `d` |
| `clrs secret` | Print the private controller secret for Yacd-meta |
| `clrs stop` | Stop Clash RS and restore macOS proxy settings |

Selector choices are stored by Clash RS. A change made in Yacd-meta is
immediately reflected by `clrs status` and `clrs system-proxy status`:

```text
Connection: Proxy -> <selected member>
```

## macOS system proxy

Regular startup leaves macOS settings unchanged. Applications can use
`127.0.0.1:7890` directly, or Rash can manage the HTTP and HTTPS proxy for the
`Wi-Fi` network service:

```zsh
clrs start --config SG --select --system-proxy
clrs system-proxy status
clrs stop
```

`clrs stop` restores the previous settings. For another network service, start
Rash first and then specify its exact name:

```zsh
clrs system-proxy on --service "USB 10/100/1000 LAN"
```

Another VPN or network extension can override the effective system proxy.
Rash reports that condition instead of claiming the setting is active.

## OpenVPN and Cisco Secure Client

Connect the organization VPN first, then start Rash in regular mode:

```zsh
clrs start --config SG --select --system-proxy
```

Rash does not create a tunnel, replace routes, or hijack system DNS, so the VPN
keeps ownership of private routes and resolvers. Re-run `clrs system-proxy
status` after the VPN reconnects because its network extension may replace
macOS proxy settings.

Terminal programs do not consistently read the macOS proxy. Run one command
through Rash:

```zsh
clrs exec -- git pull
```

Or configure the current shell until you clear it:

```zsh
eval "$(clrs env)"
eval "$(clrs env --unset)"
```

Add organization-specific hosts to `NO_PROXY`, and keep private destinations
on `DIRECT` rules, when corporate traffic must bypass the public proxy.

## Runtime assets and releases

`./scripts/download-assets.zsh` installs and verifies:

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
./scripts/download-assets.zsh --only yacd-meta --force
./scripts/download-assets.zsh --only geoip --force
```

`RASH_RELEASE_VERSION`, `RASH_ASSET_BASE_URL`, `CLASH_RS_VERSION`,
`YACD_META_COMMIT`, `GEOIP_VERSION`, `GEOIP_SHA256`, and an optional
`GITHUB_TOKEN` are supported overrides. Run
`./scripts/download-assets.zsh --help` for details.

## Controller security

At startup, Rash creates a private runtime copy of the chosen profile. It
injects a loopback-only controller, the vendored UI path, the local MMDB path,
and a random per-project controller secret. Runtime files, tmux sockets,
caches, and secrets live under ignored `.clrs/` with restrictive permissions.

Do not expose port `9090` outside the machine. If Yacd-meta asks for the API
secret, run `clrs secret`.

## TUN status

`clrs start ... --tun` exits without starting Clash RS. Live macOS tests found
selective TLS timeouts in both the stable userspace stack and an unmerged
system-stack implementation while the same requests succeeded through the
mixed proxy. Rash will reconsider TUN when upstream macOS behavior is mature
and reliably covered.

## Validate a profile

The launcher strictly validates a private runtime copy on every start. To check
a profile manually:

```zsh
./bin/clash --directory "$PWD/configs/JP" \
  --config "$PWD/configs/JP/config.yaml" \
  --test-config --strict-config
```

Parser success confirms schema compatibility, not remote credentials or live
connectivity. `HANDOFF.md` contains a concise, privacy-safe smoke-test workflow.

## License

Rash is MIT licensed. See `LICENSE` and `THIRD_PARTY_NOTICES.md` for mirrored
dependency provenance and licenses.
