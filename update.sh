#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

update_qoder() {
    local pkgbuild="$REPO_DIR/qoder/PKGBUILD"
    if [[ ! -f "$pkgbuild" ]]; then
        echo "[qoder] PKGBUILD not found, skipping."
        return
    fi

    local local_ver
    local_ver=$(grep -E '^pkgver=' "$pkgbuild" | cut -d= -f2)

    echo "[qoder] Checking upstream version (current: $local_ver)..."

    # Get upstream metadata via HEAD request
    local headers
    headers=$(curl -sIL https://download.qoder.com/qoder-app/releases/latest/Qoder-linux-amd64.deb)
    local remote_ver
    remote_ver=$(echo "$headers" | grep -i '^x-oss-meta-version:' | tr -d '\r' | awk '{print $2}')
    local remote_sha
    remote_sha=$(echo "$headers" | grep -i '^x-oss-meta-sha256:' | tr -d '\r' | awk '{print $2}')

    # Fallback to latest-linux.yml if headers were not present
    if [[ -z "$remote_ver" || -z "$remote_sha" ]]; then
        local yml
        yml=$(curl -sL https://download.qoder.com.cn/qoder-app/releases/latest-linux.yml)
        remote_ver=$(echo "$yml" | awk '/^version:/{print $2; exit}')
        remote_sha=$(echo "$yml" | awk '/url: .*Qoder-linux-amd64\.deb/{flag=1} flag && /sha256:/{print $2; exit}')
    fi

    if [[ -z "$remote_ver" || -z "$remote_sha" ]]; then
        echo "[qoder] Error: Failed to fetch upstream version/sha256." >&2
        return 1
    fi

    if [[ "$local_ver" == "$remote_ver" ]]; then
        echo "[qoder] Up to date ($local_ver)."
    else
        echo "[qoder] New version available: $local_ver -> $remote_ver"
        echo "[qoder] Updating $pkgbuild..."
        sed -i "s/^pkgver=.*/pkgver=${remote_ver}/" "$pkgbuild"
        sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
        sed -i "s/^sha256sums=('.*')/sha256sums=('${remote_sha}')/" "$pkgbuild"
        echo "[qoder] Successfully updated to $remote_ver."
    fi
}

update_qoder_ide() {
    local pkgbuild="$REPO_DIR/qoder-ide/PKGBUILD"
    if [[ ! -f "$pkgbuild" ]]; then
        echo "[qoder-ide] PKGBUILD not found, skipping."
        return
    fi

    local local_ver
    local_ver=$(grep -E '^pkgver=' "$pkgbuild" | cut -d= -f2)

    echo "[qoder-ide] Checking upstream version (current: $local_ver)..."

    local remote_ver
    remote_ver=$(curl -sL "https://center.qoder.sh/algo/api/update/linux-x64/stable/0000000000000000000000000000000000000000" | jq -r '.productVersion // empty' 2>/dev/null || true)

    if [[ -z "$remote_ver" ]]; then
        echo "[qoder-ide] Error: Failed to fetch upstream version." >&2
        return 1
    fi

    if [[ "$local_ver" == "$remote_ver" ]]; then
        echo "[qoder-ide] Up to date ($local_ver)."
    else
        echo "[qoder-ide] New version available: $local_ver -> $remote_ver"
        echo "[qoder-ide] Calculating SHA256 of new release..."
        local remote_sha
        remote_sha=$(curl -sL https://download.qoder.com/release/latest/qoder-ide_amd64.deb | sha256sum | awk '{print $1}')

        if [[ -z "$remote_sha" ]]; then
            echo "[qoder-ide] Error: Failed to compute SHA256." >&2
            return 1
        fi

        echo "[qoder-ide] Updating $pkgbuild..."
        sed -i "s/^pkgver=.*/pkgver=${remote_ver}/" "$pkgbuild"
        sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild"
        sed -i "s/^sha256sums=('.*')/sha256sums=('${remote_sha}')/" "$pkgbuild"
        echo "[qoder-ide] Successfully updated to $remote_ver."
    fi
}

update_qoder
echo ""
update_qoder_ide
