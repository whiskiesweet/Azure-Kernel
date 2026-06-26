#!/bin/bash
set -euo pipefail

trap 'echo "inject-root.sh failed at line $LINENO (exit $?)" >&2' ERR

# ── KSUN ──────────────────────────────────────────────────────────────────────

if [ "${KSU_VARIANT}" = "KSUN" ]; then
    echo "=== Applying KSUN ==="
    curl -fsSL "${KSUN_SETUP_URL}" | bash -s dev-susfs
    printf '\nCONFIG_KSU=y\nCONFIG_KSU_MANUAL_HOOK=n\nCONFIG_KSU_SUSFS=y\n' \
        >> arch/arm64/configs/gki_defconfig

    echo "--- Applying SUSFS 2.2.0 (KSUN) ---"
    git clone --depth=1 -b "${SUSFS_BRANCH}" "${SUSFS_REPO}" sus
    PATCH=$(find sus/kernel_patches -maxdepth 1 -name "50_add_susfs_in_${SUSFS_BRANCH}.patch" | head -n1)
    [ -f "$PATCH" ] || { echo "ERROR: SUSFS patch not found for ${SUSFS_BRANCH}" >&2; exit 1; }
    cp -r sus/kernel_patches/fs .
    cp -r sus/kernel_patches/include .
    cp "$PATCH" .
    patch -p1 --fuzz=3 < "$(basename "$PATCH")"
    rm -rf sus
    echo "KSUN + SUSFS OK"
fi

# ── ReSuKiSU ──────────────────────────────────────────────────────────────────

if [ "${KSU_VARIANT}" = "ReSuKiSU" ]; then
    echo "=== Applying ReSuKiSU ==="
    curl -fsSL "${RESUKISU_SETUP_URL}" | bash -s ""

    echo "--- Applying SUSFS 2.2.0 (ReSuKiSU) ---"
    git clone --depth=1 -b "${SUSFS_BRANCH}" "${SUSFS_REPO}" sus
    PATCH=$(find sus/kernel_patches -maxdepth 1 -name "50_add_susfs_in_${SUSFS_BRANCH}.patch" | head -n1)
    [ -f "$PATCH" ] || { echo "ERROR: SUSFS patch not found for ${SUSFS_BRANCH}" >&2; exit 1; }
    cp -r sus/kernel_patches/fs .
    cp -r sus/kernel_patches/include .
    cp "$PATCH" .
    patch -p1 --fuzz=3 < "$(basename "$PATCH")"
    rm -rf sus

    echo "--- Configuring ReSuKiSU + SUSFS ---"
    if [ "${KPM_ENABLED:-false}" = "true" ]; then
        echo "--- KPM enabled ---"
        printf '\nCONFIG_KSU=y\nCONFIG_KSU_MANUAL_HOOK=n\nCONFIG_KSU_SUSFS=y\nCONFIG_KPROBES=y\nCONFIG_KPM=y\n' \
            >> arch/arm64/configs/gki_defconfig
    else
        echo "--- KPM disabled ---"
        printf '\nCONFIG_KSU=y\nCONFIG_KSU_MANUAL_HOOK=n\nCONFIG_KSU_SUSFS=y\n' \
            >> arch/arm64/configs/gki_defconfig
    fi

    echo "--- Verifying ReSuKiSU ---"
    test -L drivers/kernelsu || { echo "ERROR: symlink drivers/kernelsu missing" >&2; exit 1; }
    grep -q "kernelsu" drivers/Makefile  || { echo "ERROR: Makefile hook missing" >&2; exit 1; }
    grep -q 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig \
        || { echo "ERROR: Kconfig hook missing" >&2; exit 1; }
    echo "ReSuKiSU OK"
fi

# ── VNL (Vanilla — no root manager) ───────────────────────────────────────────

if [ "${KSU_VARIANT}" = "VNL" ]; then
    echo "=== VNL — no root manager applied ==="
fi
