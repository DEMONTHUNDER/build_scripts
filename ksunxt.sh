#!/bin/bash
set -e

# ========================================================
#  CONFIGURATION & DIRECTORIES
# ========================================================
START_TIME=$(date +%s)
WORKSPACE="$HOME/kernel-workspace"
CLANG_DIR="$WORKSPACE/clang-llvm"
KERNEL_DIR="$WORKSPACE/kernel"
ANYKERNEL_DIR="$WORKSPACE/AnyKernel3"

echo "➜ [1/7] Checking dependencies..."
if command -v pacman &> /dev/null; then
    sudo pacman -Sy --needed --noconfirm git bc bison flex make gcc perl zip tar wget libelf openssl aarch64-linux-gnu-gcc
fi

mkdir -p "$WORKSPACE" && cd "$WORKSPACE"

# ========================================================
#  TOOLCHAIN SETUP (Clang r487747c)
# ========================================================
echo "➜ [2/7] Fetching prebuilt Clang toolchain..."
if [ ! -d "$CLANG_DIR" ]; then
    git clone --depth=1 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r487747c.git "$CLANG_DIR"
fi

# ========================================================
#  KERNEL SOURCE SETUP
# ========================================================
echo "➜ [3/7] Fetching SM6375 tree..."
if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth=1 https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr2 "$KERNEL_DIR"
fi

cd "$KERNEL_DIR"

# ========================================================
#  INTEGRATE KERNELSU-NEXT (Built-in Mode)
# ========================================================
echo "➜ [4/7] Setting up KernelSU-Next..."
if [ ! -d "drivers/kernelsu" ]; then
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s next
fi

# ========================================================
#  INTEGRATE SUSFS (5.4 Branch)
# ========================================================
echo "➜ [5/7] Integrating SuSFS for 5.4-qgki..."
if [ ! -d "$WORKSPACE/susfs4ksu" ]; then
    git clone -b kernel-5.4 https://gitlab.com/simonpunk/susfs4ksu.git "$WORKSPACE/susfs4ksu"
fi

cp -rf "$WORKSPACE/susfs4ksu/kernel_patches/fs"/* fs/
cp -rf "$WORKSPACE/susfs4ksu/kernel_patches/include/linux"/* include/linux/

if ! grep -q "CONFIG_KSU_SUSFS" fs/Makefile 2>/dev/null; then
    patch -p1 --forward --batch < "$WORKSPACE/susfs4ksu/kernel_patches/50_add_susfs_in_kernel-5.4.patch" || true
fi

# ========================================================
#  INJECT DEFCONFIG (KSU + SUSFS + LOW-LATENCY BOOST)
# ========================================================
echo "➜ [6/7] Injecting configs into holi-qgki_defconfig..."
DEFCONFIG="arch/arm64/configs/vendor/holi-qgki_defconfig"

# Strip duplicate old flags if re-running
sed -i '/CONFIG_KSU/d' "$DEFCONFIG"
sed -i '/CONFIG_PREEMPT/d' "$DEFCONFIG"

cat << 'EOF' >> "$DEFCONFIG"

# --- KernelSU-Next & SuSFS ---
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

# --- Performance & Low Latency ---
CONFIG_PREEMPT=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZRAM_WRITEBACK=y
EOF

# ========================================================
#  COMPILATION (6 Threads for smooth Hyprland multitasking)
# ========================================================
echo "➜ [7/7] Compiling Kernel..."
export PATH="$CLANG_DIR/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="DemonThunder"
export KBUILD_BUILD_HOST="Cosmic"

make O=out clean
make O=out holi-qgki_defconfig
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
#  ANYKERNEL3 PACKAGING
# ========================================================
cd "$WORKSPACE"
if [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image.gz" ] || [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image" ]; then
    echo "✔ Kernel compiled successfully. Packaging AnyKernel3 ZIP..."
    rm -rf "$ANYKERNEL_DIR"
    git clone https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
    
    # Configure AnyKernel3 for Larry
    sed -i 's/device.name1=.*/device.name1=larry/g' "$ANYKERNEL_DIR/anykernel.sh"
    sed -i 's/block=.*/block=auto/g' "$ANYKERNEL_DIR/anykernel.sh"
    sed -i 's/is_slot_device=0/is_slot_device=1/g' "$ANYKERNEL_DIR/anykernel.sh"

    if [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image.gz" ]; then
        cp "$KERNEL_DIR/out/arch/arm64/boot/Image.gz" "$ANYKERNEL_DIR/"
    else
        cp "$KERNEL_DIR/out/arch/arm64/boot/Image" "$ANYKERNEL_DIR/"
    fi

    # Include DTB if built
    if [ -f "$KERNEL_DIR/out/arch/arm64/boot/dtb.img" ]; then
        cp "$KERNEL_DIR/out/arch/arm64/boot/dtb.img" "$ANYKERNEL_DIR/dtb"
    elif [ -f "$KERNEL_DIR/out/arch/arm64/boot/dtb" ]; then
        cp "$KERNEL_DIR/out/arch/arm64/boot/dtb" "$ANYKERNEL_DIR/dtb"
    fi

    cd "$ANYKERNEL_DIR"
    zip -r9 "$WORKSPACE/KSU-Next-Susfs-Larry.zip" * -x .git README.md *placeholder
    
    ELAPSED=$(( $(date +%s) - START_TIME ))
    echo -e "\n============================================="
    echo "✔ SUCCESS in $((ELAPSED / 60))m $((ELAPSED % 60))s!"
    echo "Flashable ZIP: $WORKSPACE/KSU-Next-Susfs-Larry.zip"
    echo "============================================="
else
    echo "❌ Build failed. Check terminal error log."
    exit 1
fi
