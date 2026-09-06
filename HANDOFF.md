# OpenCode handoff: local Rash smoke test

## Goal

Prove that the private `SG` profile works with Clash RS,
Yacd-meta, the macOS system proxy switch, and both HTTP and SOCKS5 proxy
access. Rash supports regular proxy access only.

The historical investigation and TUN removal decision are in `TEST_RESULTS.md`.

## Safety

- Read `AGENTS.md` first.
- Do not print, edit, or commit profile YAML, controller secrets, or proxy
  credentials.
- Do not paste raw configs or logs into the report. Summarize failures with
  secrets and server addresses redacted.
- Always run `./clrs stop` before finishing.

## Regular proxy test

Run from the repository root:

```zsh
set -eu

./scripts/download-assets.zsh
test -r configs/SG/config.yaml

cleanup() {
  ./clrs stop >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP

for profile in SG; do
  ./clrs start --config "$profile"
  ./clrs status

  controller_secret="$(./clrs secret)"
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

  print -r -- "${profile}: controller=${controller_code} ui=${ui_code} http=${http_code} socks5=${socks_code}"
  [[ "$controller_code" == 200 && "$ui_code" == 200 ]]
  [[ "$http_code" == 204 && "$socks_code" == 204 ]]

  ./clrs stop
done

trap - EXIT INT TERM HUP
```

Expected result for SG:

```text
controller=200 ui=200 http=204 socks5=204
```

## Selector status and prompt

Run this part interactively:

```zsh
./clrs start --config SG --select
./clrs status
./clrs system-proxy status || true
./clrs select
./clrs stop
```

Expected result: the prompt displays latency for each `Proxy` member and marks
the current/default member. Pressing Return keeps it. Both status commands
must print the same live `Connection: Proxy -> <member>` value. If the member
is changed in Yacd, the next status command must show that change.

## System proxy switch

Close Clash Verge Rev, Shadowrocket, or any other proxy VPN first, then run:

```zsh
./clrs start --config SG --system-proxy
./clrs system-proxy status
/usr/sbin/scutil --proxy | sed -n '1,/__SCOPED__/p'
./clrs exec -- git ls-remote https://github.com/Aethergrids/Rash.git HEAD
./clrs stop
./clrs system-proxy status || true
```

Expected result: the effective HTTP and HTTPS proxy is
`127.0.0.1:7890`. `./clrs stop` must restore the previous settings and report
the Rash system proxy as off. Do not alter another proxy app's settings to
force this check; report an override if the user has left one running.

## Removed option

Confirm that the removed option is rejected before startup:

```zsh
./clrs start --config SG --tun
./clrs status || true
```

Expected result: the first command reports `unknown start option: --tun` and
the second reports `Clash RS: stopped`. TUN is no longer a project feature.
In Yacd's settings page, confirm that ordinary proxy settings remain available
and there is no TUN panel. The asset downloader must preserve this removal
after `--only yacd-meta --force`.

## Report

Return only:

- Clash RS version
- SG result codes
- Selector latency prompt and selected connection
- system proxy on/effective/restored result
- removed option rejected before startup
- whether `./clrs stop` left the service stopped
- concise, redacted failure reasons
