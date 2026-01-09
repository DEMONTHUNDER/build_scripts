#!/bin/bash

# ========================================================
#  SCRIPT CONFIGURATION
# ========================================================
START_TIME=$(date +%s)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========================================================
#  PHASE 1: CLEANUP & SYNC
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 1/5] Cleaning up old files...${NC}"

# 1. Delete output (CRITICAL to remove poisoned config)
rm -rf out/

# 2. Delete trees to ensure fresh clones
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
rm -rf .repo/local_manifests

echo -e "\n${BLUE}➜ [PHASE 2/5] Syncing Repositories...${NC}"
repo init -u https://github.com/Evolution-X/manifest -b bq2 --git-lfs
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
echo -e "${GREEN}✔ Sync Complete.${NC}"

# ========================================================
#  PHASE 2: CLONING SOURCES
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 3/5] Downloading Device Trees...${NC}"

# Keys
rm -rf vendor/evolution-priv/keys
git clone https://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@github.com/DEMONTHUNDER/my-private-keys.git vendor/evolution-priv/keys || echo "⚠️ Keys failed! Using public keys."

# Device & Vendor Trees (Using 'evo-perf' and 'sixteen-qpr1' branches)
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b evo-perf device/oneplus/larry
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr1 device/oneplus/sm6375-common
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr1 kernel/oneplus/sm6375
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b lineage-23.2 hardware/oplus
echo -e "${GREEN}✔ All downloads finished.${NC}"
echo -e "\n${BLUE}➜ [PHASE 5/5] Starting Build...${NC}"
. build/envsetup.sh
export LLVM_ENABLE_LTO=false
export LLVM_USE_LINKER=lld
# Using Lineage naming
lunch lineage_larry-bp4a-userdebug

echo ">> Sanitizing Build Environment..."

# 3. Clean kernel objects to prevent using old broken files
rm -rf out/target/product/larry/obj/KERNEL_OBJ
# ========================================================
# 2. THE CLEAN STEP (Crucial for your tweaks to work)
# Use 'installclean' to save time, or 'clean' for total safety
echo "Cleaning old images to apply new tweaks..."
make installclean

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
