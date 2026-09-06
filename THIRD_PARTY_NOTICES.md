# Third-party notices

Rash releases mirror unmodified dependencies so the bootstrap script can use
one versioned, checksum-verified source.

## Clash RS

- Project: <https://github.com/Watfaq/clash-rs>
- Version: `v0.10.8`
- License: Apache License 2.0
- Mirrored files: the official pre-built macOS and Linux binaries for arm64
  and x86_64

The release includes the upstream license as `clash-rs-LICENSE`.

## Yacd-meta

- Project: <https://github.com/MetaCubeX/Yacd-meta>
- Branch: `gh-pages`
- Commit: `ba5f198831a1ea984cf2f46c6c0d66325fde7022`
- Package license metadata: MIT
- Mirrored file: `yacd-meta-gh-pages.zip`

Yacd-meta is derived from <https://github.com/haishanh/yacd>. The release
includes its MIT license as `yacd-meta-LICENSE`.

Rash's local dashboard removes the TUN settings card from the pinned bundle.
`scripts/download-assets.zsh` applies this modification after verifying the
upstream archive, checks the original and modified bundle hashes, and records
it in `.rash-source`. `scripts/yacd-meta-tun-card.txt` contains the upstream
card expression removed by the patch. Mirrored release archives remain
unmodified.
