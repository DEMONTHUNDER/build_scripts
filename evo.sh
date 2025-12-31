#!/bin/bash
repo init -u https://github.com/Evolution-X/manifest -b bq1 --git-lfs && \

# Resync sources
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh 

git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b lineage-23.1 device/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr1 device/oneplus/sm6375-common && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common && \
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr1 kernel/oneplus/sm6375 && \
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr1 hardware/oplus && \

# Setup the build environment
. build/envsetup.sh
echo "Environment setup success."

# Lunch before building
lunch lineage_larry-bp3a-userdebug
echo "Lunch command executed."

# Build ROM
m evolution -j$(nproc --all)"
