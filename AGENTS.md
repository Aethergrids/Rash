# Rash agent instructions

Rash is a small zsh/tmux launcher for Clash RS with a vendored Yacd-meta web
UI. Make focused changes and keep the launcher understandable.

## Privacy boundary

- Treat every user profile as secret-bearing.
- User-ready profiles belong only at `configs/<PROFILE>/config.yaml`.
- Original Clash/Mihomo YAML inputs may be placed at the repository root or
  under `templates/`; they remain local inputs.
- Never commit or force-add any `.yaml` or `.yml` file from the repository
  root, `configs/`, or `templates/`. Check `git status` and the staged file list
  before every commit.
- Never expose server addresses, UUIDs, passwords, keys, certificates,
  controller secrets, or provider URLs in logs, diffs, commits, pull requests,
  or responses.

## Configuration work

Before creating, reviewing, or migrating a profile, read
`skills/clash-rs-config-expert/SKILL.md` completely and follow its validation
workflow. Instructions specific to incoming profiles are in
`templates/AGENTS.md`; the safe baseline is `templates/config.template`.

Preserve user behavior and credentials locally. Do not assume Mihomo-only
fields work in Clash RS. Validate the final graph and run the exact project
binary with both `--test-config` and `--strict-config`.

## Project conventions

- `clrs` is the user-facing command.
- `scripts/clrs-session.zsh` is the tmux process wrapper.
- `scripts/download-assets.zsh` is the only supported asset bootstrap/update
  path.
- `bin/` contains reproducible downloaded executables and stays untracked.
- `assets/yacd-meta/` contains vendored static UI files and `.rash-source`
  provenance metadata. Release downloads must match `SHA256SUMS`.
- `.clrs/` contains private runtime state and stays untracked.

Run `zsh -n clrs scripts/*.zsh` after shell changes. Run the asset downloader,
strict-validate local profiles without printing them, and exercise
`clrs start`, `clrs status`, the controller/UI endpoints, and `clrs stop` when
the corresponding local profiles are available.
