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
echo -e "\n${BLUE}➜ [PHASE 1/4] Cleaning old trees and Soong cache...${NC}"
# Remove tree directories to prevent git clone 'already exists' errors
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
# ========================================================
#  PHASE 2: SOURCE SYNC
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 2/4] Syncing Evolution X Repositories...${NC}"
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
echo -e "${GREEN}✔ Sync Complete.${NC}"
# ========================================================
#  PHASE 3: CLONING TREES
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 3/4] Downloading Device Trees...${NC}"
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b sixteen-qpr2 device/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr2 device/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b lineage-23.2 vendor/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b lineage-23.2 vendor/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b lineage-23.2 kernel/oneplus/sm6375 --depth=1
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git  -b sixteen-qpr2 hardware/oplus --depth=1
echo -e "${GREEN}✔ All repositories cloned successfully.${NC}"
# ========================================================
#  PHASE 4: ENVIRONMENT & BUILD
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 4/4] Setting up environment & starting compilation...${NC}"
. build/envsetup.sh
lunch lineage_larry-bp4a-user
echo -e "${BLUE}➜ Running installclean...${NC}"

make installclean

echo "========================================="
echo "  Starting Evolution X Compilation"
echo "========================================="

m evolution -j$(nproc --all)
# ========================================================
#  EXECUTION TIME BREAKDOWN
# ========================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))
echo -e "\n${GREEN}✔ Process finished in ${H}h ${M}m${NC}"
