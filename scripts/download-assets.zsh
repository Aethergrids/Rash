#!/bin/zsh

set -eu
setopt pipe_fail

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr PROJECT_ROOT="${SCRIPT_PATH:h:h}"
typeset -gr DEFAULT_CLASH_RS_VERSION="v0.10.8"
typeset -gr DEFAULT_YACD_META_URL="https://github.com/MetaCubeX/yacd/archive/gh-pages.zip"

typeset -gr CURL_BIN="${CURL_BIN:-${commands[curl]:-/usr/bin/curl}}"
typeset -gr YQ_BIN="${YQ_BIN:-${commands[yq]:-}}"
typeset -gr UNZIP_BIN="${UNZIP_BIN:-${commands[unzip]:-/usr/bin/unzip}}"

typeset clash_rs_version="${CLASH_RS_VERSION:-$DEFAULT_CLASH_RS_VERSION}"
typeset yacd_meta_url="${YACD_META_URL:-$DEFAULT_YACD_META_URL}"
typeset requested_asset="all"
typeset force="false"
typeset temporary_root=""

usage() {
  cat <<'EOF'
Usage:
  scripts/download-assets.zsh [--only all|clash-rs|yacd-meta]
                              [--clash-version v0.10.8]
                              [--force]

Environment overrides:
  CLASH_RS_VERSION  Clash RS release tag
  YACD_META_URL     Yacd-meta gh-pages archive URL
  GITHUB_TOKEN      Optional token for GitHub API rate limits
EOF
}

die() {
  print -u2 -r -- "download-assets: $*"
  exit 1
}

require_executable() {
  local executable_path="$1"
  local label="$2"
  [[ -n "$executable_path" && -x "$executable_path" ]] || \
    die "$label is required but was not found"
}

cleanup() {
  [[ -n "$temporary_root" && -d "$temporary_root" ]] || return 0
  [[ "$temporary_root" == */rash-assets.* ]] || return 1
  rm -rf -- "$temporary_root"
}

github_curl() {
  local -a arguments
  arguments=(--fail --location --silent --show-error --retry 3)
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    arguments+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  "$CURL_BIN" "${arguments[@]}" "$@"
}

sha256_file() {
  local file_path="$1"
  if [[ -n "${commands[sha256sum]:-}" ]]; then
    sha256sum "$file_path" | awk '{print $1}'
  elif [[ -x /usr/bin/shasum ]]; then
    /usr/bin/shasum -a 256 "$file_path" | awk '{print $1}'
  else
    die "sha256sum or shasum is required"
  fi
}

clash_asset_name() {
  local os
  local architecture
  os="$(uname -s)"
  architecture="$(uname -m)"

  case "${os}:${architecture}" in
    Darwin:arm64) print -r -- "clash-rs-aarch64-apple-darwin" ;;
    Darwin:x86_64) print -r -- "clash-rs-x86_64-apple-darwin" ;;
    Linux:arm64|Linux:aarch64) print -r -- "clash-rs-aarch64-unknown-linux-gnu" ;;
    Linux:x86_64) print -r -- "clash-rs-x86_64-unknown-linux-gnu" ;;
    *) die "unsupported platform: ${os} ${architecture}" ;;
  esac
}

download_clash_rs() {
  local destination="${PROJECT_ROOT}/bin/clash"
  local asset_name
  local release_json
  local download_path
  local download_url
  local expected_digest
  local actual_digest
  local installed_version=""

  asset_name="$(clash_asset_name)"
  if [[ -x "$destination" ]]; then
    installed_version="$("$destination" --version 2>/dev/null | awk '{print $2}')"
  fi

  if [[ "$force" != "true" && "$installed_version" == "${clash_rs_version#v}" ]]; then
    print -r -- "Clash RS ${installed_version} is already installed at $destination"
    return 0
  fi

  release_json="${temporary_root}/clash-release.json"
  download_path="${temporary_root}/${asset_name}"

  print -r -- "Resolving Clash RS ${clash_rs_version} asset ${asset_name}..."
  github_curl \
    "https://api.github.com/repos/Watfaq/clash-rs/releases/tags/${clash_rs_version}" \
    >| "$release_json"

  download_url="$(CLASH_ASSET_NAME="$asset_name" "$YQ_BIN" -p=json -o=json -r \
    '.assets[] | select(.name == strenv(CLASH_ASSET_NAME)) | .browser_download_url' \
    "$release_json")"
  expected_digest="$(CLASH_ASSET_NAME="$asset_name" "$YQ_BIN" -p=json -o=json -r \
    '.assets[] | select(.name == strenv(CLASH_ASSET_NAME)) | .digest' \
    "$release_json")"

  [[ -n "$download_url" && "$download_url" != "null" ]] || \
    die "release ${clash_rs_version} has no asset named ${asset_name}"
  [[ "$expected_digest" == sha256:* ]] || \
    die "release asset ${asset_name} does not expose a SHA-256 digest"

  print -r -- "Downloading $download_url"
  github_curl "$download_url" >| "$download_path"
  actual_digest="$(sha256_file "$download_path")"
  [[ "$actual_digest" == "${expected_digest#sha256:}" ]] || \
    die "SHA-256 mismatch for ${asset_name}"

  mkdir -p "${PROJECT_ROOT}/bin"
  chmod 755 "$download_path"
  mv -f "$download_path" "$destination"
  print -r -- "Installed $("$destination" --version) at $destination"
}

download_yacd_meta() {
  local destination="${PROJECT_ROOT}/assets/yacd-meta"
  local archive_path="${temporary_root}/yacd-meta.zip"
  local extract_dir="${temporary_root}/yacd-meta-extracted"
  local branch_json="${temporary_root}/yacd-meta-branch.json"
  local upstream_commit
  local -a extracted_directories

  if [[ "$force" != "true" && -r "${destination}/index.html" ]]; then
    print -r -- "Yacd-meta is already installed at $destination"
    return 0
  fi

  print -r -- "Downloading Yacd-meta gh-pages..."
  github_curl "$yacd_meta_url" >| "$archive_path"
  mkdir -p "$extract_dir"
  "$UNZIP_BIN" -q "$archive_path" -d "$extract_dir"
  extracted_directories=("$extract_dir"/*(/N))
  (( ${#extracted_directories} == 1 )) || \
    die "unexpected Yacd-meta archive layout"

  github_curl "https://api.github.com/repos/MetaCubeX/Yacd-meta/branches/gh-pages" \
    >| "$branch_json"
  upstream_commit="$("$YQ_BIN" -p=json -o=json -r '.commit.sha' "$branch_json")"

  mkdir -p "${PROJECT_ROOT}/assets"
  if [[ -e "$destination" ]]; then
    mv "$destination" "${temporary_root}/previous-yacd-meta"
  fi
  mv "${extracted_directories[1]}" "$destination"

  {
    print -r -- "repository=https://github.com/MetaCubeX/Yacd-meta"
    print -r -- "branch=gh-pages"
    print -r -- "commit=${upstream_commit}"
    print -r -- "archive=${yacd_meta_url}"
  } >| "${destination}/.rash-source"

  [[ -r "${destination}/index.html" ]] || die "Yacd-meta index.html is missing"
  print -r -- "Installed Yacd-meta ${upstream_commit[1,12]} at $destination"
}

while (( $# > 0 )); do
  case "$1" in
    --only)
      (( $# >= 2 )) || die "--only requires all, clash-rs, or yacd-meta"
      requested_asset="$2"
      shift 2
      ;;
    --clash-version)
      (( $# >= 2 )) || die "--clash-version requires a release tag"
      clash_rs_version="$2"
      shift 2
      ;;
    --force)
      force="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$requested_asset" in
  all|clash-rs|yacd-meta) ;;
  *) die "--only must be all, clash-rs, or yacd-meta" ;;
esac

require_executable "$CURL_BIN" "curl"
require_executable "$YQ_BIN" "yq v4"
[[ "$requested_asset" == "clash-rs" ]] || require_executable "$UNZIP_BIN" "unzip"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/rash-assets.XXXXXX")"
trap cleanup EXIT INT TERM HUP

[[ "$requested_asset" == "yacd-meta" ]] || download_clash_rs
[[ "$requested_asset" == "clash-rs" ]] || download_yacd_meta
