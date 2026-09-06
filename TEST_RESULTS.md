# Local connection and TUN retest — 2026-09-06

SG works in regular proxy mode with Hysteria2 over IPv4. Following this
investigation, TUN was removed from Rash on 2026-09-06 at the user's request.
The TUN results below are historical evidence, not supported usage instructions.

The launcher no longer has a TUN option, preset, privileged tmux session, or
TUN status/attachment path. Imported `tun` sections are removed when rendering
the runtime profile. The Yacd TUN settings card is removed by a reproducible,
checksum-verified local patch in the asset downloader. The project supports
regular HTTP/SOCKS5 proxy access and optional macOS system proxy settings.

Removal checks passed: an imported enabled TUN configuration was stripped
before starting the exact project binary, legacy TUN state was rejected,
and `--tun` was rejected as an unknown option. Browser regression checks
with the same backend metadata found one TUN card in the original bundle and
none in the patched bundle, with ordinary settings intact and no page errors.
The asset downloader passed both cached and forced-download paths, including
archive verification and the patched bundle checksum. SG strict validation,
shell and JavaScript syntax checks, skill validation, and normal proxy smoke
tests passed after the removal.

## Environment and configuration

- macOS on Apple Silicon, Switzerland; Shadowrocket disconnected.
- Project binary: Clash RS 0.10.8. The supported asset downloader completed
  successfully and found the pinned binary, dashboard, and GeoIP installed.
- SG outbound definitions now match the supplied subscription. Two IPv4
  endpoint addresses changed, and the subscription removed Hysteria2
  bandwidth overrides. Credentials were preserved locally.
- Hysteria2 IPv4 is first in the selector and is the saved active choice.
  Both IPv6 alternatives remain available for networks that can reach them.
- The existing 266 routing rules, including both LinkedIn exceptions,
  remain intact. Loopback listeners and local DNS behavior are preserved.
- JP's profile, original input, and identified historical runtime copies
  were deleted. Launcher help, accepted profile names, and examples use SG.
- Hysteria2 retains the supplied profile's existing `skip-cert-verify: true`;
  connectivity results do not establish server certificate verification.

## Validation and regular proxy tests

The final profile passes the exact project binary's strict validation:

```zsh
./bin/clash --directory "$PWD/configs/SG" \
  --config "$PWD/configs/SG/config.yaml" \
  --test-config --strict-config
zsh -n clrs scripts/*.zsh
```

The configuration graph passes duplicate-name, group-cycle, member/provider,
rule-target, final `MATCH`, and LinkedIn rule-order checks. All four outbound
definitions match the downloaded subscription.

| Check | Result |
| --- | --- |
| Start, status, restart, and saved selection | Pass |
| Interactive selector, accepting the default | Pass; Hysteria2 IPv4 retained |
| Authenticated controller and Yacd UI | Pass; UI HTTP 200 |
| Hysteria2 IPv4 via HTTP and SOCKS5 | gstatic 204, GitHub 200, Cloudflare 200 |
| Hysteria2 IPv4 exit location | SG |
| VLESS IPv4, forced HTTP/1.1 | All three sites pass |
| VLESS IPv4, HTTP/2 | Some requests fail with curl code 16; some pass |
| Both supplied IPv6 endpoints | Host routing fails with `EHOSTUNREACH` |
| macOS HTTP/HTTPS system proxy on and off | Enabled, then restored to disabled |
| `clrs exec` | gstatic HTTP 204 |
| Removed JP and TUN arguments | Rejected |

The IPv6 result applies to the supplied endpoints. A separate public IPv6
HTTPS request succeeded, so these tests do not establish a general absence
of IPv6 connectivity.

## TUN tests

Tests used the unchanged project binary, private configurations, a temporary
`utun1988` interface, separate local ports, and bounded process lifetimes.
No experimental binary was installed. TUN and fake-IP ranges did not overlap.

1. **Selected routes, MTU 1500 and 1280:** 36 of 36 HTTP/1.1 requests passed
   across DIRECT, VLESS IPv4, and Hysteria2 IPv4; each was tested through both
   the mixed listener and TUN against gstatic, GitHub, and Cloudflare.
   Fake-IP answers and the route through the test interface were verified.
2. **Full routing, multiple protocol selections:** DIRECT passed HTTP/1.1
   and HTTP/2. VLESS passed HTTP/1.1 but two of three TUN HTTP/2 requests
   failed. After selecting Hysteria2, requests through both the mixed
   listener and TUN timed out; DNS hijacking also failed in that run.
3. **Fresh Hysteria2 IPv4 process:** full routing, ordinary system DNS,
   HTTP/2 requests to gstatic and Cloudflare, SG exit location, and DNS
   hijacking succeeded. Adding a temporary route around TUN for the proxy
   endpoint did not change the successful result.
4. **Three independent Hysteria2 IPv4 restarts:** all three repeated those
   successful full-routing, HTTP/2, SG exit, and DNS-hijacking checks. Each
   run restored the original default route state before the next started.

The cause of the full-routing timeouts remains unconfirmed. These results
do not establish a routing loop or prove that selector changes caused the
failure. VLESS HTTP/2 errors also occur in regular proxy mode. Lowering MTU
was only tested with selected routes and HTTP/1.1, so it is not a demonstrated
fix for the full-routing failure.

The stable release inspected was [v0.10.8](https://github.com/Watfaq/clash-rs/releases/tag/v0.10.8).
The previously tested [system TCP stack proposal](https://github.com/Watfaq/clash-rs/pull/1491)
was still open and unmerged; it was not rerun in this investigation.

## Cleanup and privacy

Temporary TUN interfaces and endpoint bypass routes were removed. An extra
scoped default route left after testing was explicitly removed. Default
routes and DNS configuration were compared with the saved pre-test state.
The final regular-mode smoke test passed HTTP and SOCKS5 (204) and UI (200).
`clrs stop` left the service stopped and macOS HTTP/HTTPS/SOCKS proxies disabled.
Profiles, subscription inputs, and diagnostic logs remain local and ignored;
this report contains no endpoint addresses, credentials, or subscription URLs.
