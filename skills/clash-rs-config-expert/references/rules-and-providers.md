# Routing rules and remote providers

Read this reference for ordered routing, rule options, external rule sets, proxy subscriptions, and reference integrity.

## Contents

- [Rule evaluation](#rule-evaluation)
- [Supported rule types](#supported-rule-types)
- [Rule options and composite rules](#rule-options-and-composite-rules)
- [Rule ordering](#rule-ordering)
- [Proxy providers](#proxy-providers)
- [Rule providers](#rule-providers)
- [Provider formats](#provider-formats)
- [Validation and troubleshooting](#validation-and-troubleshooting)

## Rule evaluation

Treat `rules` as an ordered first-match list. Route a matching connection to the rule's final target and stop evaluating later rules.

Use the normal shape:

```yaml
rules:
  - DOMAIN,api.example.com,DIRECT
  - DOMAIN-SUFFIX,example.com,manual
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - MATCH,manual
```

Resolve final targets to a raw proxy, proxy group, or supported built-in action. Preserve exact case in names.

Use `MATCH`, not `FINAL`, for the catch-all in the reviewed parser.

## Supported rule types

| Rule type | Payload | Notes |
| --- | --- | --- |
| `DOMAIN` | exact hostname | Match only the exact name |
| `DOMAIN-SUFFIX` | domain suffix | Match the apex and subdomains |
| `DOMAIN-KEYWORD` | substring | Use sparingly because it can overmatch |
| `DOMAIN-REGEX` | regular expression | Validate syntax; keep expensive patterns late |
| `GEOSITE` | category | Require a configured geosite database |
| `GEOIP` | country/category code | Require a current GeoIP database |
| `IP-CIDR` | IPv4 or accepted network CIDR | Add `no-resolve` when domain resolution is unnecessary |
| `IP-CIDR6` | IPv6 CIDR | Parsed through the IP-CIDR implementation |
| `SRC-IP-CIDR` | source CIDR | Useful for gateways and LAN segmentation |
| `SRC-PORT` | one port | Match the source port |
| `DST-PORT` | one port | Match the destination port |
| `PROCESS-NAME` | process basename | Platform and permission sensitive |
| `PROCESS-PATH` | full process path | Platform and permission sensitive |
| `RULE-SET` | rule-provider name | Use the provider's configured behavior |
| `NETWORK` | `TCP`/`tcp` or `UDP`/`udp` | Match transport protocol |
| `AND` | parenthesized sub-rules | Require every sub-rule to match |
| `OR` | parenthesized sub-rules | Require any sub-rule to match |
| `NOT` | parenthesized sub-rule | Invert a match |
| `MATCH` | no payload | Catch all remaining traffic |

Do not import unsupported rule types from Mihomo or another Clash implementation without target validation.

## Rule options and composite rules

Append `no-resolve` only to `GEOIP`, `IP-CIDR`, `IP-CIDR6`, or `SRC-IP-CIDR`:

```yaml
rules:
  - GEOIP,CN,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
```

Append `interface=<name>` to bind a rule's outbound interface in current source:

```yaml
rules:
  - DOMAIN,internal.example.com,DIRECT,interface=en0
```

Verify runtime behavior on the target platform; an accepted interface name may still be unavailable.

Use composite syntax with commas protected by parentheses:

```yaml
rules:
  - AND,((DOMAIN,example.com),(NETWORK,tcp)),manual
  - OR,((DOMAIN-SUFFIX,example.net),(DOMAIN-SUFFIX,example.org)),manual
  - NOT,((GEOIP,CN)),manual
```

Keep composites shallow and readable. Prefer multiple ordinary rules when they express the same behavior.

## Rule ordering

Order from most specific and cheapest to broadest:

1. Localhost, private network, and explicit safety bypasses.
2. Exact domain, process, source, or narrow CIDR rules.
3. Rule-provider and domain-suffix rules.
4. Broader keyword, regex, geosite, and GeoIP rules as appropriate.
5. One final `MATCH,<target>` rule.

Adjust this heuristic when a broader policy intentionally overrides a specific route. Explain the exception.

Avoid common failures:

- Putting `MATCH` before later rules.
- Placing a broad suffix or keyword before a required exception.
- Sending local or proxy-server traffic back into the same proxy path.
- Using a rule target that differs only by capitalization.
- Adding `no-resolve` to a rule type that rejects it.
- Relying on process rules without platform support or permission.

## Proxy providers

Use `proxy-providers` to load proxy lists and reference them from group `use` fields.

HTTP provider:

```yaml
proxy-providers:
  subscription:
    type: http
    url: "https://provider.example.com/proxies.yaml"
    interval: 86400
    path: ./providers/subscription.yaml
    health-check:
      enable: true
      url: "https://www.gstatic.com/generate_204"
      interval: 300
      lazy: true
```

File provider:

```yaml
proxy-providers:
  local-nodes:
    type: file
    path: ./providers/local.yaml
    interval: 0
    health-check:
      enable: true
      url: "https://www.gstatic.com/generate_204"
      interval: 300
      lazy: true
```

Format the provider payload with a top-level `proxies` list:

```yaml
proxies:
  - name: "node-a"
    type: ss
    server: proxy.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "replace-with-secret"
```

The reviewed provider schema requires `url`, `interval`, `path`, and `health-check` for HTTP; file providers require `path`, optional `interval`, and `health-check`. The reviewed health check accepts `enable`, `url`, `interval`, and optional `lazy`.

Do not include `timeout` unless matching version documentation or source confirms its runtime meaning. Parser acceptance alone is insufficient.

## Rule providers

Use one of the current provider types.

### HTTP

```yaml
rule-providers:
  blocked-domains:
    type: http
    behavior: domain
    format: yaml
    url: "https://rules.example.com/blocked.yaml"
    interval: 86400
    path: ./rules/blocked.yaml
```

Use `url`, `behavior`, optional `interval`, optional cache `path`, and optional `format`. The reviewed source derives a cache path from the URL when `path` is absent.

### File

```yaml
rule-providers:
  local-routes:
    type: file
    behavior: classical
    format: yaml
    path: ./rules/local.yaml
```

Use `path`, `behavior`, optional `interval`, and optional `format`. Current source watches local files and treats polling as a fallback.

### Inline

```yaml
rule-providers:
  private-domains:
    type: inline
    behavior: domain
    payload:
      - internal.example.com
      - service.example.net
```

Use `payload` as the compatibility alias for `inline-rules`. Keep the provider name in the map key.

Reference any rule provider from the ordered rule list:

```yaml
rules:
  - RULE-SET,blocked-domains,REJECT
  - RULE-SET,private-domains,DIRECT
  - RULE-SET,local-routes,manual
  - MATCH,manual
```

## Provider formats

Select one behavior:

| Behavior | Entries |
| --- | --- |
| `domain` | Domain names or supported domain-set patterns |
| `ipcidr` | IPv4/IPv6 CIDRs |
| `classical` | Rule lines without the final target, such as `DOMAIN-SUFFIX,example.com` |

Select one format:

- `yaml` (default): use a top-level `payload` list.
- `text`: use newline-delimited entries appropriate to the behavior.
- `mrs`: use the compiled rule-set format; do not pair it with `classical` behavior in the reviewed source.

Examples:

```yaml
# domain behavior
payload:
  - example.com
  - sub.example.net
```

```yaml
# ipcidr behavior
payload:
  - 10.0.0.0/8
  - 2001:db8::/32
```

```yaml
# classical behavior
payload:
  - DOMAIN-SUFFIX,example.com
  - IP-CIDR,192.168.0.0/16
  - DST-PORT,443
```

Do not include a proxy target inside classical provider entries; apply the target in `RULE-SET,<provider>,<target>`.

## Validation and troubleshooting

Check provider configurations in this order:

1. Run strict parser validation on the main configuration.
2. Resolve each provider name from every `use` and `RULE-SET` reference.
3. Resolve every cache path from the runtime working directory.
4. Fetch HTTP URLs independently and confirm HTTPS, status, authentication, and content type.
5. Parse provider contents according to `format` and `behavior`.
6. Confirm proxy names inside provider files are unique and supported by the build.
7. Confirm health-check URLs are reachable through the intended proxies.
8. Inspect debug logs for update, parse, cache, and health-check failures.

Treat remote provider content as trusted configuration input. Use HTTPS, protect credentials in URLs, review provider ownership, and keep local cache permissions restrictive.
