#!/bin/bash

# ========================================================
#  SCRIPT CONFIGURATION
# ========================================================
START_TIME=$(date +%s)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================
# 1. Memory Safety & Soong Pre-Flight Config (Top of Script)
# ============================================================
# Remove dirty/corrupted blueprint intermediate outputs
rm -rf out/soong/build.lineage_larry.ninja out/soong/.bootstrap

# 1. Force Go garbage collector to cap memory at 8GB (Stops soong OOM)
export GOMEMLIMIT=8GiB
export GOGC=50

# 2. JVM cap & dependency resolution
export _JAVA_OPTIONS="-Xmx6g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
# ========================================================
#  PHASE 1: TARGETED CLEANUP (PREVENT TREE CONFLICTS)
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 1/5] Cleaning old trees and Soong cache...${NC}"
rm -rf device/oneplus/larry device/oneplus/sm6375-common
rm -rf vendor/oneplus/larry vendor/oneplus/sm6375-common
rm -rf kernel/oneplus/sm6375 hardware/oplus
rm -rf device/oneplus/larry                                                                                                                                                                   
rm -rf device/oneplus/sm6375-common                                                                                                                                                           
rm -rf hardware/oplus                                                                                                                                                                         
rm -rf kernel/oneplus/sm6375                                                                                                                                                                  
rm -rf vendor/oneplus/larry                                                                                                                                                                   
rm -rf vendor/oneplus/sm6375-common                                                                                                                                                           
rm -rf out/soong/build.lineage_larry.ninja out/soong/.bootstrap out/soong/.minibootstrap
# Remove broken Evo-X LFS vendor_gms directory if it exists from previous runs
rm -rf vendor/gms .repo/projects/vendor/gms.git
# ========================================================
#  PHASE 3: SOURCE SYNC
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 3/5] Syncing Evolution X Repositories...${NC}"
repo init -u https://github.com/Evolution-X/manifest -b cnb --git-lfs --depth=1

/opt/crave/resync.sh
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle # For fixing sync error
echo -e "${GREEN}✔ Sync Complete.${NC}"
# ========================================================
#  PHASE 4: CLONING DEVICE TREES
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 4/5] Downloading Device Trees...${NC}"
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b a17evox device/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b a17 device/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b a17 vendor/oneplus/larry --depth=1
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b a17 vendor/oneplus/sm6375-common --depth=1
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b a17 kernel/oneplus/sm6375 --depth=1
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b a17 hardware/oplus --depth=1
echo -e "${GREEN}✔ All repositories cloned successfully.${NC}"

# ============================================================
# 2. ccache Configuration
# ============================================================
# Ensure ccache is present in the container
if ! command -v ccache &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y ccache
fi

export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR="${HOME}/.ccache"
ccache -M 50G
ccache -o compression=true

# Configure cache size and enable compression
ccache -M 50G
ccache -o compression=true

# Zero stats at the start so you can inspect hits after the run
ccache -z

. build/envsetup.sh

lunch lineage_larry-cp2a-userdebug

m evolution
# ========================================================
#  EXECUTION TIME BREAKDOWN
# ========================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))
echo -e "\n${GREEN}✔ Both builds finished in ${H}h ${M}m${NC}"
