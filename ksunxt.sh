#!/usr/bin/env bash
set -e

# ========================================================
#  1. WORKSPACE & DEPENDENCIES
# ========================================================
START_TIME=$(date +%s)
WORKSPACE="$HOME/kernel_workspace"
CLANG_DIR="$WORKSPACE/toolchains/clang-aosp"
KERNEL_DIR="$WORKSPACE/sm6375_kernel"
ANYKERNEL_DIR="$WORKSPACE/AnyKernel3"

# Set your A17 branch name here (e.g., 'seventeen', 'a17', or 'android-17')
A17_BRANCH="seventeen" 

echo "➜ Checking CachyOS dependencies..."
if command -v pacman &> /dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel bc bison flex ccache \
        gcc perl zip tar wget libelf openssl aarch64-linux-gnu-gcc arm-none-eabi-gcc
fi

mkdir -p "$WORKSPACE/toolchains" && cd "$WORKSPACE"

# ========================================================
#  2. TOOLCHAIN FETCH (AOSP Clang)
# ========================================================
echo "➜ Fetching AOSP Clang..."
if [ ! -d "$CLANG_DIR" ]; then
    git clone --depth=1 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r487747c.git "$CLANG_DIR"
fi

# ========================================================
#  3. KERNEL SOURCE (A17 Trees)
# ========================================================
echo "➜ Fetching OnePlus SM6375 A17 Tree..."
if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth=1 https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b "$A17_BRANCH" "$KERNEL_DIR"
fi

cd "$KERNEL_DIR"

# ========================================================
#  4. KERNELSU-NEXT (v3.3.0) & SUSFS (Latest 2.2.x capabilities)
# ========================================================
echo "➜ Fetching KernelSU-Next v3.3.0..."
if [ ! -d "drivers/kernelsu" ]; then
    # Hardcoding the v3.3.0 tag for both the script source and the checkout target
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/v3.3.0/kernel/setup.sh" | bash -s v3.3.0
fi

echo "➜ Fetching SuSFS for 5.4..."
if [ ! -d "$WORKSPACE/susfs4ksu" ]; then
    # The kernel-5.4 branch contains the structural patches needed for 5.4, updated for newer SuSFS versions
    git clone --depth=1 -b kernel-5.4 https://gitlab.com/simonpunk/susfs4ksu.git "$WORKSPACE/susfs4ksu"
fi

# ========================================================
#  5. THE INTEGRATION (Kernel + KSU Patching)
# ========================================================
echo "➜ Applying SuSFS patches..."

cp -f "$WORKSPACE/susfs4ksu/kernel_patches/fs/susfs.c" fs/
cp -f "$WORKSPACE/susfs4ksu/kernel_patches/include/linux/susfs.h" include/linux/
cp -f "$WORKSPACE/susfs4ksu/kernel_patches/include/linux/sus_su.h" include/linux/ 2>/dev/null || true

if ! grep -q "CONFIG_KSU_SUSFS" fs/Makefile 2>/dev/null; then
    patch -p1 --forward --batch < "$WORKSPACE/susfs4ksu/kernel_patches/50_add_susfs_in_kernel-5.4.patch" || true
fi

# Patch KernelSU-Next directly
cp -f "$WORKSPACE/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" drivers/kernelsu/
cd drivers/kernelsu
if [ -f "10_enable_susfs_for_ksu.patch" ] && ! grep -q "susfs" ksu.c 2>/dev/null; then
    patch -p1 --forward --batch < 10_enable_susfs_for_ksu.patch || true
fi
cd "$KERNEL_DIR"

# ========================================================
#  6. DEFCONFIG INJECTION (Privacy + Performance)
# ========================================================
echo "➜ Injecting tweaks into defconfig..."
DEFCONFIG_FILE="arch/arm64/configs/vendor/holi-qgki_defconfig"

sed -i '/CONFIG_KSU/d' "$DEFCONFIG_FILE"
sed -i '/CONFIG_AUDIT/d' "$DEFCONFIG_FILE"

cat << 'EOF' >> "$DEFCONFIG_FILE"

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
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_ENABLE_LOG=n

# --- Anti-Detection & Privacy ---
# CONFIG_AUDIT is not set
# CONFIG_KALLSYMS_ALL is not set
# CONFIG_FTRACE is not set

# --- Performance & Low Latency ---
CONFIG_PREEMPT=y
CONFIG_HZ_300=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZRAM_WRITEBACK=y
EOF

# ========================================================
#  7. COMPILATION
# ========================================================
echo "➜ Building the Kernel..."
export PATH="$CLANG_DIR/bin:$PATH"
THREADS=$(( $(nproc --all) - 2 )) 

make O=out clean
make O=out holi-qgki_defconfig
make O=out -j"$THREADS" \
    ARCH=arm64 \
    SUBARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-none-eabi- \
    LLVM=1

# ========================================================
#  8. ANYKERNEL3 PACKAGING
# ========================================================
cd "$WORKSPACE"
IMAGE_GZ="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"

if [ -f "$IMAGE_GZ" ]; then
    echo "✔ Kernel compiled. Packaging AnyKernel3..."
    rm -rf "$ANYKERNEL_DIR"
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
    
    # Configure for OnePlus Nord CE 3 Lite (larry)
    sed -i 's/device.name1=.*/device.name1=larry/g' "$ANYKERNEL_DIR/anykernel.sh"
    sed -i 's/block=.*/block=by-name\/boot/g' "$ANYKERNEL_DIR/anykernel.sh"
    sed -i 's/is_slot_device=0/is_slot_device=1/g' "$ANYKERNEL_DIR/anykernel.sh"

    cp "$IMAGE_GZ" "$ANYKERNEL_DIR/"

    cd "$ANYKERNEL_DIR"
    zip -r9 "$WORKSPACE/Larry-A17-KSUNext3.3-SuSFS2.2.zip" * -x .git README.md *placeholder
    
    ELAPSED=$(( $(date +%s) - START_TIME ))
    echo -e "\n============================================="
    echo "✔ SUCCESS in $((ELAPSED / 60))m $((ELAPSED % 60))s!"
    echo "Flashable ZIP: $WORKSPACE/Larry-A17-KSUNext3.3-SuSFS2.2.zip"
    echo "============================================="
else
    echo "❌ Build failed. Check the logs above."
    exit 1
fi
