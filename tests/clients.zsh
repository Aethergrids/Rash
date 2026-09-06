#!/bin/zsh
# Isolated behavior checks: no real profiles, network requests, or installations.
set -eu
setopt pipe_fail
root="${0:A:h:h}"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/rash-client-test.XXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root"/{scripts,configs/SG,assets/yacd-meta,assets/geoip,bin,mocks}
cp "$root/rash" "$test_root/rash"
cp "$root/scripts/"{rash-session.zsh,sing-box-runtime.yq,download-assets.zsh} "$test_root/scripts/"
cp "$root/templates/sing-box.template" "$test_root/configs/SG/sing-box.json"
print '<html></html>' > "$test_root/assets/yacd-meta/index.html"
print fixture > "$test_root/assets/geoip/Country.mmdb"
cat > "$test_root/configs/SG/config.yaml" <<'YAML'
mixed-port: 7890
secret: fixture-source-secret
tun:
  enable: true
proxies: []
proxy-groups: []
rules: ["MATCH,DIRECT"]
YAML
cat > "$test_root/mocks/core" <<'MOCK'
#!/bin/zsh
print -rl -- "$@" > "$TEST_ARGS"
exit "${TEST_CORE_EXIT:-41}"
MOCK
cat > "$test_root/mocks/absent-port" <<'MOCK'
#!/bin/zsh
exit 1
MOCK
cat > "$test_root/mocks/uname" <<'MOCK'
#!/bin/zsh
if [[ "$1" == -s ]]; then print -r -- "$TEST_OS"; else print x86_64; fi
MOCK
cat > "$test_root/mocks/brew" <<'MOCK'
#!/bin/zsh
print -r -- "$*" >> "$TEST_BREW_LOG"
case "$1" in
  list) [[ "${TEST_INSTALLED:-false}" == true ]] ;;
  install|reinstall) exit 0 ;;
  --prefix) print -r -- "$TEST_PREFIX" ;;
  *) exit 1 ;;
esac
MOCK
cat > "$test_root/bin/sing-box" <<'MOCK'
#!/bin/zsh
print -r -- "sing-box version fixture"
print -r -- "Tags: ${TEST_TAGS-with_clash_api}"
MOCK
chmod +x "$test_root/mocks/"* "$test_root/bin/sing-box"
export PATH="$test_root/mocks:$PATH"
export TEST_OS=Darwin TEST_ARGS="$test_root/args"
export TEST_PREFIX="$test_root" TEST_BREW_LOG="$test_root/brew.log"
export RASH_STATE_DIR="$test_root/state"
export TMUX_BIN="$test_root/mocks/absent-port" LSOF_BIN="$test_root/mocks/absent-port"
export SING_BOX_BIN="$test_root/mocks/core" CLASH_BIN="$test_root/mocks/core"
export BREW_BIN="$test_root/mocks/brew"
fail() { print -u2 -- "FAIL: $*"; exit 1; }
expect_failure() {
  local expected="$1"
  shift
  local actual=0
  "$@" > "$test_root/output" 2>&1 || actual=$?
  [[ "$actual" == "$expected" ]] || fail "expected exit $expected, got $actual: $*"
}

# Unknown options must fail before a core runs.
expect_failure 1 "$test_root/rash" start --config SG --client invalid
expect_failure 1 "$test_root/rash" start --config SG --tun
[[ ! -e "$TEST_ARGS" ]] || fail 'invalid options launched a core'

# The default selects Clash and uses strict validation.
expect_failure 41 "$test_root/rash" start --config SG
[[ "$(<"$TEST_ARGS")" == *--test-config*--strict-config* ]] || fail 'Clash validation flags'
clash_runtime="$RASH_STATE_DIR/runtime/sg-clash-rs/config.yaml"
[[ "$(yq 'has("tun")' "$clash_runtime")" == false ]] || fail 'Clash TUN removal'
[[ "$(yq -r '.secret' "$clash_runtime")" != fixture-source-secret ]] || fail 'controller secret injection'

# Sing-box does not require Clash or its MMDB and must discard unsafe listeners.
rm "$test_root/assets/geoip/Country.mmdb"
export CLASH_BIN="$test_root/missing-clash"
yq -p=json -o=json -i '.inbounds = [{"type":"tun"}] | .endpoints = [{}] | .services = [{}] | .experimental.v2ray_api.listen = "0.0.0.0:1234"' "$test_root/configs/SG/sing-box.json"
source_digest="$(cksum "$test_root/configs/SG/sing-box.json")"
expect_failure 41 "$test_root/rash" start --config SG --client=sing-box
[[ "$(<"$TEST_ARGS")" == check$'\n'* ]] || fail 'sing-box check dispatch'
native_runtime="$RASH_STATE_DIR/runtime/sg-sing-box/sing-box.json"
[[ "$(yq -p=json -o=yaml -r '.inbounds[].type' "$native_runtime")" == $'mixed\ndirect' ]] || fail 'native listeners'
[[ "$(yq -p=json -o=yaml 'has("endpoints") or has("services") or (.experimental | has("v2ray_api"))' "$native_runtime")" == false ]] || fail 'native auxiliary services'
[[ "$(yq -p=json -o=yaml -r '.experimental.clash_api.external_controller' "$native_runtime")" == 127.0.0.1:9090 ]] || fail 'controller binding'
[[ "$(yq -p=json -o=yaml '.experimental.cache_file.enabled' "$native_runtime")" == true ]] || fail 'selection persistence'
[[ "$(yq -p=json -o=yaml -r '.route.rules[0].inbound[0]' "$native_runtime")" == rash-dns ]] || fail 'DNS scope'
[[ "$(cksum "$test_root/configs/SG/sing-box.json")" == "$source_digest" ]] || fail 'source was modified'
[[ ! -s "$RASH_STATE_DIR/state" ]] || fail 'failed check recorded a session'

# The wrapper must use run only for sing-box, preserving arguments with spaces.
for client in clash-rs sing-box; do
  TEST_CORE_EXIT=0 "$test_root/scripts/rash-session.zsh" "$client" "$SING_BOX_BIN" '/fixture dir' '/fixture dir/config' > /dev/null
  args="$(<"$TEST_ARGS")"
  [[ "$args" == *$'--directory\n/fixture dir\n--config\n/fixture dir/config' ]] || fail 'wrapper argument quoting'
  if [[ "$client" == sing-box ]]; then
    [[ "$args" == run$'\n'* ]] || fail 'sing-box run dispatch'
  else
    [[ "$args" == --directory$'\n'* ]] || fail 'Clash run dispatch'
  fi
done

# Homebrew is checked first for both all-assets and sing-box-only bootstraps.
for asset in all sing-box; do
  expect_failure 1 env BREW_BIN="$test_root/no-brew" "$test_root/scripts/download-assets.zsh" --only "$asset"
  [[ "$(<"$test_root/output")" == *'Homebrew is required'* ]] || fail 'missing Homebrew diagnostic'
done
for operating_system in Darwin Linux; do
  export TEST_OS="$operating_system"
  : > "$TEST_BREW_LOG"
  "$test_root/scripts/download-assets.zsh" --only sing-box > /dev/null
  [[ "$(<"$TEST_BREW_LOG")" == *'install sing-box'* ]] || fail 'brew install'
  : > "$TEST_BREW_LOG"
  TEST_INSTALLED=true "$test_root/scripts/download-assets.zsh" --only sing-box > /dev/null
  [[ "$(<"$TEST_BREW_LOG")" != *'install sing-box'* ]] || fail 'installed formula not reused'
  TEST_INSTALLED=true "$test_root/scripts/download-assets.zsh" --only sing-box --force > /dev/null
  [[ "$(<"$TEST_BREW_LOG")" == *'reinstall sing-box'* ]] || fail 'brew reinstall'
done
expect_failure 1 env TEST_TAGS=without_api "$test_root/scripts/download-assets.zsh" --only sing-box
expect_failure 1 "$test_root/rash" start --config SG --client sing-box --system-proxy
[[ "$(<"$test_root/output")" == *'only supported on macOS'* ]] || fail 'Linux system proxy guard'
export TEST_OS=Windows_NT
expect_failure 1 "$test_root/rash" status
expect_failure 1 "$test_root/scripts/download-assets.zsh" --only sing-box
print 'PASS: client dispatch, runtime isolation, wrapper arguments, Homebrew lifecycle, platform guards'
