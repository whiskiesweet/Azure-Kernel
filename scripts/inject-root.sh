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

# ── KWS (KowSU, no SUSFS, Droidspaces-ready) ──────────────────────────────────

if [ "${KSU_VARIANT}" = "KWS" ]; then
    echo "=== Applying KowSU (no SUSFS) ==="
    rm -rf drivers/KowSU
    git clone --depth=1 https://github.com/KOWX712/KernelSU drivers/KowSU

    echo "--- Hooking KowSU into drivers/Makefile & drivers/Kconfig ---"
    grep -q "KowSU/kernel" drivers/Makefile \
        || echo "obj-y += KowSU/kernel/" >> drivers/Makefile
    grep -q 'source "drivers/KowSU/kernel/Kconfig"' drivers/Kconfig \
        || sed -i '/endmenu/i source "drivers/KowSU/kernel/Kconfig"' drivers/Kconfig

    printf '\nCONFIG_KSU=y\nCONFIG_KSU_MANUAL_HOOK=n\n' \
        >> arch/arm64/configs/gki_defconfig
    echo "NOTE: SUSFS intentionally skipped for KWS (Droidspaces compatibility)."

    echo "--- Verifying KowSU ---"
    test -f drivers/KowSU/kernel/Kconfig || { echo "ERROR: drivers/KowSU/kernel/Kconfig missing" >&2; exit 1; }
    grep -q "KowSU/kernel" drivers/Makefile || { echo "ERROR: Makefile hook missing" >&2; exit 1; }
    grep -q 'source "drivers/KowSU/kernel/Kconfig"' drivers/Kconfig \
        || { echo "ERROR: Kconfig hook missing" >&2; exit 1; }
    echo "KowSU OK"

    echo "--- Applying Droidspaces kABI fix patches (GKI, kernel 5.10) ---"
    git clone --depth=1 "${DROIDSPACES_REPO}" droidspaces
    PATCH_DIR="droidspaces/Documentation/resources/kernel-patches/GKI/below-kernel-6.12"
    [ -d "$PATCH_DIR" ] || { echo "ERROR: Droidspaces GKI patch dir not found" >&2; exit 1; }

    SYSVIPC_PATCH=$(find "$PATCH_DIR" -maxdepth 1 -name "001.GKI-below-6.12-fix_sysvipc_kabi*.patch" | head -n1)
    MQUEUE_PATCH=$(find "$PATCH_DIR" -maxdepth 1 -name "002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch" | head -n1)
    [ -f "$SYSVIPC_PATCH" ] || { echo "ERROR: SYSVIPC kABI patch not found" >&2; exit 1; }
    [ -f "$MQUEUE_PATCH" ]  || { echo "ERROR: POSIX_MQUEUE kABI patch not found" >&2; exit 1; }

    apply_droidspaces_patch() {
        local patch_file="$1"
        if patch -p1 -N --dry-run --silent < "$patch_file" >/dev/null 2>&1; then
            patch -p1 -N < "$patch_file"
            echo "Applied: $(basename "$patch_file")"
        elif patch -p1 -N --dry-run --reverse --silent < "$patch_file" >/dev/null 2>&1; then
            echo "SKIP (already applied upstream): $(basename "$patch_file")"
        else
            echo "ERROR: patch does not apply cleanly: $(basename "$patch_file")" >&2
            echo "--- dry-run output for diagnostics ---" >&2
            patch -p1 -N --dry-run < "$patch_file" >&2 || true
            exit 1
        fi
    }

    apply_droidspaces_patch "$SYSVIPC_PATCH"
    apply_droidspaces_patch "$MQUEUE_PATCH"
    rm -rf droidspaces
    echo "Droidspaces kABI patches applied OK"
fi
