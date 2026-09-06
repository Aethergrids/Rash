# DNS configuration

Read this reference for the Clash RS DNS client/server, fake-IP routing, and upstream selection.

## Contents

- [Configuration fields](#configuration-fields)
- [Local DNS listeners](#local-dns-listeners)
- [Upstream resolvers](#upstream-resolvers)
- [Resolution modes](#resolution-modes)
- [Policies, fallback, and hosts](#policies-fallback-and-hosts)
- [Baseline example](#baseline-example)
- [Troubleshooting](#troubleshooting)

## Configuration fields

Use only fields supported by the target version.

| Key | Shape | Purpose |
| --- | --- | --- |
| `enable` | boolean | Enable Clash RS DNS processing |
| `listen` | address string or protocol map | Start local DNS listeners; omission disables the local server in the reviewed source |
| `ipv6` | boolean | Return empty AAAA answers when false |
| `use-hosts` | boolean | Consult the top-level `hosts` map |
| `nameserver` | string list | Configure primary upstream resolvers |
| `fallback` | string list | Configure fallback upstream resolvers |
| `fallback-filter` | mapping | Choose when fallback answers apply |
| `default-nameserver` | IP-address list | Bootstrap resolver hostnames, especially DoH names |
| `proxy-server-nameserver` | string list | Resolve outbound proxy server hostnames separately |
| `nameserver-policy` | pattern-to-resolver map | Route matching domain queries to a specific resolver |
| `enhanced-mode` | `normal`, `fake-ip`, or `redir-host` | Select DNS/routing integration |
| `fake-ip-range` | IPv4 CIDR | Allocate synthetic addresses in fake-IP mode |
| `fake-ip-filter` | domain-pattern list | Force selected names to return real addresses |
| `edns-client-subnet` | mapping | Send optional IPv4/IPv6 ECS prefixes upstream |
| `respect-rules` | boolean | Route normal upstream DNS traffic through the rule engine in current builds |

Set both `enable: true` and `listen` when clients must query the local Clash RS DNS server.

## Local DNS listeners

Use the string form for a UDP-only listener:

```yaml
dns:
  enable: true
  listen: 127.0.0.1:53553
```

Use the map form for multiple protocols:

```yaml
dns:
  enable: true
  listen:
    udp: 127.0.0.1:53553
    tcp: 127.0.0.1:53553
    dot:
      addr: 127.0.0.1:53554
      ca-cert: ./certs/dns.crt
      ca-key: ./certs/dns.key
    doh:
      addr: 127.0.0.1:53555
      hostname: dns.example.com
      ca-cert: ./certs/dns.crt
      ca-key: ./certs/dns.key
```

Current source also defines `doh3` with the DoH field shape. Verify it against the target build before use.

Apply these checks:

- Bind to loopback unless LAN DNS service is explicitly required.
- Protect non-loopback DNS listeners with firewall rules.
- Provide readable certificate and private-key paths for encrypted listeners.
- Do not add `hostname` under `dot`; the reviewed strict schema exposes it for DoH/DoH3, not DoT.
- Resolve certificate paths from the runtime working directory.

## Upstream resolvers

Use these documented endpoint forms:

```yaml
dns:
  default-nameserver:
    - 1.1.1.1
    - 8.8.8.8
  nameserver:
    - 1.1.1.1
    - tcp://8.8.8.8:53
    - tls://1.1.1.1:853
    - https://1.1.1.1/dns-query
```

Apply these constraints:

- Put IP addresses only in `default-nameserver`; use them to bootstrap resolver hostnames.
- Use `proxy-server-nameserver` to avoid circular dependency when an outbound server is named by domain.
- Use trusted resolvers appropriate to the user's jurisdiction and network.
- Treat `dhcp://<interface>` as version- and platform-sensitive; validate it with the target build.
- Expect primary resolvers to be queried concurrently and the first usable result to win, as described by the manual.
- Set `respect-rules: true` only after proving that DNS routing cannot recurse through an unresolved proxy endpoint. It does not affect `default-nameserver` or `proxy-server-nameserver` in the reviewed source.

## Resolution modes

### Fake-IP

Use fake-IP to preserve domain identity for routing after an application receives a synthetic address:

```yaml
dns:
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.2/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "router.example"
```

- Keep the fake-IP range separate from LANs, VPNs, and other routed networks.
- Add only compatibility-sensitive domains to `fake-ip-filter`; broad filters reduce fake-IP benefits.
- Enable `profile.store-fake-ip` only when mappings should persist across restarts.

### Redir-host

Use real answers when applications or networks cannot tolerate fake addresses:

```yaml
dns:
  enhanced-mode: redir-host
```

### Normal

Use `normal` or omit `enhanced-mode` when enhanced routing integration is unnecessary. Validate actual defaults against the target version.

## Policies, fallback, and hosts

Route selected names to a specific upstream with scalar policy values:

```yaml
dns:
  nameserver-policy:
    "geosite:cn": "114.114.114.114"
    "+.internal.example.com": "10.0.0.53"
```

The reviewed source models each policy value as one string, not a list. Do not copy list-valued Mihomo policies without target validation.

Configure fallback filtering only when the selection behavior is understood:

```yaml
dns:
  fallback:
    - tls://8.8.8.8:853
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4
    domain:
      - "+.example.com"
```

Use host overrides through the top-level map:

```yaml
hosts:
  "router.local": 192.168.1.1

dns:
  use-hosts: true
```

Do not use public host overrides for private services unless their lifecycle and ownership are clear.

## Baseline example

Start from this shape and replace resolvers or filters for the user's environment:

```yaml
dns:
  enable: true
  listen: 127.0.0.1:53553
  ipv6: false
  use-hosts: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.2/16
  default-nameserver:
    - 1.1.1.1
    - 8.8.8.8
  proxy-server-nameserver:
    - 1.1.1.1
  nameserver:
    - tls://1.1.1.1:853
    - tls://8.8.8.8:853
  fallback: []
  fake-ip-filter:
    - "*.lan"
    - "*.local"
```

Do not present these public resolvers as universally optimal; adapt them to the user's location, privacy requirements, and reachability.

## Troubleshooting

Diagnose in this order:

1. Confirm strict parser acceptance.
2. Confirm the DNS listener is actually bound.
3. Query the listener directly over the configured protocol.
4. Test each upstream from the Clash RS host without the proxy.
5. Confirm bootstrap resolution for any DoH/DoT hostname.
6. Inspect the fake-IP range for overlap with local networks.
7. Add one failing domain to `fake-ip-filter` only to prove a compatibility issue.
8. Check `nameserver-policy`, fallback filters, and routing rules for unintended capture.
9. Enable `log-level: debug` temporarily and remove it after diagnosis.

Distinguish failure classes: listener binding, upstream reachability, TLS verification, policy mismatch, fake-IP incompatibility, route recursion, and application DNS bypass.
