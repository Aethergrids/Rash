---
name: clash-rs-config-expert
description: Create, review, migrate, validate, and troubleshoot Clash RS YAML configurations. Use when working with Clash RS config files, inbound listeners, DNS and fake-IP, outbound proxy protocols, proxy groups, routing rules, proxy or rule providers, external-controller settings, platform-specific configuration, Clash RS parser errors, or migration from Clash/Mihomo-compatible profiles.
---

# Clash RS Configuration Expert

Create the smallest secure configuration that satisfies the request. This project supports regular HTTP/SOCKS5 proxy access only. TUN, route management, and DNS hijacking have been removed; omit `tun` from migrated profiles and keep the launcher's runtime removal of imported `tun` sections. Treat the installed Clash RS binary as the final authority because configuration support changes by version and build features.

## Follow the workflow

1. Establish the target environment.
   - Identify the Clash RS version or binary, operating system, desired inbound mode, outbound protocol, DNS mode, and whether the user supplied an existing configuration.
   - Continue with clearly labeled assumptions when a non-critical fact is unavailable.
   - Never invent server addresses, credentials, UUIDs, keys, certificates, provider URLs, interface names, or controller secrets. Use conspicuous placeholders.
2. Load only the references needed for the task.
   - Read [core-settings.md](references/core-settings.md) for top-level settings, listeners, controllers, profiles, and databases.
   - Read [dns.md](references/dns.md) for DNS listeners, upstreams, fake-IP, policies, and fallback.
   - Read [outbounds-and-groups.md](references/outbounds-and-groups.md) for proxy protocols, transports, build features, and proxy groups.
   - Read [rules-and-providers.md](references/rules-and-providers.md) for routing rules, provider schemas, and reference integrity.
   - Read [sources-and-validation.md](references/sources-and-validation.md) whenever exact version support matters, documentation conflicts, or validation is possible.
3. Preserve the user's configuration.
   - Make surgical edits and retain unrelated keys, comments, ordering, anchors, and quoting.
   - Redact secrets in explanations and logs. Do not replace a real secret with a literal redaction inside the user's file unless requested.
   - Explain behavior before changing routing, LAN exposure, or certificate verification.
4. Check the configuration graph.
   - Require unique proxy, group, listener, and provider names.
   - Resolve every group member, provider in `use`, rule provider in `RULE-SET`, and rule target.
   - Reject self-references and cycles between proxy groups.
   - Keep specific rules before broad rules and finish rule mode with `MATCH,<target>`.
5. Validate with the target binary.

```bash
clash-rs --directory /absolute/working-directory \
  --config /absolute/path/config.yaml \
  --test-config --strict-config
```

   - Use the same binary or build that will run the configuration.
   - Include `--directory` when relative paths appear; Clash RS resolves configuration-relative resources from its working directory.
   - If `--strict-config` is unavailable, run `--test-config` and report that unknown fields may be ignored.
   - Treat strict success as necessary but not sufficient. Confirm version-sensitive nested fields in matching source or runtime behavior because some tagged configuration variants can still accept ignored keys.
   - If Clash RS is unavailable, check YAML syntax and references, but explicitly state that runtime support was not verified.
   - Iterate on the smallest failing section until validation succeeds.

## Apply these rules

- Use kebab-case configuration keys and exact protocol `type` values.
- Do not assume that a Clash or Mihomo option works in Clash RS.
- Treat compile-time protocol features as unavailable until the target build confirms them.
- Do not equate a successful non-strict parse with an applied option; the default parser can ignore unknown fields.
- Keep `skip-cert-verify: false` unless the user knowingly accepts the risk for a controlled test.
- Bind the external controller to loopback by default. Require authentication and network controls before exposing it.
- Enable `allow-lan` or TPROXY only when the requested topology needs them.
- Prefer explicit YAML over dense flow syntax when creating a new configuration.
- Quote names and string values that contain spaces, punctuation, emoji, boolean-like words, or numeric-looking text.

## Report the result

- Provide the complete changed section or file, not disconnected fragments that cannot be applied safely.
- List assumptions and placeholders immediately after the YAML.
- Report the exact validation command and outcome.
- Call out build-feature dependencies, platform restrictions, deprecated or ignored fields, certificate bypasses, exposed listeners, and unresolved references.
- Distinguish YAML validity, Clash RS parser validity, and live connectivity; do not claim one proves the others.
