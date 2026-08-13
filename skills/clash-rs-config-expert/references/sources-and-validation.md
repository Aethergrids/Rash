# Sources and validation

Use this reference to resolve documentation conflicts and verify a configuration against the target Clash RS build.

## Source priority

Apply evidence in this order:

1. The exact installed binary with `--test-config --strict-config`.
2. Source code or generated configuration reference from the same version or commit.
3. The official Clash RS user manual for concepts and examples.
4. Other Clash-family documentation only as migration input, never as proof of Clash RS support.

The user manual states that it contains AI-generated content and may not be fully accurate. Preserve useful patterns from it, but let matching source, strict parsing, and observed target behavior override conflicting examples.

## Official sources

- [Configuration index](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration)
- [Documentation index for agents](https://watfaq.gitbook.io/clashrs-user-manual/llms.txt)
- [General configuration](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration/general-configs.md)
- [Outbound proxies](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration/outbounds.md)
- [Traffic routing rules](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration/rules.md)
- [TUN configuration](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration/tun.md)
- [Remote content](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration/remote-content.md)
- [DNS configuration](https://watfaq.gitbook.io/clashrs-user-manual/using-it/configuration/dns.md)
- [Generated Rust configuration reference](https://watfaq.github.io/clash-rs/clash_doc/)
- [Official repository](https://github.com/Watfaq/clash-rs)
- [Current configuration definitions](https://github.com/Watfaq/clash-rs/blob/master/clash-lib/src/config/def.rs)
- [Current proxy and group definitions](https://github.com/Watfaq/clash-rs/blob/master/clash-lib/src/config/internal/proxy.rs)
- [Current routing rule parser](https://github.com/Watfaq/clash-rs/blob/master/clash-lib/src/config/internal/rule.rs)
- [Current listener definitions](https://github.com/Watfaq/clash-rs/blob/master/clash-lib/src/config/internal/listener.rs)

The local reference tables were reconciled on 2026-08-11 against repository commit `b0538e86aedcbe7f000bb9f00889175ffb85176c` from 2026-08-05. Re-check the installed version when working with a different build.

## Validate in layers

### 1. Identify the target

```bash
clash-rs --version
clash-rs --help
```

Inspect `--help` instead of assuming newer flags exist. Substitute the actual executable name when a distribution installs Clash RS as `clash`.

### 2. Validate YAML and the strict schema

```bash
clash-rs --directory /absolute/working-directory \
  --config /absolute/path/config.yaml \
  --test-config --strict-config
```

Use `--directory` for the same base directory used in production. It affects relative provider caches, databases, dashboards, certificates, and other file paths.

If the build lacks strict mode:

```bash
clash-rs --directory /absolute/working-directory \
  --config /absolute/path/config.yaml \
  --test-config
```

Report the limitation. A normal parse intentionally ignores unknown fields for compatibility, so a misspelled or unsupported option can otherwise appear successful.

Treat strict success as a strong syntax/schema check, not proof that every nested compatibility field is applied. Compare version-sensitive fields with matching source or demonstrate their runtime effect.

### 3. Check semantic references

Confirm all of the following independently of parser success:

- Every name is unique within its namespace.
- Every `proxy-groups[].proxies[]` item resolves to a proxy, another acyclic group, or a documented built-in.
- Every `proxy-groups[].use[]` item resolves to a proxy provider.
- Every `RULE-SET` name resolves to a rule provider.
- Every rule target resolves to a proxy, group, or built-in action.
- Every file path exists relative to the runtime working directory or is expected to be downloaded there.
- Every feature-gated protocol exists in the target build.

### 4. Test runtime behavior

After parser validation, test only the paths relevant to the request:

- Confirm listeners bind to the intended addresses and ports.
- Confirm DNS returns expected real or fake answers.
- Confirm representative destinations hit the intended rules.
- Confirm health checks can reach their URLs.
- Confirm TUN routes do not capture the proxy's own outbound connection.
- Confirm controller authentication before any non-loopback exposure.

Do not claim connectivity from a parser-only test.

## Known version-sensitive conflicts

Treat these as warnings tied to the reviewed commit, not timeless guarantees:

- HTTP is a supported inbound, but bare `type: http` is not a supported outbound protocol.
- Current proxy-provider health checks define `enable`, `url`, `interval`, and optional `lazy`; some manual examples show an additional `timeout`.
- Current `url-test` group definitions do not include a `timeout` key, although a manual example shows one. A local Clash RS 0.10.8 strict test accepted that key, demonstrating that parser acceptance can still mean silent non-application.
- The top-level `interface` key is parsed but marked not implemented in the reviewed source.
- A TUN `dns-hijack` list is parsed, but the reviewed implementation documents the list as having the same all-port-53 effect as `true`.
- `dns.enable: true` without `dns.listen` does not start the local DNS server in the reviewed source.
- Some protocols and listeners are compile-time features; documentation coverage does not prove the target binary includes them.

When a manual example fails validation or contains fields absent from the matching schema, reduce it to documented current fields. Do not disable strict mode or rely on mere parser acceptance to hide the conflict.
