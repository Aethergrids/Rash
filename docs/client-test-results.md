# Rash client integration checks

Date: 2026-09-06. Host: macOS arm64, tested directly from Switzerland.
Clients: Clash RS 0.10.8 and Homebrew sing-box 1.14.0 with `with_clash_api`.
Private SG profiles and raw logs remain local and ignored.

| Check | Clash RS | sing-box |
| --- | --- | --- |
| Native config validation | `--test-config --strict-config` passed | `check` passed |
| Start/status/client identification/stop | Passed | Passed |
| Controller, configs, proxies, rules, connections, provider APIs | HTTP 200 | HTTP 200 |
| Yacd entry | HTTP 200 | HTTP 200 |
| HTTP and SOCKS5 to the public 204 endpoint | Both 204 | Both 204 |
| Local DNS query on port 1053 | Fake-IP answer | Fake-IP answer |
| Interactive latency and node selection | Passed | Passed |
| Selector persistence across restart | Passed after cache flush | Passed |
| Rule/Global/Direct API controls | Passed | Passed |
| Yacd overview/proxies/rules/connections/settings pages | Rendered, no browser errors | Rendered, no browser errors |
| tmux attach/detach | Passed | Passed |
| macOS system proxy effective state and exact restoration on stop | Passed | Passed |

The proxy checks used the selected IPv4 Hysteria2 connection. They do not
establish reachability for every node or verify every private routing rule.
The native SG profile's outbound references and endpoint/credential mapping
were checked without printing sensitive values.

Clash RS 0.10.8 writes its selection cache every 10 seconds. An immediate stop
after selection did not preserve the change; allowing the flush interval did.
This existing core behavior is documented in the README and smoke-test guide.

Additional checks passed:

- Shell syntax and isolated `tests/clients.zsh` regression suite.
- Default Clash dispatch, sing-box check/run arguments, and separate runtime
  paths. sing-box startup does not require the Clash executable or MMDB.
- Source profiles remain unchanged; runtime rendering removes TUN-capable
  source listeners/endpoints/services and uses a loopback controller.
- Missing Homebrew fails before bootstrap work. Simulated macOS/Linux formula
  install, reuse, force reinstall, and missing Clash API capability handling.
- Real full asset bootstrap, reusing the installed Homebrew formula and
  verified Clash/Yacd/GeoIP assets. Native sing-box starter config validation.
- Shared environment set/unset, proxy execution, log capture, and UI opener
  dispatch. `rash` resolves through the updated local command symlink.
- Private profile/runtime ignore rules and restrictive runtime permissions.

Linux OS branches were exercised with isolated command stubs. No native Linux
network session was tested. Linux system-proxy commands are explicitly
unsupported; `env`, `exec`, and explicit HTTP/SOCKS5 proxy settings are available.

Both clients were stopped after testing, and prior macOS proxy settings were
restored. No private profile, subscription, secret, or raw runtime log is
included in this change.
