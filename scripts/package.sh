#!/bin/bash
set -euo pipefail

trap 'echo "package.sh failed at line $LINENO (exit $?)" >&2' ERR

source "$(dirname "$0")/../config/kernel.conf"

KERNEL_ZIP="${KERNEL_NAME}-${KSU_VARIANT}-${CLANG_VARIANT}"
echo "ZIP_NAME=${KERNEL_ZIP}" >> "$GITHUB_ENV"

echo "=== Packaging with AnyKernel3 ==="
git clone --depth=1 "${ANYKERNEL3_REPO}" anykernel

sed -i "s/kernel\.string=.*/kernel.string=\"${KERNEL_NAME}-${KSU_VARIANT} by whiskiesweet\"/" \
    anykernel/anykernel.sh

cp kernel/out/arch/arm64/boot/Image anykernel/Image

cd anykernel
zip -r9 "../${KERNEL_ZIP}.zip" . \
    -x "*.git*" -x ".git" -x ".git/*" \
    -x "README.md" -x "*.placeholder" -x "*.zip"
cd ..

echo "=== Uploading artifacts ==="
echo "Image  : kernel/out/arch/arm64/boot/Image"
echo "Package: ${KERNEL_ZIP}.zip"
