#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../config/toolchain.conf"

_download_extract() {
    local url="$1" dest="$2"
    mkdir -p "$dest"
    local tmp
    tmp=$(mktemp /tmp/clang.XXXXXX)
    curl -fsSL "$url" -o "$tmp"
    case "$url" in
        *.7z)     7z x "$tmp" -o"$dest" ;;
        *.tar.gz) tar -xzf "$tmp" -C "$dest" --strip-components=1 ;;
        *.tar.xz) tar -xJf "$tmp" -C "$dest" --strip-components=1 ;;
        *.tar.*)  tar -xf  "$tmp" -C "$dest" --strip-components=1 ;;
        *)
            echo "ERROR: unknown archive format: $url" >&2
            rm -f "$tmp"; exit 1 ;;
    esac
    rm -f "$tmp"
}

# ── CLANG-19 ──────────────────────────────────────────────────────────────────

if [ "${CLANG_VARIANT}" = "CLANG-19" ]; then
    echo "=== Setting up CLANG-19 ==="
    if [ ! -f "${CLANG19_DIR}/bin/clang" ]; then
        git clone --depth=1 "${CLANG19_REPO}" "${CLANG19_DIR}"
    else
        echo "CLANG-19 already cached."
    fi
    CLANG_PATH="${CLANG19_DIR}"
fi

# ── CLANG-22 ──────────────────────────────────────────────────────────────────

if [ "${CLANG_VARIANT}" = "CLANG-22" ]; then
    echo "=== Setting up CLANG-22 ==="
    if [ ! -f "${CLANG22_DIR}/bin/clang" ]; then
        _download_extract "${CLANG22_URL}" "${CLANG22_DIR}"
    else
        echo "CLANG-22 already cached."
    fi
    CLANG_PATH="${CLANG22_DIR}"
fi

# ── Verify & export ───────────────────────────────────────────────────────────

if [ -z "${CLANG_PATH:-}" ]; then
    echo "ERROR: CLANG_VARIANT '${CLANG_VARIANT}' not recognised." >&2
    exit 1
fi

echo "Clang path : ${CLANG_PATH}"
echo "Clang version:"
"${CLANG_PATH}/bin/clang" --version | head -n 2

echo "CLANG_PATH=${CLANG_PATH}" >> "$GITHUB_ENV"
echo "=== Toolchain ready ==="
