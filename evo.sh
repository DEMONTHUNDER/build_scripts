#!/bin/bash
#vars
sign=true
# Define colors to make logs easier to read
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Start the timer
START_TIME=$(date +%s)

#cleanup
CURRENT_PHASE="CLEANUP"
echo -e "\n${BLUE}➜ [PHASE 1/5] Cleaning up old files...${NC}"

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
echo -e "${GREEN}✔ Cleanup Complete.${NC}"

CURRENT_PHASE="REPO SYNC"
echo -e "\n${BLUE}➜ [PHASE 2/5] Syncing Repositories...${NC}"
#start rom build
repo init -u https://github.com/Evolution-X/manifest -b bq1 --git-lfs && \

# Resync sources
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
echo -e "${GREEN}✔ Sync Complete.${NC}"

CURRENT_PHASE="CLONING SOURCES"
echo -e "\n${BLUE}➜ [PHASE 3/5] Downloading Device Trees & Keys...${NC}"
#signing keys
echo -e "${YELLOW}>> Cloning Signing Keys...${NC}"
echo "🔑 Attempting to clone Private Keys..."
rm -rf vendor/evolution-priv/keys
git clone https://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@github.com/DEMONTHUNDER/my-private-keys.git vendor/evolution-priv/keys || echo "⚠️ Keys failed to download! Continuing with public Test-Keys..."

#clone device tree
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b evo-perf device/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr1 device/oneplus/sm6375-common && \

#clone vendor tree
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common && \

#clone kernel and hardware tree
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375_austen.git -b sixteen-qpr1 kernel/oneplus/sm6375 && \
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr1 hardware/oplus && \

echo -e "${GREEN}✔ All downloads finished.${NC}"

# ========================================================
#  NEW PHASE: NEUTRON CLANG SETUP
# ========================================================
CURRENT_PHASE="NEUTRON SETUP"
echo -e "\n${BLUE}➜ [PHASE 4/6] Setting up Neutron Clang...${NC}"
# Create directory
mkdir -p prebuilts/clang/host/linux-x86/neutron
cd prebuilts/clang/host/linux-x86/neutron

# Download AntMan and fetch toolchain
echo -e "${YELLOW}>> Fetching Neutron Toolchain (Stable)...${NC}"
curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
chmod +x antman
./antman -S
# Return to root
cd ../../../../../
echo -e "${GREEN}✔ Neutron Clang Installed.${NC}"

CURRENT_PHASE="COMPILATION"
echo -e "\n${BLUE}➜ [PHASE 5/5] Starting Build...${NC}"
# Setup the build environment
echo ">> Setting up environment..."
. build/envsetup.sh

# ========================================================
#  FORCE NEUTRON VARIABLES
# ========================================================
echo -e "${YELLOW}>> Exporting Neutron Compiler Variables...${NC}"
export TARGET_KERNEL_CLANG_COMPILE=true
export TARGET_KERNEL_CLANG_VERSION=neutron
export TARGET_KERNEL_CLANG_PATH=$(pwd)/prebuilts/clang/host/linux-x86/neutron
export LD_LIBRARY_PATH=$(pwd)/prebuilts/clang/host/linux-x86/neutron/lib:$LD_LIBRARY_PATH
echo "Environment setup success."

# Lunch before building
echo ">> Lunching target..."
lunch lineage_larry-bp3a-user
echo "Lunch command executed."

# Build ROM
echo ">> Compiling..."
echo "========================="
echo "Starting ROM Compilation..."
echo "========================="
m evolution -j$(nproc --all)

# ==========================================
#  SUCCESS
# ==========================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ BUILD SUCCESS! 🚀${NC}"
echo -e "${GREEN}Total Time: ${H}h ${M}m${NC}"
echo -e "${GREEN}========================================${NC}"
