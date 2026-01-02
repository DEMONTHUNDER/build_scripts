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

# =========================================================
#  ENVIRONMENT SANITIZATION (The "Safety" Block)
# =========================================================
# 1. Unset dangerous variables that break host tools
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset PYTHONPATH

# 2. Clear Compiler Flags (Let the ROM build system handle this)
unset CC
unset CXX
unset CPP
unset CFLAGS
unset CXXFLAGS
unset LDFLAGS

# 3. Clear Java/Locale junk
export LC_ALL=C
unset JAVA_HOME

echo -e "${GREEN}✔ Environment Cleaned. Ready to build.${NC}"
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
# --- PHASE 1: NEUTRON CLANG SETUP ---
echo -e "${BLUE}➜ [1/5] Setting up Neutron Clang...${NC}"

if [ ! -d "prebuilts/clang/host/linux-x86/neutron" ]; then
    mkdir -p prebuilts/clang/host/linux-x86/neutron
    cd prebuilts/clang/host/linux-x86/neutron
    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman -S --legacy 
    cd ../../../../../
fi
# 2. Set Variables (TARGET ONLY)
# We use absolute paths to be safe
NEUTRON_PATH="$(pwd)/prebuilts/clang/host/linux-x86/neutron"
export PATH="${NEUTRON_PATH}/bin:$PATH"
export TARGET_KERNEL_CLANG_COMPILE=true
export TARGET_KERNEL_CLANG_VERSION=neutron
export TARGET_KERNEL_CLANG_PATH="${NEUTRON_PATH}"
echo -e "${GREEN}✔ Neutron Clang Installed.${NC}"


CURRENT_PHASE="COMPILATION"
echo -e "\n${BLUE}➜ [PHASE 5/5] Starting Build...${NC}"

# Setup the build environment
echo ">> Setting up environment..."
. build/envsetup.sh
echo "Environment setup success."

# Lunch before building
echo ">> Lunching target..."
lunch lineage_larry-bp3a-userdebug
echo "Lunch command executed."

# ========================================================
#  🛑 NUCLEAR FIX FOR ERROR 139 (SEGFAULT) 🛑
# ========================================================
# 1. Clean broken kernel objects from previous run
rm -rf out/target/product/larry/obj/KERNEL_OBJ
rm -rf out/target/product/larry/obj/kernel

# 2. Sanitize Flags (Stop Server from using Neutron libs)
unset LDFLAGS
unset HOSTLDFLAGS
unset CLANG_LDFLAGS
unset LD_LIBRARY_PATH
# 3. Force Server to use Stable GCC
export HOSTCC=gcc
export HOSTCXX=g++
# ========================================================

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

