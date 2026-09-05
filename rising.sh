#!/bin/bash

START_TIME=$(date +%s)


# ========================================================
#  PHASE 2: HIGH-EFFICIENCY SYNC
# ========================================================
echo "➜ Syncing RisingOS Source..."

repo init -u https://github.com/RisingOS-Revived/android -b seventeen --git-lfs --depth=1
/opt/crave/resync.sh

echo "✔ Source Sync Complete."


# ========================================================
#  PHASE 3: CLEAN & CLONE DEVICE TREES
# ========================================================
echo "➜ Cleaning and downloading device trees..."
export GOMAXPROCS=4
export GOGC=50
rm -rf out/soong
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
rm -rf .repo/local_manifests
# ========================================================
#  PHASE 3: FAST DEVICE TREE CLONING
# ========================================================
echo "➜ Downloading Device Trees..."

git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b rising device/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr2 device/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr2 vendor/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr2 vendor/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr2 kernel/oneplus/sm6375 --depth=1
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr2 hardware/oplus --depth=1

echo "✔ Trees successfully cloned."


. build/envsetup.sh

# Commands verified against official RisingOS docs
riseup larry user

# Generate release keys to replace testkey (matches Rising documentation)
echo "➜ Generating release keys for Play Integrity..."
gk -s

echo "========================================="
echo "  Starting RisingOS Compilation"
echo "========================================="

rise b

if [ $? -eq 0 ]; then
    echo "✔ Build Successful! Locating output..."
    FILENAME=$(ls -t out/target/product/larry/RisingOS*.zip | grep -v "md5" | head -n 1)
    
    if [ -f "$FILENAME" ]; then
        echo "✔ ROM compiled successfully! Output file: $FILENAME"
    else
        echo "❌ Build finished but ZIP file was not found."
    fi
else
    echo "❌ Build Failed. Please inspect the build logs above."
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))
echo "✔ Total execution time: ${H}h ${M}m"
