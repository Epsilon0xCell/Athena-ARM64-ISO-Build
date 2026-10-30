#!/bin/bash
# validate-kickstart.sh - Local validation script for the kickstart file

set -e

# Run from the directory this script lives in, so the relative paths
# below work no matter where the caller invokes it from.
cd "$(dirname "$0")"

echo "🔍 Validating AthenaOS ARM64 Kickstart Configuration"
echo "=================================================="

# The pykickstart package ships its validator as the ksvalidator
# command. There is no pykickstart command, so checking for one made
# this script report a missing tool on correctly installed systems.
if ! command -v ksvalidator &> /dev/null; then
    echo "❌ ksvalidator not found. Please install the pykickstart package:"
    echo "   Fedora/RHEL: sudo dnf install pykickstart"
    echo "   Ubuntu/Debian: sudo apt install pykickstart"
    exit 1
fi

# Validate kickstart syntax
echo "📋 Validating kickstart syntax..."
if ksvalidator --version F40 athena-iso.ks; then
    echo "✅ Kickstart syntax is valid"
else
    echo "❌ Kickstart syntax validation failed"
    exit 1
fi

# Check repository accessibility for ARM64
echo ""
echo "🌐 Checking repository accessibility for ARM64..."

repos=(
    "https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-40&arch=aarch64"
    "https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f40&arch=aarch64"
    "https://copr-be.cloud.fedoraproject.org/results/@athenaos/athenaos/fedora-40-aarch64/"
    "https://copr-be.cloud.fedoraproject.org/results/petersen/nix/fedora-40-aarch64/"
    "https://hub.athenaos.org/athena/aarch64"
)

for repo in "${repos[@]}"; do
    echo -n "  Checking $repo ... "
    if curl -s --head "$repo" | head -n 1 | grep -q "200 OK\|302 Found\|301 Moved"; then
        echo "✅"
    else
        echo "⚠️  (may not be accessible or may not have ARM64 packages)"
    fi
done

# Check required source files. Missing files are a validation failure:
# the previous version printed them but still exited 0 and announced
# that validation was complete.
echo ""
echo "📁 Checking required source files..."

required_files=(
    "src/athena-mirrorlist"
    "src/pacman.conf"
    "src/athena.gpg"
    "src/athena-trusted"
    "src/athena-revoked"
    "src/chaotic.gpg"
    "src/chaotic-trusted"
    "src/chaotic-revoked"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        missing_files=$((missing_files + 1))
    fi
done

echo ""
echo "🎯 Architecture-specific checks..."
echo "  Target architecture: aarch64 (ARM64)"
echo "  Base Fedora version: 40"

# Check for x86-only packages. Only the %packages section is scanned,
# and only whole package names match. The previous substring scan of
# the whole file flagged a line of the embedded PGP key block and a
# comment, and never flagged the one real x86-only entry, syslinux.
echo ""
echo "🔍 Scanning for x86-only packages..."
x86_packages=$(awk '/^%packages/,/^%end/' athena-iso.ks | grep -E "^(syslinux|syslinux-[a-z]+|microcode_ctl|intel-microcode|amd-ucode)$" || true)
if [ -n "$x86_packages" ]; then
    echo "⚠️  Found x86-only packages:"
    echo "$x86_packages"
    echo "   These have no aarch64 build and will fail the package step"
else
    echo "✅ No x86-only packages found"
fi

if [ "$missing_files" -gt 0 ]; then
    echo ""
    echo "❌ Validation failed: $missing_files required source file(s) missing"
    exit 1
fi

echo ""
echo "📊 Kickstart validation complete!"
echo ""
echo "🚀 To build the ISO:"
echo "   1. Push changes to GitHub"
echo "   2. Go to Actions tab in GitHub repository"
echo "   3. Run 'Build AthenaOS ARM64 ISO' workflow"
echo "   4. Download the built ISO from artifacts or releases"
