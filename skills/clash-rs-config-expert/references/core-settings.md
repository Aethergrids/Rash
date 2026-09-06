# Core settings and listeners

Read this reference for top-level configuration, inbound exposure, controllers, databases, and profiles.

## Contents

- [Top-level map](#top-level-map)
- [Inbound shortcuts](#inbound-shortcuts)
- [Explicit listeners](#explicit-listeners)
- [Controller and file settings](#controller-and-file-settings)
- [Profiles and experimental settings](#profiles-and-experimental-settings)

## Top-level map

Use kebab-case keys.

| Key | Shape | Purpose and constraints |
| --- | --- | --- |
| `port` | port | HTTP inbound shortcut |
| `socks-port` | port | SOCKS5 inbound shortcut |
| `mixed-port` | port | Combined HTTP and SOCKS5 inbound shortcut |
| `redir-port` | port | Linux TCP redirect inbound; build-dependent |
| `tproxy-port` | port | Linux transparent proxy inbound; build-dependent |
| `authentication` | list of `user:pass` strings | Authentication for HTTP, SOCKS5, and mixed shortcuts |
| `allow-lan` | boolean | Allow non-local inbound clients; coordinate with `bind-address` |
| `bind-address` | address or `*` | Bind address for shortcut listeners |
| `mode` | `rule`, `global`, or `direct` | Select routing mode; default to `rule` |
| `log-level` | `trace`, `debug`, `info`, `warn`/`warning`, `error`, or `off`/`silent` | Control logging; prefer `info` or `warn` outside debugging |
| `dns` | mapping | Configure the optional DNS subsystem |
| `profile` | mapping | Persist selections, fake-IP mappings, and smart-group statistics |
| `proxies` | list | Define inline outbound proxies |
| `proxy-groups` | list | Define selection, testing, failover, balancing, relay, or smart groups |
| `rules` | ordered list | Route traffic in first-match order |
| `hosts` | domain-to-address map | Override host resolution when `dns.use-hosts` is enabled |
| `mmdb`, `asn-mmdb`, `geosite` | path | Point to GeoIP, ASN, and geosite databases |
| `*-download-url` | URL | Download the corresponding database when supported |
| `ipv6` | boolean | Control IPv6 capability; coordinate with `dns.ipv6` |
| `external-controller` | address | Expose the REST controller |
| `external-controller-ipc` | path | Configure controller IPC; platform aliases may differ |
| `external-ui` | path | Locate dashboard files relative to the working directory |
| `external-ui-url` | URL | Download a dashboard archive in current builds; verify target support |
| `secret` | string | Authenticate the external controller |
| `cors-allow-origins` | list of origins | Restrict browser origins allowed to call the controller |
| `interface` | string | Parsed but marked unimplemented in the reviewed source |
| `routing-mark` | integer | Mark Clash-originated traffic on Linux to support loop avoidance |
| `proxy-providers` | map | Load outbound lists from HTTP or files |
| `rule-providers` | map | Load or embed routing rule sets |
| `experimental` | mapping | Configure explicitly documented experimental behavior |
| `listeners` | list | Define named inbound listeners; take precedence over shortcuts |
| `inbound-providers` | map | Load listener definitions in current builds; verify target support |

Use integers for ports unless preserving a working string-valued port from an existing profile. Keep each bound port unique unless the protocol intentionally shares it.

## Inbound shortcuts

Use only the shortcuts required by the requested clients:

```yaml
port: 8888
socks-port: 8889
mixed-port: 8899
bind-address: 127.0.0.1
allow-lan: false
authentication:
  - "user:replace-with-a-secret"
```

Apply these constraints:

- Bind to loopback for local-only use.
- Set a non-loopback bind address only when LAN clients must connect.
- Do not rely on `allow-lan: false` to constrain TPROXY; the manual states that TPROXY accepts LAN traffic regardless.
- Use `redir-port` and `tproxy-port` only on Linux builds that include the corresponding features.
- Avoid enabling HTTP, SOCKS5, and mixed shortcuts simultaneously unless the user needs all three.

## Explicit listeners

Prefer `listeners` when different addresses, ports, or inbound protocols need independent names. Each entry uses:

```yaml
listeners:
  - name: "local-socks"
    type: socks
    listen: 127.0.0.1
    port: 1080
    allow-lan: false
    udp: true
```

Use common fields `name`, `type`, `listen`, `port`, optional `allow-lan`, and optional Linux `fw-mark`. Keep names unique.

| Type | Extra fields | Availability |
| --- | --- | --- |
| `http` | none | Standard build |
| `socks` | optional `udp` | Standard build |
| `mixed` | optional `udp` | Standard build |
| `tproxy` | optional `udp` | Linux and `tproxy` feature |
| `redir` | none | Linux and `redir` feature |
| `tunnel` | `network` list and `target` | Standard build |
| `shadowsocks` | `cipher`, `password`, optional `udp`, optional `users` | `shadowsocks` feature |
| `anytls` | `password`, optional certificate, key, users, and fallback | Verify target build |
| `hysteria2` | `password`, optional certificate, key, and users | Verify target build |

For `tunnel`, specify a fixed target:

```yaml
listeners:
  - name: "web-tunnel"
    type: tunnel
    listen: 127.0.0.1
    port: 9090
    network: [tcp]
    target: "example.com:443"
```

When both shortcuts and `listeners` appear, expect explicit listeners to take precedence. Avoid ambiguous duplication.

## Controller and file settings

Keep the controller private by default:

```yaml
external-controller: 127.0.0.1:9090
external-ui: ./dashboard
secret: "replace-with-a-long-random-secret"
cors-allow-origins:
  - "https://dashboard.example.com"
```

Apply these rules:

- Require `secret` before binding the controller beyond loopback.
- Restrict CORS to known origins; do not use a wildcard without an explicit requirement.
- Protect controller access with host firewall or network policy when exposed.
- Resolve `external-ui`, provider caches, databases, and certificate paths from the runtime working directory selected with `--directory`.
- Keep database download URLs on HTTPS and ensure their format matches the consuming key.

## Profiles and experimental settings

Use current profile fields as needed:

```yaml
profile:
  store-selected: true
  store-fake-ip: false
  store-smart-stats: true
```

- Use `store-selected` to remember manual group choices.
- Use `store-fake-ip` only when fake-IP persistence is desired.
- Use `store-smart-stats` with smart groups when persistence is desired.

The reviewed source defines these experimental fields:

```yaml
experimental:
  tcp-buffer-size: 65536
  ignore-resolve-fail: false
```

Do not copy unrelated experimental keys from other Clash implementations.
