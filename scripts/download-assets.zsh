#!/bin/zsh

set -eu
setopt pipe_fail

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr PROJECT_ROOT="${SCRIPT_PATH:h:h}"
typeset -gr DEFAULT_RASH_RELEASE_VERSION="v1.1.0"
typeset -gr DEFAULT_CLASH_RS_VERSION="v0.10.8"
typeset -gr DEFAULT_YACD_META_COMMIT="ba5f198831a1ea984cf2f46c6c0d66325fde7022"
typeset -gr DEFAULT_GEOIP_VERSION="202608130025"
typeset -gr DEFAULT_GEOIP_SHA256="2e81dcd2703da6efa667865a01dc73ec97304d66bc925d67a5d2ffd412291ca2"
typeset -gr RASH_REPOSITORY="Aethergrids/Rash"
typeset -gr GEOIP_REPOSITORY="Loyalsoldier/geoip"
typeset -gr CHECKSUMS_ASSET_NAME="SHA256SUMS"
typeset -gr YACD_META_ASSET_NAME="yacd-meta-gh-pages.zip"
typeset -gr GEOIP_ASSET_NAME="Country.mmdb"

typeset -gr CURL_BIN="${CURL_BIN:-${commands[curl]:-/usr/bin/curl}}"
typeset -gr UNZIP_BIN="${UNZIP_BIN:-${commands[unzip]:-/usr/bin/unzip}}"

typeset rash_release_version="${RASH_RELEASE_VERSION:-$DEFAULT_RASH_RELEASE_VERSION}"
typeset clash_rs_version="${CLASH_RS_VERSION:-$DEFAULT_CLASH_RS_VERSION}"
typeset yacd_meta_commit="${YACD_META_COMMIT:-$DEFAULT_YACD_META_COMMIT}"
typeset geoip_version="${GEOIP_VERSION:-$DEFAULT_GEOIP_VERSION}"
typeset geoip_sha256="${GEOIP_SHA256:-$DEFAULT_GEOIP_SHA256}"
typeset asset_base_url_override="${RASH_ASSET_BASE_URL:-}"
typeset requested_asset="all"
typeset force="false"
typeset temporary_root=""
typeset checksum_manifest=""

usage() {
  cat <<'EOF'
Usage:
  scripts/download-assets.zsh [--only all|clash-rs|yacd-meta|geoip]
                              [--release-version v1.1.0]
                              [--clash-version v0.10.8]
                              [--force]

Environment overrides:
  RASH_RELEASE_VERSION  Rash release containing mirrored assets
  RASH_ASSET_BASE_URL   Alternate release/mirror base URL
  CLASH_RS_VERSION      Expected Clash RS version in that release
  YACD_META_COMMIT      Expected Yacd-meta source commit
  GEOIP_VERSION         Pinned Loyalsoldier/geoip release tag
  GEOIP_SHA256          SHA-256 for that release's Country.mmdb
  GITHUB_TOKEN          Optional token for GitHub downloads
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

release_asset_url() {
  local asset_name="$1"
  local base_url

  if [[ -n "$asset_base_url_override" ]]; then
    base_url="${asset_base_url_override%/}"
  else
    base_url="https://github.com/${RASH_REPOSITORY}/releases/download/${rash_release_version}"
  fi
  print -r -- "${base_url}/${asset_name}"
}

sha256_file() {
  local file_path="$1"
  local checksum_output
  local digest
  local ignored

  if [[ -n "${commands[sha256sum]:-}" ]]; then
    checksum_output="$("${commands[sha256sum]}" "$file_path")"
  elif [[ -x /usr/bin/shasum ]]; then
    checksum_output="$(/usr/bin/shasum -a 256 "$file_path")"
  else
    die "sha256sum or shasum is required"
  fi

  IFS=' ' read -r digest ignored <<< "$checksum_output"
  print -r -- "$digest"
}

ensure_checksum_manifest() {
  [[ -s "$checksum_manifest" ]] && return 0
  print -u2 -r -- "Downloading checksums for Rash ${rash_release_version}..."
  github_curl "$(release_asset_url "$CHECKSUMS_ASSET_NAME")" \
    >| "$checksum_manifest"
}

expected_digest_for() {
  local requested_name="$1"
  local digest
  local file_name

  ensure_checksum_manifest
  while read -r digest file_name; do
    file_name="${file_name#\*}"
    if [[ "$file_name" == "$requested_name" ]]; then
      [[ ${#digest} -eq 64 ]] || die "invalid checksum for ${requested_name}"
      print -r -- "$digest"
      return 0
    fi
  done < "$checksum_manifest"

  die "${CHECKSUMS_ASSET_NAME} has no entry for ${requested_name}"
}

download_verified_asset() {
  local asset_name="$1"
  local destination="$2"
  local expected_digest
  local actual_digest
  local download_url

  expected_digest="$(expected_digest_for "$asset_name")"
  download_url="$(release_asset_url "$asset_name")"
  print -r -- "Downloading $download_url"
  github_curl "$download_url" >| "$destination"
  actual_digest="$(sha256_file "$destination")"
  [[ "$actual_digest" == "$expected_digest" ]] || \
    die "SHA-256 mismatch for ${asset_name}"
}

clash_asset_name() {
  local operating_system
  local architecture
  operating_system="$(uname -s)"
  architecture="$(uname -m)"

  case "${operating_system}:${architecture}" in
    Darwin:arm64) print -r -- "clash-rs-aarch64-apple-darwin" ;;
    Darwin:x86_64) print -r -- "clash-rs-x86_64-apple-darwin" ;;
    Linux:arm64|Linux:aarch64) print -r -- "clash-rs-aarch64-unknown-linux-gnu" ;;
    Linux:x86_64) print -r -- "clash-rs-x86_64-unknown-linux-gnu" ;;
    *) die "unsupported platform: ${operating_system} ${architecture}" ;;
  esac
}

download_clash_rs() {
  local destination="${PROJECT_ROOT}/bin/clash"
  local asset_name
  local download_path
  local version_output=""
  local installed_version=""

  asset_name="$(clash_asset_name)"
  if [[ -x "$destination" ]]; then
    version_output="$("$destination" --version 2>/dev/null || true)"
    installed_version="${version_output##* }"
  fi

  if [[ "$force" != "true" && "$installed_version" == "${clash_rs_version#v}" ]]; then
    print -r -- "Clash RS ${installed_version} is already installed at $destination"
    return 0
  fi

  download_path="${temporary_root}/${asset_name}"
  download_verified_asset "$asset_name" "$download_path"
  chmod 755 "$download_path"

  version_output="$("$download_path" --version 2>/dev/null || true)"
  [[ "${version_output##* }" == "${clash_rs_version#v}" ]] || \
    die "${asset_name} is not Clash RS ${clash_rs_version#v}"

  mkdir -p "${PROJECT_ROOT}/bin"
  mv -f "$download_path" "$destination"
  print -r -- "Installed $version_output at $destination"
}

remove_yacd_tun_card() {
  local destination="$1"
  local bundle="${destination}/assets/index-CJUkmLR8.js"
  local original_digest="4aa7cd7ca0a9f9f247baa6e24a77c7caff77176fd5ddb50302c05f0edf79257b"
  local patched_digest="b66cb471007672a22ead9389a02972768d556636f67249aa01601c436a2ffdc1"
  local digest
  local contents
  local card
  local patched_bundle="${temporary_root}/yacd-without-tun.js"

  [[ -r "$bundle" ]] || die "Yacd-meta bundle does not match the pinned TUN removal patch"
  digest="$(sha256_file "$bundle")"
  [[ "$digest" == "$patched_digest" ]] && return 0
  [[ "$digest" == "$original_digest" ]] || \
    die "Yacd-meta bundle changed; review the TUN removal patch before updating"

  card="$(<"${PROJECT_ROOT}/scripts/yacd-meta-tun-card.txt")"
  contents="$(<"$bundle")"
  [[ -n "$card" && "$contents" == *"$card"* ]] || die "Yacd-meta TUN card was not found"
  print -rn -- "${contents/"$card"/null}" >| "$patched_bundle"
  [[ "$(sha256_file "$patched_bundle")" == "$patched_digest" ]] || \
    die "Yacd-meta TUN removal checksum mismatch"
  chmod 644 "$patched_bundle"
  mv -f "$patched_bundle" "$bundle"
}

download_yacd_meta() {
  local destination="${PROJECT_ROOT}/assets/yacd-meta"
  local archive_path="${temporary_root}/${YACD_META_ASSET_NAME}"
  local extract_dir="${temporary_root}/yacd-meta-extracted"
  local -a extracted_directories

  if [[ "$force" != "true" && -r "${destination}/index.html" ]]; then
    remove_yacd_tun_card "$destination"
    if [[ -r "${destination}/.rash-source" && \
          "$(<"${destination}/.rash-source")" != *'local-modification=remove-tun-card'* ]]; then
      print -r -- "local-modification=remove-tun-card" >> "${destination}/.rash-source"
    fi
    print -r -- "Yacd-meta is already installed at $destination"
    return 0
  fi

  download_verified_asset "$YACD_META_ASSET_NAME" "$archive_path"
  mkdir -p "$extract_dir"
  "$UNZIP_BIN" -q "$archive_path" -d "$extract_dir"
  extracted_directories=("$extract_dir"/*(/N))
  (( ${#extracted_directories} == 1 )) || \
    die "unexpected Yacd-meta archive layout"
  remove_yacd_tun_card "${extracted_directories[1]}"

  mkdir -p "${PROJECT_ROOT}/assets"
  if [[ -e "$destination" ]]; then
    mv "$destination" "${temporary_root}/previous-yacd-meta"
  fi
  mv "${extracted_directories[1]}" "$destination"

  {
    print -r -- "repository=https://github.com/MetaCubeX/Yacd-meta"
    print -r -- "branch=gh-pages"
    print -r -- "commit=${yacd_meta_commit}"
    print -r -- "rash-release=${rash_release_version}"
    print -r -- "archive=$(release_asset_url "$YACD_META_ASSET_NAME")"
    print -r -- "local-modification=remove-tun-card"
  } >| "${destination}/.rash-source"

  [[ -r "${destination}/index.html" ]] || die "Yacd-meta index.html is missing"
  print -r -- "Installed Yacd-meta ${yacd_meta_commit[1,12]} at $destination"
}

download_geoip() {
  local destination="${PROJECT_ROOT}/assets/geoip/${GEOIP_ASSET_NAME}"
  local download_path="${temporary_root}/${GEOIP_ASSET_NAME}"
  local download_url="https://github.com/${GEOIP_REPOSITORY}/releases/download/${geoip_version}/${GEOIP_ASSET_NAME}"
  local installed_digest=""
  local downloaded_digest

  if [[ -r "$destination" ]]; then
    installed_digest="$(sha256_file "$destination")"
  fi
  if [[ "$force" != "true" && "$installed_digest" == "$geoip_sha256" ]]; then
    print -r -- "GeoIP ${geoip_version} is already installed at $destination"
    return 0
  fi

  print -r -- "Downloading $download_url"
  github_curl "$download_url" >| "$download_path"
  downloaded_digest="$(sha256_file "$download_path")"
  [[ "$downloaded_digest" == "$geoip_sha256" ]] || \
    die "SHA-256 mismatch for ${GEOIP_ASSET_NAME}"

  mkdir -p "${destination:h}"
  mv -f "$download_path" "$destination"
  {
    print -r -- "repository=https://github.com/${GEOIP_REPOSITORY}"
    print -r -- "release=${geoip_version}"
    print -r -- "asset=${GEOIP_ASSET_NAME}"
    print -r -- "sha256=${geoip_sha256}"
  } >| "${destination:h}/.rash-source"
  print -r -- "Installed GeoIP ${geoip_version} at $destination"
}

while (( $# > 0 )); do
  case "$1" in
    --only)
      (( $# >= 2 )) || die "--only requires all, clash-rs, yacd-meta, or geoip"
      requested_asset="$2"
      shift 2
      ;;
    --release-version)
      (( $# >= 2 )) || die "--release-version requires a release tag"
      rash_release_version="$2"
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
  all|clash-rs|yacd-meta|geoip) ;;
  *) die "--only must be all, clash-rs, yacd-meta, or geoip" ;;
esac

require_executable "$CURL_BIN" "curl"
if [[ "$requested_asset" == "all" || "$requested_asset" == "yacd-meta" ]]; then
  require_executable "$UNZIP_BIN" "unzip"
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/rash-assets.XXXXXX")"
checksum_manifest="${temporary_root}/${CHECKSUMS_ASSET_NAME}"
trap cleanup EXIT INT TERM HUP

case "$requested_asset" in
  all)
    download_clash_rs
    download_yacd_meta
    download_geoip
    ;;
  clash-rs) download_clash_rs ;;
  yacd-meta) download_yacd_meta ;;
  geoip) download_geoip ;;
esac
