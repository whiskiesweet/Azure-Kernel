#!/bin/bash
set -euo pipefail

echo "=== Installing build dependencies ==="
sudo apt-get update -q
sudo apt-get install -y --no-install-recommends \
    bc bison flex build-essential libssl-dev libelf-dev \
    cpio kmod rsync zip patch curl ca-certificates \
    python3 python3-pip python3-lxml libxml2-dev libxslt1-dev \
    git wget binutils zstd lld p7zip-full

python3 -c "import lxml" 2>/dev/null || pip3 install --break-system-packages lxml
echo "=== Dependencies ready ==="
