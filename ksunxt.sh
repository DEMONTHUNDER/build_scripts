#!/bin/bash
set -e

# ========================================================
#  CONFIGURATION & PATHS
# ========================================================
START_TIME=$(date +%s)
WORKSPACE="$HOME/kernel-workspace"
CLANG_DIR="$WORKSPACE/clang-llvm"
KERNEL_DIR="$WORKSPACE/kernel"
ANYKERNEL_DIR="$WORKSPACE/AnyKernel3"

echo "➜ [1/6] Setting up build dependencies..."
# Detect package manager
if command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm git bc bison flex make gcc perl zip tar wget libelf openssl
elif command -v dnf &> /dev/null; then
    sudo dnf install -y git bc bison flex openssl-devel elfutils-libelf-devel make gcc perl zip tar wget
fi

mkdir -p "$WORKSPACE" && cd "$WORKSPACE"

# ========================================================
#  CLONE TOOLCHAIN & KERNEL
# ========================================================
echo "➜ [2/6] Fetching toolchain and SM6375 tree..."
if [ ! -d "$CLANG_DIR" ]; then
    git clone --depth=1 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r487747c.git "$CLANG_DIR"
fi

if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth=1 https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr2 "$KERNEL_DIR"
fi

cd "$KERNEL_DIR"

# ========================================================
#  INTEGRATE KERNELSU-NEXT (NON-GKI DRIVER INTEGRATION)
# ========================================================
echo "➜ [3/6] Integrating KernelSU-Next..."
if [ ! -d "drivers/kernelsu" ]; then
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s next
fi

# ========================================================
#  INTEGRATE SUSFS (5.4 NON-GKI TREE)
# ========================================================
echo "➜ [4/6] Applying SuSFS 5.4 Patches..."
if [ ! -d "$WORKSPACE/susfs4ksu" ]; then
    git clone -b kernel-5.4 https://gitlab.com/simonpunk/susfs4ksu.git "$WORKSPACE/susfs4ksu"
fi

# Copy SuSFS kernel files
cp -rf "$WORKSPACE/susfs4ksu/kernel_patches/fs"/* fs/
cp -rf "$WORKSPACE/susfs4ksu/kernel_patches/include/linux"/* include/linux/

# Apply SuSFS patches cleanly if not already applied
if ! grep -q "CONFIG_KSU_SUSFS" fs/Makefile 2>/dev/null; then
    patch -p1 --forward < "$WORKSPACE/susfs4ksu/kernel_patches/50_add_susfs_in_kernel-5.4.patch" || echo "Note: Check if patch applied with fuzzy offset."
fi

# ========================================================
#  INJECT DEFCONFIG: KSU + SUSFS + STABLE BOOST
# ========================================================
echo "➜ [5/6] Appending safe Non-GKI configs..."
# Identify config file
DEFCONFIG_PATH=$(ls arch/arm64/configs/vendor/*larry* 2>/dev/null || ls arch/arm64/configs/vendor/*holi* 2>/dev/null | head -n 1)
DEFCONFIG_NAME=$(basename "$DEFCONFIG_PATH")

cat << 'EOF' >> "$DEFCONFIG_PATH"

# ==========================================
# NON-GKI KSU-NEXT & SUSFS INTEGRATION
# ==========================================
CONFIG_KSU=y
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=n
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y

# ==========================================
# STABLE NON-GKI PERFORMANCE & LATENCY BOOST
# ==========================================
CONFIG_PREEMPT=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZRAM_WRITEBACK=y
# Strip overhead tracing
# CONFIG_DEBUG_KERNEL is not set
# CONFIG_FTRACE is not set
EOF

# ========================================================
#  BUILD KERNEL COMPILATION
# ========================================================
echo "➜ [6/6] Compiling SM6375 Kernel..."
export PATH="$CLANG_DIR/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="DemonThunder"
export KBUILD_BUILD_HOST="Local-Linux"

make O=out clean
make O=out "$DEFCONFIG_NAME"
make O=out -j6 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-gnu- \
    LLVM=1 \
    LLVM_IAS=1

# ========================================================
#  PACKAGE OUTPUT
# ========================================================
cd "$WORKSPACE"
if [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image.gz" ] || [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image" ]; then
    echo "✔ Binary built. Preparing flashable zip..."
    rm -rf "$ANYKERNEL_DIR"
    git clone https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
    sed -i 's/device.name1=.*/device.name1=larry/g' "$ANYKERNEL_DIR/anykernel.sh"
    sed -i 's/block=.*/block=auto/g' "$ANYKERNEL_DIR/anykernel.sh"
    
    if [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image.gz" ]; then
        cp "$KERNEL_DIR/out/arch/arm64/boot/Image.gz" "$ANYKERNEL_DIR/"
    else
        cp "$KERNEL_DIR/out/arch/arm64/boot/Image" "$ANYKERNEL_DIR/"
    fi
    
    # Include dtb/dtbo if compiled
    if [ -f "$KERNEL_DIR/out/arch/arm64/boot/dtb" ]; then
        cp "$KERNEL_DIR/out/arch/arm64/boot/dtb" "$ANYKERNEL_DIR/"
    fi

    cd "$ANYKERNEL_DIR"
    zip -r9 "$WORKSPACE/KSU-Next-Susfs-Larry.zip" * -x .git README.md *placeholder
    
    ELAPSED=$(( $(date +%s) - START_TIME ))
    echo -e "\n============================================="
    echo "✔ Done in $((ELAPSED / 60))m $((ELAPSED % 60))s"
    echo "Flashable ZIP: $WORKSPACE/KSU-Next-Susfs-Larry.zip"
    echo "============================================="
else
    echo "❌ Kernel output image not found. Compilation failed."
    exit 1
fi
