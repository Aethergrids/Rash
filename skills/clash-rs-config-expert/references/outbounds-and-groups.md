# Outbound proxies and proxy groups

Read this reference to select exact Clash RS outbound schemas, transport options, compile-time features, and group behavior.

## Contents

- [Common structure](#common-structure)
- [Protocol matrix](#protocol-matrix)
- [Protocol details](#protocol-details)
- [Transport and TLS rules](#transport-and-tls-rules)
- [Proxy groups](#proxy-groups)
- [Reference checks](#reference-checks)
- [Security checks](#security-checks)

## Common structure

Define raw outbounds under `proxies`:

```yaml
proxies:
  - name: "node-a"
    type: ss
    server: proxy.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "replace-with-secret"
    udp: true
```

Most network outbounds share `name`, `server`, and `port`. Many also support `connect-via` (alias `dialer-proxy`) to dial through an existing raw proxy or group. Do not point `connect-via` directly at an item inside a proxy provider.

Keep exact `type` names. In particular, use `ss`, not `shadowsocks`, for a Shadowsocks outbound.

## Protocol matrix

The fields below match the reviewed source snapshot. Re-check feature availability and strict validation on the target binary.

| `type` | Required protocol fields beyond common fields | Important optional fields | Build note |
| --- | --- | --- | --- |
| `direct` | `name` only | none | Built in |
| `reject` | `name` only | none | Built in |
| `ss` | `cipher`, `password` | `udp`, `plugin`, `plugin-opts` | Requires `shadowsocks` feature |
| `socks5` | none | `username`, `password`, `tls`, `sni`, `skip-cert-verify`, `udp` | Standard build |
| `anytls` | `password` | `alpn`, `sni`, `udp`, mTLS fields | Verify build/version |
| `trojan` | `password` | `alpn`, `sni`, `udp`, `network`, WebSocket/gRPC options, mTLS fields | Standard build |
| `vmess` | `uuid`, `alterId` | `cipher`, `udp`, `tls`, `server-name`, `network`, transport options, mTLS fields | Standard build |
| `vless` | `uuid` | `udp`, `tls`, `server-name`, `network`, transport options, Reality, `flow`, fingerprint, mTLS fields | Standard build |
| `wireguard` | `private-key`, `public-key`, `ip` | pre-shared key, IPv6, DNS, allowed IPs, MTU, reserved bits | Requires `wireguard` feature |
| `hysteria2` | `name`, `server`, `port`, `password` | port hopping, bandwidth, obfuscation, TLS, MTU, certificate pinning | Standard current build |
| `tuic` | `uuid`, `password` | QUIC, relay, congestion, SNI, TLS, window, timeout fields | Requires `tuic` feature |
| `shadowquic` | `password`, `username`, `server-name` | ALPN, MTU, congestion, 0-RTT, stream mode, GSO | Requires `shadowquic` feature |
| `ssh` | `username` | password or private key, passphrase, host keys, TOTP | Requires `ssh` feature |
| `tor` | `name` only | none | Requires `onion`; commonly a plus build |
| `tailscale` | `name` | state directory, auth key, hostname, control URL, client name, ephemeral | Requires `tailscale` feature |

Do not generate a bare `type: http` outbound. HTTP is an inbound protocol, but the reviewed Clash RS outbound enum does not implement it.

## Protocol details

### Direct, reject, and built-ins

Use the built-in names `DIRECT` and `REJECT` in groups and rules. The manual also documents `PASS` for transparent pass-through; confirm its behavior on the target version before relying on it.

Define named direct or reject entries only when a stable custom name is useful:

```yaml
proxies:
  - name: "direct-via-rule"
    type: direct
  - name: "blocked"
    type: reject
```

### Shadowsocks

Use a cipher supported by both ends. The manual lists:

- `aes-128-gcm`, `aes-192-gcm`, `aes-256-gcm`
- `chacha20-ietf-poly1305`, `xchacha20-ietf-poly1305`
- `2022-blake3-aes-128-gcm`, `2022-blake3-aes-256-gcm`, `2022-blake3-chacha20-poly1305`

Configure plugin fields only when the target server requires the same plugin and options.

### AnyTLS

Use a minimal secure shape:

```yaml
proxies:
  - name: "anytls-node"
    type: anytls
    server: proxy.example.com
    port: 443
    password: "replace-with-secret"
    sni: proxy.example.com
    skip-cert-verify: false
```

The reviewed parser accepts `fingerprint`, `client-fingerprint`, `idle-session-check-interval`, `idle-session-timeout`, and `min-idle-session`, but the reviewed runtime marks them as not applied. Do not claim that they change behavior.

Set both `tls-cert` and `tls-key` when using mTLS; each accepts a path or inline PEM.

### VMess, VLess, and Trojan transports

Use documented transport values and matching option maps:

- `network: ws` with `ws-opts.path`, `headers`, and optional early-data fields.
- `network: grpc` with `grpc-opts.grpc-service-name`.
- `network: h2` with `h2-opts.host` and `h2-opts.path` where the protocol supports H2.

VMess accepts `alterId` as a compatibility alias and `alter-id` as the kebab-case form. Preserve the user's working spelling; prefer the documented `alterId` when matching imported profiles.

Use VLess Reality only with server-provided values:

```yaml
proxies:
  - name: "vless-reality"
    type: vless
    server: proxy.example.com
    port: 443
    uuid: "replace-with-uuid"
    tls: true
    server-name: cover.example.com
    client-fingerprint: chrome
    flow: xtls-rprx-vision
    reality-opts:
      public-key: "replace-with-public-key"
      short-id: "replace-with-short-id"
```

Do not invent SNI, Reality public keys, short IDs, service names, paths, or host headers.

### Hysteria2

Use current field names rather than adding generic Clash options:

```yaml
proxies:
  - name: "hy2-node"
    type: hysteria2
    server: proxy.example.com
    port: 443
    password: "replace-with-secret"
    sni: proxy.example.com
    skip-cert-verify: false
    obfs: salamander
    obfs-password: "replace-with-obfs-secret"
```

Current optional fields include `ports`, `alpn`, `up`, `down`, `cwnd`, `ca`, `ca-str`, SHA-256 certificate `fingerprint`, `udp-mtu`, and `disable-mtu-discovery`. The reviewed strict struct does not define a generic `udp` key for Hysteria2.

### TUIC

Use server-provided `uuid` and password. Current options include `ip`, `heartbeat-interval`, `alpn`, `disable-sni`, `reduce-rtt`, `request-timeout`, `udp-relay-mode`, `congestion-controller`, `max-udp-relay-packet-size`, `fast-open`, `skip-cert-verify`, `max-open-stream`, `sni`, garbage-collection intervals, send/receive windows, and mTLS fields.

The reviewed strict struct does not define a generic `udp` key for TUIC.

### ShadowQUIC

Require matching JLS credentials and server name. Keep `initial-mtu` at least 1200 and no smaller than `min-mtu`. Validate congestion values (`bbr`, `new-reno`, or `cubic`) and use 0-RTT only when replay risk is acceptable.

### WireGuard

Protect `private-key`. Use server-provided `public-key`, optional `pre-shared-key`, client `ip`, optional `ipv6`, `allowed-ips`, `dns`, `remote-dns-resolve`, `reserved-bits`, and `mtu`. Check that allowed routes do not create a loop with Clash RS itself.

### SSH

Use either `password` or `private-key` plus optional `private-key-passphrase`. Pin `host-key` when possible. Do not disable host verification by omission without explaining the trust model.

### Tailscale and Tor

Confirm the binary includes the required feature. Persist Tailscale state in a protected directory unless the node is intentionally ephemeral. Treat Tailscale auth keys as secrets. Tor requires no server address or credentials in the manual's outbound shape.

## Transport and TLS rules

- Keep `skip-cert-verify: false` by default.
- Use the server's authenticated name in `sni` or `server-name`; do not assume the dial hostname is correct.
- Supply both halves of any client certificate/key pair.
- Treat Hysteria2 `fingerprint` as a certificate SHA-256 digest, not a browser fingerprint name.
- Do not claim AnyTLS browser fingerprint fields take effect in the reviewed runtime.
- Configure `udp` only on protocol structs that expose it; generic compatibility fields can be ignored normally and rejected strictly.
- Use `connect-via` for intentional chaining only and check the graph for loops.

## Proxy groups

Use direct `proxies` and/or provider names in `use`.

| Group type | Required fields | Optional fields |
| --- | --- | --- |
| `select` | `name` | `proxies`, `use`, `udp`, `url`, `icon` |
| `url-test` | `name`, `url`, `interval` | `proxies`, `use`, `lazy`, `tolerance`, `icon` |
| `fallback` | `name`, `url`, `interval` | `proxies`, `use`, `lazy`, `icon` |
| `load-balance` | `name`, `url`, `interval` | `proxies`, `use`, `lazy`, `strategy`, `icon` |
| `relay` | `name` | `proxies`, `use`, `url`, `icon` |
| `smart` | `name` | `proxies`, `use`, `udp`, `lazy`, `url`, `icon`, scoring controls |

Use load-balance strategies `consistent-hashing` (reviewed default), `round-robin`, or `sticky-session`.

Use smart-group controls only when requested:

- `max-retries`
- `site-stickiness` from `0.0` to `1.0`
- `bandwidth-weight`, where `0.0` disables bandwidth influence

Example:

```yaml
proxy-groups:
  - name: "manual"
    type: select
    proxies:
      - "node-a"
      - "auto"
      - DIRECT

  - name: "auto"
    type: url-test
    use:
      - "subscription"
    url: "https://www.gstatic.com/generate_204"
    interval: 300
    lazy: true
    tolerance: 50
```

Do not add `timeout` to a group unless matching version documentation or source confirms its runtime meaning; the reviewed group structs do not expose that field, and parser acceptance alone is insufficient.

## Reference checks

- Require every proxy and group name to be unique.
- Resolve each `proxies` item to a raw proxy, earlier or later acyclic group, or supported built-in.
- Resolve each `use` item to a proxy-provider key.
- Reject direct or indirect group cycles.
- Ensure a relay chain has a deliberate order and no path back to itself.
- Ensure rule targets use exact case-sensitive names.
- Keep health-check URLs reachable through the intended topology.

## Security checks

- Redact passwords, UUIDs, private keys, auth keys, and certificate private keys in explanations.
- Reject `skip-cert-verify: true` for production unless the user explicitly accepts interception risk.
- Prefer HTTPS health-check and provider URLs when the environment supports them.
- Verify SSH host keys and TLS server names.
- Avoid 0-RTT for sensitive replayable operations unless the protocol and server mitigate the risk.
- Confirm imported subscriptions are trusted before loading executable routing intent from them.
