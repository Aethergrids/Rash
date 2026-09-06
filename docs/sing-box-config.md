# Native sing-box profiles

Rash accepts `configs/SG/sing-box.json` when started with `--client sing-box`.
Use `templates/sing-box.template` as a credential-free starting point. Its
`Proxy` selector initially contains only `DIRECT`; add your native outbounds
and selector members locally before using a remote proxy.

Rash supplies the mixed listener on `127.0.0.1:7890`, DNS listener on
`127.0.0.1:1053`, authenticated Clash API, vendored Yacd path, and persistent
cache. All source inbounds, endpoints, services, and V2Ray API settings are
removed from the runtime copy. The source file is unchanged. Do not depend on
custom inbound tags or additional listeners in a Rash profile.

The profile supplies DNS servers, outbound definitions, selectors, and routing
rules. Keep these as sing-box's native JSON schema:

1. Copy protocol settings and credentials from the source without printing
   them. Use native `outbounds`, `tls`, and transport fields. Do not paste
   Clash `proxies`, `proxy-groups`, or `rules` strings into JSON.
2. Check unique outbound tags and all selector members, rule targets, DNS
   server references, rule-set tags, and dependency cycles. Every reference
   must resolve. Preserve rule order, especially the LinkedIn rules before
   broad country rules.
3. Preserve the template's `clash_mode` routing rules so Yacd's Rule, Global,
   and Direct controls take effect. The default `Proxy` selector determines
   the Global route. The launcher stores each client's selection separately.
4. Use native DNS server objects and native rule sets where required. Clash
   MMDB/GeoIP, fake-IP, and nameserver-policy settings need explicit mapping;
   they cannot be copied directly. Pin external rule-set sources when possible.
   Confirm DNS behavior separately from HTTP/SOCKS5 connectivity.
5. Validate with the executable that will run the profile:

   ```zsh
   sing-box check --directory "$PWD/configs/SG" \
     --config "$PWD/configs/SG/sing-box.json"
   ./rash start --config SG --client sing-box
   ```

   Rash checks the rendered runtime file again before starting tmux. Check
   controller/UI responses, both proxy protocols, DNS, selector persistence,
   and shutdown as described in `HANDOFF.md`. Config checks do not verify
   credentials, remote availability, or rule-set downloads at startup.

The shared UI uses sing-box's Clash API. Its core-specific settings are
limited to what that API implements; use the native profile for other
sing-box options. TUN is not supported by Rash with either client.

References: [configuration](https://sing-box.sagernet.org/configuration/),
[Clash API](https://sing-box.sagernet.org/configuration/experimental/clash-api/),
[cache](https://sing-box.sagernet.org/configuration/experimental/cache-file/),
[rule sets](https://sing-box.sagernet.org/configuration/rule-set/).
