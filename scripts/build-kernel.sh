#!/bin/bash
set -euo pipefail

trap 'echo "build-kernel.sh failed at line $LINENO (exit $?)" >&2' ERR

set -a
source "$(dirname "$0")/../config/kernel.conf"
set +a

unset LOCALVERSION

if [ -z "${CLANG_PATH:-}" ]; then
    echo "ERROR: CLANG_PATH is not set." >&2
    exit 1
fi

export PATH="${CLANG_PATH}/bin:${PATH}"
echo "Clang version : $(${CLANG_PATH}/bin/clang --version | head -n1)"

# ── Strip EXTRAVERSION ────────────────────────────────────────────────────────

echo "=== Stripping EXTRAVERSION ==="
sed -i 's/^EXTRAVERSION[[:space:]]*=.*/EXTRAVERSION =/' Makefile

# ── Set LOCALVERSION ──────────────────────────────────────────────────────────

printf '\nCONFIG_LOCALVERSION="%s"\n' "${LOCALVERSION}" \
    >> arch/arm64/configs/gki_defconfig

# ── Polly ─────────────────────────────────────────────────────────────────────

POLLY_FLAGS=""
if "${CLANG_PATH}/bin/clang" -mllvm -polly -x c /dev/null -o /dev/null 2>/dev/null; then
    echo "Polly : available"
    POLLY_FLAGS="-mllvm -polly -polly-run-dce"
else
    echo "Polly : not available"
fi

# ── KCFLAGS ───────────────────────────────────────────────────────────────────

export KCFLAGS="-w -march=armv8.2-a -mtune=generic -fno-semantic-interposition ${POLLY_FLAGS}"

# ── Linker ────────────────────────────────────────────────────────────────────

if command -v ld.lld >/dev/null 2>&1; then
    export LD=ld.lld
elif [ -x "${CLANG_PATH}/bin/ld.lld" ]; then
    export LD="${CLANG_PATH}/bin/ld.lld"
else
    echo "ERROR: ld.lld not found." >&2
    exit 1
fi

# ── ZRAM Multiple Compression (ZMC) pre-flight ────────────────────────────────

echo "=== Validating ZMC backport ==="
grep -q "ZRAM_MULTI_COMP" drivers/block/zram/Kconfig 2>/dev/null \
    || { echo "ERROR: ZRAM_MULTI_COMP not found in Kconfig" >&2; exit 1; }
grep -q "recompress" drivers/block/zram/zram_drv.c 2>/dev/null \
    || { echo "ERROR: recompress not found in zram_drv.c" >&2; exit 1; }
echo "ZMC backport OK"

grep -q "^CONFIG_ZRAM_MULTI_COMP" arch/arm64/configs/gki_defconfig \
    || echo "CONFIG_ZRAM_MULTI_COMP=y" >> arch/arm64/configs/gki_defconfig

# ── Generate config ───────────────────────────────────────────────────────────

make O=out gki_defconfig

# ── Kernel tweaks ─────────────────────────────────────────────────────────────

echo "=== Applying kernel tweaks ==="
scripts/config --file out/.config \
    -e LTO_CLANG -d LTO_NONE -e LTO_CLANG_THIN -d LTO_CLANG_FULL -e THINLTO

scripts/config --file out/.config \
    -e ZRAM -e ZSMALLOC \
    -e CRYPTO_ZSTD -e CRYPTO_LZ4 -e CRYPTO_LZ4HC \
    -e ZRAM_MULTI_COMP --set-str ZRAM_DEF_COMP "lz4hc"

scripts/config --file out/.config \
    -e SUSPEND -e SUSPEND_FREEZER -e PM_SLEEP \
    -e PM_AUTOSLEEP -e PM_WAKELOCKS -e PM_WAKELOCKS_GC \
    --set-val PM_WAKELOCKS_LIMIT 100 \
    -e CPU_IDLE -e CPU_IDLE_GOV_MENU -e ARM_CPUIDLE -e ARM_PSCI_CPUIDLE

scripts/config --file out/.config -d LOCALVERSION_AUTO

make O=out CC=clang LLVM=1 CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
echo "Kernel release: $(make -s O=out CC=clang LLVM=1 CROSS_COMPILE="${CROSS_COMPILE}" kernelrelease)"

# ── Build ─────────────────────────────────────────────────────────────────────

echo "=== Building kernel image ==="
make -j"$(nproc --all)" O=out CC=clang LLVM=1 CROSS_COMPILE="${CROSS_COMPILE}" Image

# ── Post-build verification ───────────────────────────────────────────────────

echo "=== Post-build verification ==="

echo "--- Compiler (.comment) ---"
readelf -p .comment out/vmlinux 2>/dev/null | grep -v "^$\|String dump" || true

echo "--- LTO ---"
grep -E "CONFIG_LTO|CONFIG_THINLTO" out/.config || true

echo "--- ThinLTO cache ---"
[ -d out/.thinlto-cache ] && ls -A out/.thinlto-cache | head -3 && echo "ThinLTO ran." || echo "No ThinLTO cache."

echo "--- Power management ---"
grep -E "CONFIG_SUSPEND|CONFIG_PM_SLEEP|CONFIG_PM_AUTOSLEEP|CONFIG_ARM_PSCI_CPUIDLE" out/.config | grep -v "^#" || true

echo "--- ZRAM + ZMC ---"
grep -E "CONFIG_ZRAM|CONFIG_ZRAM_MULTI_COMP|CONFIG_ZRAM_DEF_COMP" out/.config | grep -v "^#" || true

echo "--- Kernel release string ---"
KRELEASE=$(make -s O=out CC=clang LLVM=1 CROSS_COMPILE="${CROSS_COMPILE}" kernelrelease 2>/dev/null)
echo "${KRELEASE}"
echo "${KRELEASE}" | grep -q "\-rc" && echo "WARNING: -rc suffix still present." || echo "OK: no -rc suffix."

echo "--- compile.h ---"
cat out/include/generated/compile.h 2>/dev/null || true

# ── KMI validation ────────────────────────────────────────────────────────────

if [ "${KMI_SYMBOL_CHECK}" = "true" ]; then
    echo "=== KMI validation ==="
    python3 KMI_function_symbols_test.py
else
    echo "KMI symbol check disabled."
fi

echo "=== Build complete. Toolchain: ${CLANG_VARIANT} ==="
