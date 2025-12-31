#!/bin/bash
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
repo init -u https://github.com/Project-Mica/manifest -b 16-qpr2 && \

# Resync sources
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh 

#clone device tree
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b mica_os device/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr1 device/oneplus/sm6375-common && \

#clone vendor tree
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common && \

#clone kernel and hardware tree
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr1 kernel/oneplus/sm6375 && \
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b lineage23.2 hardware/oplus && \

# Setup the build environment
. build/envsetup.sh
echo "Environment setup success."


#gms 
cd vendor/gms
bash generate-gms.sh

# Lunch before building
lunch mica_larry-bp4a-userdebug
echo "Lunch command executed."

# Build ROM
echo "========================="
echo "Starting ROM Compilation..."
echo "========================="
m mica-release -j$(nproc --all)
