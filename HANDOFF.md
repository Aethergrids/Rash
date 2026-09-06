# OpenCode handoff: local Rash smoke test

## Goal

Prove that the private `SG` profiles work with Clash RS and sing-box,
Yacd-meta, the macOS system proxy switch, and both HTTP and SOCKS5 proxy
access. Rash supports regular proxy access only.

The historical investigation and TUN removal decision are in `TEST_RESULTS.md`.

## Safety

- Read `AGENTS.md` first.
- Do not print or commit profile YAML/JSON, controller secrets, or proxy
  credentials.
- Do not paste raw configs or logs into the report. Summarize failures with
  secrets and server addresses redacted.
- Always run `./rash stop` before finishing.

## Regular proxy test

Run from the repository root:

```zsh
set -eu

./scripts/download-assets.zsh
test -r configs/SG/config.yaml
test -r configs/SG/sing-box.json
mkdir -p .rash/checks
chmod 700 .rash/checks
umask 077

cleanup() {
  ./rash stop >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP

for client in clash-rs sing-box; do
  ./rash start --config SG --client "$client" > ".rash/checks/$client-start.log" 2>&1
  ./rash status > ".rash/checks/$client-status.log"

  controller_secret="$(./rash secret)"
  controller_code="$(curl --fail --silent --show-error --output /dev/null \
    --write-out '%{http_code}' --max-time 10 \
    --header "Authorization: Bearer ${controller_secret}" \
    http://127.0.0.1:9090/version)"
  ui_code="$(curl --fail --silent --show-error --output /dev/null \
    --write-out '%{http_code}' --max-time 10 \
    http://127.0.0.1:9090/ui/)"
  http_code="$(curl --fail --silent --show-error --output /dev/null \
    --write-out '%{http_code}' --max-time 20 \
    --proxy http://127.0.0.1:7890 \
    https://www.gstatic.com/generate_204)"
  socks_code="$(curl --fail --silent --show-error --output /dev/null \
    --write-out '%{http_code}' --max-time 20 \
    --socks5-hostname 127.0.0.1:7890 \
    https://www.gstatic.com/generate_204)"
  unset controller_secret

  print -r -- "${client}: controller=${controller_code} ui=${ui_code} http=${http_code} socks5=${socks_code}"
  [[ "$controller_code" == 200 && "$ui_code" == 200 ]]
  [[ "$http_code" == 204 && "$socks_code" == 204 ]]

  ./rash stop
done

trap - EXIT INT TERM HUP
```

Expected result for SG with each client:

```text
controller=200 ui=200 http=204 socks5=204
```

## Selector status and prompt

Run this part interactively for each client (`clash-rs` and `sing-box`):

```zsh
./rash start --config SG --client sing-box --select
./rash status
./rash system-proxy status || true
./rash select
./rash stop
```

Expected result: the prompt displays latency for each `Proxy` member and marks
the current/default member. Pressing Return keeps it. Both status commands
must print the same live `Connection: Proxy -> <member>` value. If the member
is changed in Yacd, the next status command must show that change. Change the
selection, stop/start the same client, confirm it was saved, then restore the
original selection. With Clash RS 0.10.8, wait at least 10 seconds before each
stop so its periodic cache writer can persist the change. Confirm Yacd's
Rule/Global/Direct mode controls work.

## System proxy switch

On macOS, close other proxy VPNs first, then run for each client:

```zsh
./rash start --config SG --client sing-box --system-proxy
./rash system-proxy status
/usr/sbin/scutil --proxy | sed -n '1,/__SCOPED__/p'
./rash exec -- git ls-remote https://github.com/Aethergrids/Rash.git HEAD
./rash stop
./rash system-proxy status || true
```

Expected result: the effective HTTP and HTTPS proxy is
`127.0.0.1:7890`. `./rash stop` must restore the previous settings and report
the Rash system proxy as off. Do not alter another proxy app's settings to
force this check; report an override if the user has left one running.

## Removed option

Confirm that the removed option is rejected before startup:

```zsh
./rash start --config SG --tun
./rash status || true
```

Expected result: the first command reports `unknown start option: --tun` and
the second reports `Rash: stopped`. Repeat with `--client sing-box`.
TUN is no longer a project feature.
In Yacd's settings page, confirm that ordinary proxy settings remain available
and there is no TUN panel. The asset downloader must preserve this removal
after `--only yacd-meta --force`.

## Installation and platform checks

Run `zsh tests/clients.zsh` to check client dispatch, native rendering, removed
TUN input, Homebrew detection/install/reuse/reinstall, and platform guards in
an isolated directory. These tests simulate OS selection; a native Linux
integration test still requires a Linux host with its own dependencies.

Test `rash env`, `rash exec`, local DNS on port 1053, `rash logs`, `rash attach`,
and `rash ui` for each client. Verify old `clrs` is absent from the checkout.
Check `git status` and ignored private files before committing.

## Report

Return only:

- OS and both client versions
- SG result codes for each client
- Selector latency prompt and selected connection
- system proxy on/effective/restored result
- removed option rejected before startup
- whether `./rash stop` left the service stopped
- concise, redacted failure reasons
