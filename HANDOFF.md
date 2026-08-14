# OpenCode handoff: local Rash smoke test

## Goal

Prove that the existing private `JP` and `SG` profiles work with Clash RS,
Yacd-meta, the macOS system proxy switch, and both HTTP and SOCKS5 proxy
access. Test macOS TUN mode last.

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
test -r configs/JP/config.yaml
test -r configs/SG/config.yaml

cleanup() {
  ./clrs stop >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP

for profile in JP SG; do
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

Expected result for both profiles:

```text
controller=200 ui=200 http=204 socks5=204
```

## Selector status and prompt

Run this part interactively:

```zsh
./clrs start --config JP --select
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
./clrs start --config JP
./clrs system-proxy on
./clrs system-proxy status
/usr/sbin/scutil --proxy | sed -n '1,/__SCOPED__/p'
./clrs stop
./clrs system-proxy status || true
```

Expected result: the effective HTTP and HTTPS proxy is
`127.0.0.1:7890`. `./clrs stop` must restore the previous settings and report
the Rash system proxy as off. Do not alter another proxy app's settings to
force this check; report an override if the user has left one running.

## TUN test

After the regular test passes, stop other route-owning VPN clients and run:

```zsh
./clrs start --config JP --tun
ifconfig utun1989
ALL_PROXY= HTTPS_PROXY= HTTP_PROXY= all_proxy= https_proxy= http_proxy= \
  curl --noproxy '*' --fail --silent --show-error --output /dev/null \
  --write-out 'TUN HTTP: %{http_code}\n' --max-time 20 \
  https://www.gstatic.com/generate_204
./clrs stop
```

Expected result: `utun1989` exists and the unconfigured curl request returns
`TUN HTTP: 204`. If `sudo` cannot be used interactively, report TUN as blocked
instead of bypassing the launcher.

## Report

Return only:

- Clash RS version
- JP and SG result codes
- Selector latency prompt and selected connection
- system proxy on/effective/restored result
- TUN pass/fail/blocked
- whether `./clrs stop` left the service stopped
- concise, redacted failure reasons
