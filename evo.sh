#!/bin/bash

# ========================================================
#  SCRIPT CONFIGURATION
# ========================================================
START_TIME=$(date +%s)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# =========================================================
#  PHASE 1: ENVIRONMENT SANITIZATION (Critical)
# =========================================================
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset PYTHONPATH
unset CC
unset CXX
unset CFLAGS
unset LDFLAGS
export LC_ALL=C
unset JAVA_HOME

echo -e "${GREEN}✔ Environment Cleaned.${NC}"

# ========================================================
#  PHASE 2: CLEANUP & SYNC
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 1/5] Cleaning up old files...${NC}"
# Delete the entire output folder to remove "poisoned" config files
rm -rf out/

# Delete trees to ensure a fresh start
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
rm -rf .repo/local_manifests

echo -e "\n${BLUE}➜ [PHASE 2/5] Syncing Repositories...${NC}"
repo init -u https://github.com/Evolution-X/manifest -b bq1 --git-lfs
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
echo -e "${GREEN}✔ Sync Complete.${NC}"

# ========================================================
#  PHASE 3: CLONING SOURCES
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 3/5] Downloading Device Trees...${NC}"

# Keys
rm -rf vendor/evolution-priv/keys
git clone https://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@github.com/DEMONTHUNDER/my-private-keys.git vendor/evolution-priv/keys || echo "⚠️ Keys failed! Using public keys."

# Device & Vendor Trees
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b evo-perf device/oneplus/larry
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr1 device/oneplus/sm6375-common
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375_austen.git -b sixteen-qpr1 kernel/oneplus/sm6375
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr1 hardware/oplus

echo -e "${GREEN}✔ All downloads finished.${NC}"

# ========================================================
#  PHASE 4: NEUTRON SETUP (No CCACHE)
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 4/5] Setting up Environment...${NC}"

if [ ! -d "prebuilts/clang/host/linux-x86/neutron" ]; then
    mkdir -p prebuilts/clang/host/linux-x86/neutron
    cd prebuilts/clang/host/linux-x86/neutron
    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman -S --legacy 
    cd ../../../../../
fi

NEUTRON_PATH="$(pwd)/prebuilts/clang/host/linux-x86/neutron"
export PATH="${NEUTRON_PATH}/bin:$PATH"
export TARGET_KERNEL_CLANG_COMPILE=true
export TARGET_KERNEL_CLANG_VERSION=neutron
export TARGET_KERNEL_CLANG_PATH="${NEUTRON_PATH}"

# 🛑 CCACHE REMOVED: It was causing the "not found" error.

# ========================================================
#  PHASE 5: COMPILATION
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 5/5] Starting Build...${NC}"

. build/envsetup.sh

# Using Lineage naming (as required)
lunch lineage_larry-bp3a-userdebug

# ========================================================
#  🛑 NUCLEAR FIX V2 (EXECUTE RIGHT BEFORE BUILD) 🛑
# ========================================================
echo "Applying final environment sanitizer..."

# 1. Force Server Tools to use GCC (Prevents Error 139)
export HOSTCC=gcc
export HOSTCXX=g++

# 2. CLEAR FLAGS (This fixes the log seen in Image 1)
# We unset these AGAIN here because 'lunch' might have added them back.
unset HOSTLDFLAGS
unset LDFLAGS
unset CLANG_LDFLAGS
unset LD_LIBRARY_PATH

# 3. Double check cleanup
rm -rf out/target/product/larry/obj/KERNEL_OBJ
# ========================================================

echo "========================="
echo "Starting ROM Compilation..."
echo "========================="
m evolution -j$(nproc --all)

# ========================================================
#  FINISHED
# ========================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))
echo -e "\n${GREEN}✔ Build Completed in ${H}h ${M}m${NC}"
