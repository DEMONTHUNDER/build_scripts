#!/bin/bash

# ========================================================
#  PHASE 1: NUCLEAR CLEANUP
# ========================================================
echo "➜ Cleaning up old environment..."

# Delete output and trees to prevent poisoned caches and git conflicts
rm -rf out/
rm -rf out/target/product/larry/obj/KERNEL_OBJ
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
rm -rf .repo/local_manifests

# ========================================================
#  PHASE 2: HIGH-EFFICIENCY SYNC
# ========================================================
echo "➜ Syncing RisingOS Source..."

# Using --depth=1 saves bandwidth. We only need the latest commit.
repo init -u https://github.com/RisingOS-Revived/android -b seventeen --git-lfs --depth=1

# Aggressive sync: forces sync, skips clone bundles, optimized fetch
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
/opt/crave/resync.sh

echo "✔ Source Sync Complete."

# ========================================================
#  PHASE 3: FAST DEVICE TREE CLONING
# ========================================================
echo "➜ Downloading Device Trees..."

# --depth=1 slashes download times from minutes to seconds
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b sixteen-qpr2 device/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr2 device/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr2 vendor/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr2 vendor/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr2 kernel/oneplus/sm6375 --depth=1
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr2 hardware/oplus --depth=1

echo "✔ Trees successfully cloned."

# ========================================================
#  PHASE 4: CCACHE SAFEGUARD & CONFIG
# ========================================================
echo "➜ Configuring Ccache..."

# Safe check: Only use ccache if the binary actually exists and is executable
if command -v ccache >/dev/null 2>&1; then
    export USE_CCACHE=1
    export CCACHE_EXEC=$(which ccache)
    export CCACHE_COMPRESS=1
    export CCACHE_MAXSIZE=50G
    ccache -M 50G
    echo "✔ Ccache enabled and configured."
else
    export USE_CCACHE=0
    echo "⚠️ Ccache not found or broken. Safely falling back to a standard build."
fi

# ========================================================
#  PHASE 5: SAFE BUILD & OPTIMIZATIONS
# ========================================================
echo "➜ Applying Tweaks & Starting Build..."

export KBUILD_BUILD_USER="DemonThunder"
export KBUILD_BUILD_HOST="Crave-Build"
export BUILD_USERNAME="DemonThunder"
export BUILD_HOSTNAME="Crave-Build"

# Full GApps configuration for RisingOS
export WITH_GMS=true
export TARGET_BUILD_VARIANT=userdebug

# Initialize the build environment
. build/envsetup.sh

# RisingOS wrapper targets your device
riseup larry userdebug

echo "========================================="
echo "  Starting RisingOS Compilation (Full GApps)"
echo "========================================="

# 'rise b' executes the build using all available Crave cores
rise b

# Clean exit logic without uploads
if [ $? -eq 0 ]; then
    echo "✔ Build Successful! Locating output..."
    FILENAME=$(ls -t out/target/product/larry/RisingOS*.zip | grep -v "md5" | head -n 1)
    
    if [ -f "$FILENAME" ]; then
        echo "✔ ROM compiled successfully! You can find it at: $FILENAME"
    else
        echo "❌ Build finished but ZIP file was not found in the output directory."
    fi
else
    echo "❌ Build Failed. Please check the error logs above."
fi
M=$(( (ELAPSED % 3600) / 60 ))
echo -e "\n${GREEN}✔ Build Completed in ${H}h ${M}m${NC}"
