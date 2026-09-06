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



echo -e "\n${BLUE}➜ [PHASE 2/5] Syncing Repositories...${NC}"
repo init -u https://github.com/Evolution-X/manifest -b bq2 --git-lfs
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
echo -e "${GREEN}✔ Sync Complete.${NC}"

# ========================================================
#  PHASE 2: CLONING SOURCES
# ========================================================
echo -e "\n${BLUE}➜ [PHASE 3/5] Downloading Device Trees...${NC}"

# Device & Vendor Trees (Using 'evo-perf' and 'sixteen-qpr1' branches)
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b sixteen-qpr2 device/oneplus/larry
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common.git -b sixteen-qpr2 device/oneplus/sm6375-common
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr2 vendor/oneplus/larry
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr2 vendor/oneplus/sm6375-common
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr2 kernel/oneplus/sm6375
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr2 hardware/oplus

# Keys
rm -rf vendor/evolution-priv/keys
git clone https://github.com/DEMONTHUNDER/my-private-keys -b keys vendor/evolution-priv/keys || echo "⚠️ Keys failed! Using public keys."

echo -e "${GREEN}✔ All downloads finished.${NC}"
echo -e "\n${BLUE}➜ [PHASE 5/5] Starting Build...${NC}"




. build/envsetup.sh
# Using Lineage naming
lunch lineage_larry-bp4a-userdebug

echo "Cleaning old images to apply new tweaks..."
make installclean

echo "========================="
echo "Starting ROM Compilation..."
echo "========================="
m evolution -j$(nproc --all); if [ $? -eq 0 ]; then \
    echo "Build Successful! Installing uploader tools..."; \
    sudo apt install sshpass -y; \
    echo "Starting Upload..."; \
    export SSHPASS='sJuEw8mi.c:9Z7S'; \
    FILENAME=$(ls -t out/target/product/larry/EvolutionX*.zip | grep -v "md5" | head -n 1); \
    sshpass -e scp -o StrictHostKeyChecking=no "$FILENAME" demonthunder@frs.sourceforge.net:/home/frs/project/saket-builds/; \
    echo "Upload Complete!"; \
else \
    echo "Build Failed. Skipping install and upload."; \
fi

# ========================================================
#  FINISHED
# ========================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(( (ELAPSED % 3600) / 60 ))
echo -e "\n${GREEN}✔ Build Completed in ${H}h ${M}m${NC}"
