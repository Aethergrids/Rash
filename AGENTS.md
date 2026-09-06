# Rash agent instructions

Rash is a small zsh/tmux launcher for Clash RS and sing-box on macOS and Linux,
with a vendored Yacd-meta web UI. Keep the launcher understandable.

## Supported scope

Rash supports HTTP/SOCKS5 proxy access and optional macOS system proxy settings.
TUN has been removed. Do not add TUN presets, privileged tmux sessions, route
management, or system DNS interception. Keep runtime rendering's removal of
Clash `tun` sections and replacement of sing-box inbounds/removal of endpoints
and services. sing-box's internal `hijack-dns` action is scoped to the explicit
local DNS listener; it does not change system DNS.

## Privacy boundary

- Treat every user profile as secret-bearing.
- User-ready profiles belong only at `configs/<PROFILE>/config.yaml` (Clash RS)
  or `configs/<PROFILE>/sing-box.json` (sing-box).
- Original Clash/Mihomo YAML inputs may be placed at the repository root or
  under `templates/`; they remain local inputs.
- Never commit or force-add any `.yaml`, `.yml`, or `.json` profile from the repository
  root, `configs/`, or `templates/`. Check `git status` and the staged file list
  before every commit.
- Never expose server addresses, UUIDs, passwords, keys, certificates,
  controller secrets, or provider URLs in logs, diffs, commits, pull requests,
  or responses.

## Configuration work

Before creating, reviewing, or migrating a Clash profile, read
`skills/clash-rs-config-expert/SKILL.md` completely and follow its validation
workflow. Instructions specific to incoming profiles are in
`templates/AGENTS.md`; the safe baseline is `templates/config.template`.

Preserve user behavior and credentials locally. Do not assume Mihomo-only
fields work in Clash RS. Validate the final graph and run the exact project
binary with both `--test-config` and `--strict-config`.

For native sing-box profiles, read `docs/sing-box-config.md`, start from
`templates/sing-box.template`, validate all outbound/rule/DNS references, and
run the installed `sing-box check`. Do not assume Clash YAML keys or MMDB files
work in sing-box. Keep schema validation separate from live connectivity.

## Project conventions

- `rash` is the user-facing command.
- `scripts/rash-session.zsh` is the tmux process wrapper.
- `scripts/download-assets.zsh` is the only supported asset bootstrap/update
  path. It detects Homebrew before installing sing-box with `brew install sing-box`.
- `bin/` contains reproducible downloaded executables and stays untracked.
- `assets/yacd-meta/` contains vendored static UI files and `.rash-source`
  provenance metadata. Release downloads must match `SHA256SUMS`.
- The asset downloader removes the pinned Yacd TUN settings card after archive
  verification. Preserve that local patch and its `.rash-source` provenance.
- `.rash/` contains private runtime state and stays untracked.
- Legacy `.clrs/` remains private and ignored; stop old sessions before upgrading.

Run `zsh -n rash scripts/*.zsh` after shell changes. Run the asset downloader,
strict-validate local profiles without printing them, and exercise
`rash start`, `rash status`, the controller/UI endpoints, and `rash stop` when
the corresponding local profiles are available. Exercise both clients and run
`zsh tests/clients.zsh` after changes to client dispatch or installation.
