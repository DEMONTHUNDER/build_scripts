

repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen-qpr1 --git-lfs && \
/opt/crave/resync.sh && \
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_larry.git -b pixelos16 device/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/android_device_oneplus_sm6375-common_austen.git -b sixteen-qpr1 device/oneplus/sm6375-common && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_larry.git -b sixteen-qpr1 vendor/oneplus/larry && \
git clone https://github.com/DEMONTHUNDER/proprietary_vendor_oneplus_sm6375-common.git -b sixteen-qpr1 vendor/oneplus/sm6375-common && \
git clone https://github.com/DEMONTHUNDER/android_kernel_oneplus_sm6375.git -b sixteen-qpr1 kernel/oneplus/sm6375 && \
git clone https://github.com/DEMONTHUNDER/android_hardware_oplus.git -b sixteen-qpr1 hardware/oplus && \
. build/envsetup.sh && \
lunch custom_larry-bp3a-user && \
m pixelos -j$(nproc --all)"
