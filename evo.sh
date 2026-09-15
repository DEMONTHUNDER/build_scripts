#!/bin/bash

# ========================================================
#  SCRIPT CONFIGURATION
# ========================================================
START_TIME=$(date +%s)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ========================================================
#  PHASE 1: TARGETED CLEANUP (PREVENT TREE CONFLICTS)
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 1/5] Cleaning old trees and Soong cache...${NC}"
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
# Remove broken Evo-X LFS vendor_gms directory if it exists from previous runs
rm -rf vendor/gms .repo/projects/vendor/gms.git

# ========================================================
#  PHASE 3: SOURCE SYNC
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 3/5] Syncing Evolution X Repositories...${NC}"
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs
/opt/crave/resync.sh
repo sync -c -j$(nproc --all) --force-sync --force-remove-dirty --no-clone-bundle --no-tags
/opt/crave/resync.sh
echo -e "${GREEN}✔ Sync Complete.${NC}"

# ========================================================
#  PHASE 4: CLONING DEVICE TREES
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 4/5] Downloading Device Trees...${NC}"
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b sixteen-qpr2 device/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr2 device/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b lineage-23.2 vendor/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b lineage-23.2 vendor/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b lineage-23.2 kernel/oneplus/sm6375 --depth=1
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr2 hardware/oplus --depth=1
echo -e "${GREEN}✔ All repositories cloned successfully.${NC}"

# ========================================================
#  PHASE 5: ENVIRONMENT & BUILDS
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 5/5] Setting up build environment...${NC}"
. build/envsetup.sh

# --- BUILD 1: VANILLA ---
echo "========================================="
echo "  Starting Evolution X (Vanilla Build)"
echo "========================================="
export WITH_GMS=false
lunch lineage_larry-bp4a-userdebug
make installclean
m evolution -j$(nproc --all)

# Move or rename the output zip so it doesn't get overwritten
mkdir -p out/artifacts
mv out/target/product/larry/EvolutionX*.zip out/artifacts/ 2>/dev/null || true

# --- BUILD 2: GAPPS ---
echo "========================================="
echo "  Starting Evolution X (GApps Build)"
echo "========================================="
export WITH_GMS=true
lunch lineage_larry-bp4a-userdebug
make clean
m evolution -j$(nproc --all)

# Move GApps build zip
mv out/target/product/larry/EvolutionX*.zip out/artifacts/ 2>/dev/null || true

# ========================================================
#  EXECUTION TIME BREAKDOWN
# ========================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))
echo -e "\n${GREEN}✔ Both builds finished in ${H}h ${M}m${NC}"
