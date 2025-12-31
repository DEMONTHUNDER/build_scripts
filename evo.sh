#!/bin/bash
#vars
sign=true
#cleanup
# 1. Delete the Build Output
rm -rf out/target/product/larry

# 2. Delete the Device/Vendor Trees (So you can clone them fresh)
rm -rf device/oneplus/larry
rm -rf device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry
rm -rf vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375
rm -rf hardware/oplus

# 3. Clean the 'local_manifests' (Just in case you added bad repos there)
rm -rf .repo/local_manifests

#start rom build
repo init -u https://github.com/Evolution-X/manifest -b bq1 --git-lfs && \

# Resync sources
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh

#signing keys
echo "🔑 Attempting to clone Private Keys..."
rm -rf vendor/evolution-priv/keys
git clone https://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@github.com/DEMONTHUNDER/my-private-keys.git vendor/evolution-priv/keys || echo "⚠️ Keys failed to download! Continuing with public Test-Keys..."

#clone device tree
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b lineage-23.1 device/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr1 device/oneplus/sm6375-common && \

#clone vendor tree
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common && \

#clone kernel and hardware tree
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr1 kernel/oneplus/sm6375 && \
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr1 hardware/oplus && \

# Setup the build environment
. build/envsetup.sh
echo "Environment setup success."

# Lunch before building
lunch lineage_larry-bp3a-userdebug
echo "Lunch command executed."

# Build ROM
echo "========================="
echo "Starting ROM Compilation..."
echo "========================="
m evolution -j$(nproc --all)
