# Configuration migration instructions

This directory is the local inbox for existing Clash, Clash Verge Rev, or
Mihomo profile YAML files. Those inputs may contain credentials and must stay
untracked.

When a user places a profile here and asks for a Clash RS version:

1. Read `../skills/clash-rs-config-expert/SKILL.md` completely, then read only
   the linked references needed for the supplied profile.
2. Use `config.template` as the safe Clash RS baseline. Preserve the user's
   proxy endpoints, credentials, comments, ordering, unrelated behavior, and
   intent. Never invent missing secrets or replace real values with redaction
   text inside the local output.
3. Convert only fields that the target Clash RS release does not support.
   Check group members, providers, rule targets, duplicates, and cycles.
4. Keep the LinkedIn rules before broad CN rules: both `linkedin.com` and
   `linkedin.cn` must use `Proxy`. Routing is not an HTTP redirect, so do not
   fake a redirect with DNS host rewriting.
5. Write the result to `../configs/<PROFILE>/config.yaml`, with a short,
   uppercase profile name; the launcher currently accepts `SG`. Do not alter
   the input file. Omit `tun` from the output: Rash supports regular proxy
   access only and does not manage routes or hijack system DNS.
6. Validate against this project's binary:

   ```zsh
   ../bin/clash --directory ../configs/<PROFILE> \
     --config ../configs/<PROFILE>/config.yaml \
     --test-config --strict-config
   ```

7. Report schema validation separately from live connectivity.

For sing-box, follow `../docs/sing-box-config.md` and use `sing-box.template`.
Write native JSON to `../configs/<PROFILE>/sing-box.json` and validate with
`sing-box check`. Preserve routing intent and credentials locally; report
any behavior that cannot be represented instead of silently dropping it.

Never commit or force-add any `.yaml`, `.yml`, or `.json` profile below `templates/` or
`configs/`. Do not print credentials in command output, patches, diffs, commit
messages, pull requests, or agent responses.
