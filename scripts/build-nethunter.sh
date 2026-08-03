#!/bin/bash
################################################################################
# NetHunter Kernel Build Script for Samsung Galaxy Tab S8 (gts8wifi/SM-X700)
# Chipset: SM8450 (Snapdragon 8 Gen 1)
# Android Version: 12/13/14 (One UI 4.1/5.0/6.0)
# Kernel Version: 5.10.x
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default configuration
KERNEL_SOURCE_URL="https://github.com/ben443/gts8-sm8450-kernel-platform.git"
KERNEL_BRANCH="main"
DEVICE_CODENAME="gts8wifi"
DEVICE_MODEL="SM-X700"
CHIPSET="SM8450"
ANDROID_VERSION="13"

# GKI (Generic Kernel Image) Configuration
GKI_ENABLE="true"
GKI_DEFCONFIG="gki_defconfig"
VENDOR_DEFCONFIG="gts8wifi_defconfig"
DEFCONFIG="${VENDOR_DEFCONFIG}"

# Build directories
BUILD_DIR="${SCRIPT_DIR}/build"
KERNEL_DIR="${REPO_ROOT}/kernel_platform/common"
TOOLCHAIN_DIR="${BUILD_DIR}/toolchains"
OUTPUT_DIR="${SCRIPT_DIR}/output"
MODULES_DIR="${OUTPUT_DIR}/modules"
GKI_DIR="${OUTPUT_DIR}/gki"
VENDOR_DIR="${OUTPUT_DIR}/vendor"

# Toolchain URLs
AARCH64_GCC_URL="https://kali.download/nethunter-images/toolchains/linaro-aarch64-5.5.tar.xz"
ARM_GCC_URL="https://kali.download/nethunter-images/toolchains/linaro-armhf-5.5.tar.xz"
CLANG_URL="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b/archive/refs/heads/lineage-20.0.tar.gz"

# Number of parallel jobs
JOBS=$(nproc --all)

################################################################################
# Helper Functions
################################################################################

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║           NetHunter Kernel Builder for Samsung Galaxy Tab S8                 ║"
    echo "║                      gts8wifi (SM-X700) - SM8450                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

################################################################################
# GKI Specific Functions
################################################################################

check_gki_support() {
    log_step "Checking GKI support..."
    
    cd "${KERNEL_DIR}"
    
    # Check if GKI defconfig exists
    if [ -f "arch/arm64/configs/${GKI_DEFCONFIG}" ]; then
        log_info "GKI defconfig found: ${GKI_DEFCONFIG}"
        GKI_ENABLE="true"
    elif [ -f "arch/arm64/configs/gki_defconfig" ]; then
        GKI_DEFCONFIG="gki_defconfig"
        log_info "GKI defconfig found: ${GKI_DEFCONFIG}"
        GKI_ENABLE="true"
    else
        log_warn "GKI defconfig not found. Falling back to legacy build."
        GKI_ENABLE="false"
    fi
    
    # Check for vendor module support
    if [ -d "${KERNEL_DIR}/drivers/staging/gki" ] || [ -f "${KERNEL_DIR}/Kbuild.gki" ]; then
        log_info "GKI vendor module support detected"
        GKI_BUILD_VENDOR_MODULES="true"
    else
        GKI_BUILD_VENDOR_MODULES="false"
    fi
    
    log_info "GKI Enabled: ${GKI_ENABLE}"
    log_info "Vendor Modules: ${GKI_BUILD_VENDOR_MODULES}"
}

configure_gki_kernel() {
    log_step "Configuring GKI kernel..."
    
    cd "${KERNEL_DIR}"
    
    # For GKI, we use the GKI defconfig as base
    log_info "Using GKI defconfig: ${GKI_DEFCONFIG}"
    make "${GKI_DEFCONFIG}"
    
    # Keep base GKI config; NetHunter fragment is merged later in configure_kernel
    make olddefconfig
    
    log_info "GKI kernel base configuration complete!"
}

configure_vendor_modules() {
    log_step "Configuring vendor modules..."
    
    cd "${KERNEL_DIR}"
    
    # Save GKI config
    cp .config "${OUTPUT_DIR}/.config.gki"
    
    # Configure vendor-specific modules
    log_info "Setting up vendor module configuration..."
    
    # Check if there's a vendor-specific defconfig
    if [ -f "arch/arm64/configs/${VENDOR_DEFCONFIG}" ]; then
        log_info "Using vendor defconfig: ${VENDOR_DEFCONFIG}"
        
        # Merge vendor defconfig with GKI config
        ./scripts/kconfig/merge_config.sh -m "${OUTPUT_DIR}/.config.gki" "arch/arm64/configs/${VENDOR_DEFCONFIG}"
    fi
    
    # Apply vendor-specific NetHunter drivers as modules
    cat >> .config << 'EOF'

# NetHunter Vendor Drivers as Modules
CONFIG_RTL8812AU=m
CONFIG_RTL8814AU=m
CONFIG_RTL88XXAU=m
CONFIG_R8188EU=m
CONFIG_RTL8188FU=m
CONFIG_MT7601U=m
CONFIG_ATH9K_HTC=m
CONFIG_ATH_COMMON=m

# USB WiFi drivers as modules
CONFIG_USB_NET_RNDIS_HOST=m
CONFIG_USB_USBNET=m
CONFIG_USB_ACM=m

# HID Gadget as module
CONFIG_USB_F_HID=m

# Additional NetHunter modules
CONFIG_TUN=m
CONFIG_TAP=m
EOF
    
    make olddefconfig
    
    log_info "Vendor module configuration complete!"
}

build_gki_kernel() {
    log_step "Building GKI kernel..."
    
    cd "${KERNEL_DIR}"
    
    # Set up environment
    setup_build_env
    
    # Build GKI kernel (Image.gz)
    log_info "Building GKI kernel image..."
    make -j"${JOBS}" LLVM=1 LLVM_IAS=1 Image.gz 2>&1 | tee "${OUTPUT_DIR}/build-gki.log"
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_error "GKI kernel build failed!"
        return 1
    fi
    
    # Copy GKI kernel
    mkdir -p "${GKI_DIR}"
    cp "arch/arm64/boot/Image.gz" "${GKI_DIR}/Image.gz"
    
    log_info "GKI kernel built successfully!"
}

build_vendor_modules() {
    log_step "Building vendor modules..."
    
    cd "${KERNEL_DIR}"
    
    # Build vendor modules
    log_info "Building vendor kernel modules..."
    make -j"${JOBS}" LLVM=1 LLVM_IAS=1 modules 2>&1 | tee -a "${OUTPUT_DIR}/build-vendor.log"
    
    # Install modules
    log_info "Installing vendor modules..."
    make modules_install INSTALL_MOD_PATH="${VENDOR_DIR}"
    
    # Strip modules
    log_info "Stripping vendor modules..."
    find "${VENDOR_DIR}" -name "*.ko" -exec ${STRIP} --strip-unneeded {} \; 2>/dev/null || true
    
    # Create vendor module list
    log_info "Vendor modules built:"
    find "${VENDOR_DIR}" -name "*.ko" -exec basename {} \; | tee "${OUTPUT_DIR}/vendor-modules.list"
    
    log_info "Vendor modules built successfully!"
}

package_gki_kernel() {
    log_step "Packaging GKI kernel..."
    
    cd "${KERNEL_DIR}"
    
    # Create output directories
    mkdir -p "${OUTPUT_DIR}/kernel"
    mkdir -p "${MODULES_DIR}"
    
    # Copy GKI kernel
    if [ -f "${GKI_DIR}/Image.gz" ]; then
        cp "${GKI_DIR}/Image.gz" "${OUTPUT_DIR}/kernel/Image.gz"
    fi
    
    # Copy GKI kernel config
    if [ -f "${OUTPUT_DIR}/.config.gki" ]; then
        cp "${OUTPUT_DIR}/.config.gki" "${OUTPUT_DIR}/kernel/config-gki"
    elif [ -f ".config" ]; then
        cp ".config" "${OUTPUT_DIR}/kernel/config-gki"
    fi
    
    # Copy dtb files
    if [ -d "arch/arm64/boot/dts" ]; then
        find "arch/arm64/boot/dts" -name "*.dtb" -exec cp {} "${OUTPUT_DIR}/kernel/" \; 2>/dev/null || true
    fi
    
    # Create dtb.img if multiple dtbs exist
    if [ $(find "${OUTPUT_DIR}/kernel" -name "*.dtb" | wc -l) -gt 0 ]; then
        cat "${OUTPUT_DIR}/kernel"/*.dtb > "${OUTPUT_DIR}/kernel/dtb.img" 2>/dev/null || true
    fi
    
    # Copy vendor modules
    if [ -d "${VENDOR_DIR}/lib/modules" ]; then
        cp -r "${VENDOR_DIR}/lib/modules" "${MODULES_DIR}/"
    fi
    
    # Create GKI flashable zip using AnyKernel3
    create_gki_anykernel_zip
    
    log_info "GKI kernel packaging complete!"
}

create_gki_anykernel_zip() {
    log_step "Creating GKI AnyKernel3 flashable zip..."
    
    cd "${BUILD_DIR}"
    
    # Clone AnyKernel3
    if [ -d "AnyKernel3" ]; then
        rm -rf AnyKernel3
    fi
    
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git
    
    cd AnyKernel3
    
    # Configure AnyKernel3 for GKI device
    cat > anykernel.sh << EOF
### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { 
kernel.string=NetHunter GKI Kernel for Galaxy Tab S8 (gts8wifi)
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=gts8wifi
device.name2=gts8
device.name3=SM-X700
device.name4=SM-X706
device.name5=
supported.versions=13.0-14.0
supported.patchlevels=

block=boot
is_slot_device=0
ramdisk_compression=auto
}

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

# GKI specific: Don't replace the kernel, just add modules
# For GKI, we need to use vendor_boot or vendor_dlkm partition

# boot shell variables
slot_select=none

# boot install
dump_boot

# For GKI devices, the kernel stays the same
# We only need to update vendor modules if needed

write_boot
## end boot install
EOF
    
    # Copy GKI kernel image
    if [ -f "${OUTPUT_DIR}/kernel/Image.gz" ]; then
        cp "${OUTPUT_DIR}/kernel/Image.gz" zImage
    fi
    
    # Copy dtb
    if [ -f "${OUTPUT_DIR}/kernel/dtb.img" ]; then
        cp "${OUTPUT_DIR}/kernel/dtb.img" dtb.img
    fi
    
    # Copy vendor modules
    if [ -d "${MODULES_DIR}/lib/modules" ]; then
        mkdir -p modules
        cp -r "${MODULES_DIR}/lib/modules"/* modules/ 2>/dev/null || true
    fi
    
    # Create zip
    ZIP_NAME="NetHunter-GKI-${DEVICE_CODENAME}-$(date +%Y%m%d).zip"
    zip -r9 "${OUTPUT_DIR}/${ZIP_NAME}" * -x "*.git*" -x "README.md" -x "LICENSE"
    
    log_info "GKI AnyKernel3 zip created: ${ZIP_NAME}"
}

setup_build_env() {
    # Set up environment variables for build
    export ARCH=arm64
    export SUBARCH=arm64
    export CROSS_COMPILE="${TOOLCHAIN_DIR}/aarch64-5.5/bin/aarch64-linux-gnu-"
    export CROSS_COMPILE_ARM32="${TOOLCHAIN_DIR}/armhf-5.5/bin/arm-linux-gnueabihf-"
    export CC="${TOOLCHAIN_DIR}/clang-r416183b/bin/clang"
    export CLANG_TRIPLE=aarch64-linux-gnu-
    export AR="${TOOLCHAIN_DIR}/clang-r416183b/bin/llvm-ar"
    export NM="${TOOLCHAIN_DIR}/clang-r416183b/bin/llvm-nm"
    export OBJCOPY="${TOOLCHAIN_DIR}/aarch64-5.5/bin/aarch64-linux-gnu-objcopy"
    export OBJDUMP="${TOOLCHAIN_DIR}/aarch64-5.5/bin/aarch64-linux-gnu-objdump"
    export STRIP="${TOOLCHAIN_DIR}/aarch64-5.5/bin/aarch64-linux-gnu-strip"
    export LD="${TOOLCHAIN_DIR}/clang-r416183b/bin/ld.lld"
    
    # Enable ccache
    export CCACHE_COMPRESS=1
    export CCACHE_DIR="${BUILD_DIR}/.ccache"
    mkdir -p "${CCACHE_DIR}"
}

################################################################################
# Environment Setup
################################################################################

setup_environment() {
    log_step "Setting up build environment..."
    
    # Create directories
    mkdir -p "${BUILD_DIR}" "${TOOLCHAIN_DIR}" "${OUTPUT_DIR}" "${MODULES_DIR}"
    
    # Install dependencies
    log_info "Installing required packages..."
    sudo apt-get update
    sudo apt-get install -y \
        git \
        build-essential \
        bc \
        bison \
        flex \
        libssl-dev \
        libncurses5-dev \
        libncursesw5-dev \
        device-tree-compiler \
        lz4 \
        xz-utils \
        wget \
        curl \
        python3 \
        python3-pip \
        ccache \
        libelf-dev \
        libxml2-utils \
        kmod \
        cpio \
        qttools5-dev \
        libqt5widgets5 \
        fakeroot \
        xz-utils \
        whiptail \
        zip \
        unzip \
        lynx \
        pandoc \
        axel \
        binutils-aarch64-linux-gnu
    
    log_info "Environment setup complete!"
}

################################################################################
# Toolchain Setup
################################################################################

download_toolchains() {
    log_step "Downloading and setting up toolchains..."
    
    cd "${TOOLCHAIN_DIR}"
    
    # Download GCC toolchain for aarch64
    if [ ! -d "aarch64-5.5" ]; then
        log_info "Downloading AArch64 GCC toolchain..."
        wget -q --show-progress "${AARCH64_GCC_URL}" -O aarch64-toolchain.tar.xz
        tar -xf aarch64-toolchain.tar.xz
        mv linaro-aarch64-5.5 aarch64-5.5
        rm aarch64-toolchain.tar.xz
    fi
    
    # Download GCC toolchain for arm
    if [ ! -d "armhf-5.5" ]; then
        log_info "Downloading ARM GCC toolchain..."
        wget -q --show-progress "${ARM_GCC_URL}" -O arm-toolchain.tar.xz
        tar -xf arm-toolchain.tar.xz
        mv linaro-armhf-5.5 armhf-5.5
        rm arm-toolchain.tar.xz
    fi
    
    # Download Clang
    if [ ! -d "clang-r416183b" ]; then
        log_info "Downloading Clang toolchain..."
        wget -q --show-progress "${CLANG_URL}" -O clang.tar.gz
        tar -xzf clang.tar.gz
        mv android_prebuilts_clang_kernel_linux-x86_clang-r416183b-lineage-20.0 clang-r416183b
        rm clang.tar.gz
    fi
    
    log_info "Toolchains downloaded successfully!"
}

################################################################################
# Kernel Source Setup
################################################################################

download_kernel_source() {
    log_step "Preparing kernel source..."

    if [ -d "${KERNEL_DIR}" ] && [ -f "${KERNEL_DIR}/Makefile" ]; then
        log_info "Using existing kernel source at ${KERNEL_DIR}"
        return 0
    fi

    mkdir -p "$(dirname "${KERNEL_DIR}")"

    log_info "Cloning kernel source from ${KERNEL_SOURCE_URL}..."
    git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_SOURCE_URL}" "${KERNEL_DIR}"

    cd "${KERNEL_DIR}"

    # Initialize submodules if any
    git submodule update --init --recursive 2>/dev/null || true

    log_info "Kernel source prepared successfully!"
}

################################################################################
# NetHunter Patches Setup
################################################################################

setup_nethunter_patches() {
    log_step "Setting up NetHunter kernel patches..."
    
    cd "${BUILD_DIR}"
    
    # Clone NetHunter kernel builder
    if [ -d "kali-nethunter-kernel" ]; then
        rm -rf kali-nethunter-kernel
    fi
    
    git clone --depth=1 https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel.git
    
    # Copy patches to kernel directory
    cd "${KERNEL_DIR}"
    
    # Apply NetHunter patches based on kernel version
    KERNEL_MAJOR=$(make kernelversion 2>/dev/null | cut -d. -f1 || echo "5")
    
    log_info "Detected kernel major version: ${KERNEL_MAJOR}"
    
    # Create patches directory
    mkdir -p "${KERNEL_DIR}/nethunter-patches"
    
    # Copy relevant patches
    if [ -d "${BUILD_DIR}/kali-nethunter-kernel/patches" ]; then
        cp -r "${BUILD_DIR}/kali-nethunter-kernel/patches/"* "${KERNEL_DIR}/nethunter-patches/" 2>/dev/null || true
    fi
    
    log_info "NetHunter patches setup complete!"
}

################################################################################
# Apply NetHunter Patches
################################################################################

apply_nethunter_patches() {
    log_step "Applying NetHunter patches..."
    
    cd "${KERNEL_DIR}"
    
    # Wi-Fi injection patch for 802.11 frame injection
    log_info "Applying Wi-Fi injection patches..."
    
    # mac80211 injection patch
    if [ -f "nethunter-patches/mac80211.compat08082009.wl_frag+ack_v1.patch" ]; then
        patch -p1 < nethunter-patches/mac80211.compat08082009.wl_frag+ack_v1.patch || \
            log_warn "mac80211 patch may have already been applied or failed"
    fi
    
    # Apply HID patches if kernel < 4.x (not needed for 5.10)
    log_info "HID patches not required for kernel 5.10+"
    
    # Apply RTL8812AU driver patch if available
    if [ -f "nethunter-patches/rtl8812au.patch" ]; then
        log_info "Applying RTL8812AU driver patch..."
        patch -p1 < nethunter-patches/rtl8812au.patch || \
            log_warn "RTL8812AU patch may have already been applied or failed"
    fi
    
    # Apply RTL8188EUS driver patch if available
    if [ -f "nethunter-patches/rtl8188eus.patch" ]; then
        log_info "Applying RTL8188EUS driver patch..."
        patch -p1 < nethunter-patches/rtl8188eus.patch || \
            log_warn "RTL8188EUS patch may have already been applied or failed"
    fi
    
    log_info "NetHunter patches applied!"
}

################################################################################
# Configure Kernel
################################################################################

configure_kernel() {
    log_step "Configuring kernel for NetHunter..."
    
    cd "${KERNEL_DIR}"
    
    # Set up build environment
    setup_build_env
    
    # Clean previous builds
    log_info "Cleaning previous build artifacts..."
    make clean 2>/dev/null || true
    make mrproper 2>/dev/null || true
    
    # Check for GKI support
    check_gki_support
    
    if [ "${GKI_ENABLE}" = "true" ]; then
        log_info "Using GKI build configuration..."
        configure_gki_kernel
        
        if [ "${GKI_BUILD_VENDOR_MODULES}" = "true" ]; then
            configure_vendor_modules
        fi
    else
        # Legacy non-GKI configuration
        log_info "Using legacy build configuration..."
        
        # Find and use appropriate defconfig
        log_info "Looking for device defconfig..."
        
        if [ -f "arch/arm64/configs/${DEFCONFIG}" ]; then
            log_info "Using defconfig: ${DEFCONFIG}"
            make "${DEFCONFIG}"
        elif [ -f "arch/arm64/configs/gts8_defconfig" ]; then
            DEFCONFIG="gts8_defconfig"
            log_info "Using defconfig: ${DEFCONFIG}"
            make "${DEFCONFIG}"
        else
            log_warn "Device defconfig not found, using gki_defconfig"
            make gki_defconfig
        fi
    fi
    
    # Apply NetHunter configuration options
    log_info "Applying NetHunter kernel configuration..."
    
    # Create NetHunter config fragment
    if [ -f "${SCRIPT_DIR}/nethunter-config.fragment" ]; then
        cp "${SCRIPT_DIR}/nethunter-config.fragment" "${KERNEL_DIR}/nethunter.config"
    else
        log_warn "nethunter-config.fragment not found, generating minimal fallback config"
        cat > "${KERNEL_DIR}/nethunter.config" << 'EOF'
# Minimal NetHunter fallback config
CONFIG_MODULES=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_F_HID=y
CONFIG_BT_RFCOMM=y
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_TUN=y
CONFIG_CFG80211=y
CONFIG_MAC80211=y
EOF
    fi
    
    # Merge NetHunter config with kernel config
    log_info "Merging NetHunter configuration..."
    
    # Use merge_config.sh if available
    if [ -f "scripts/kconfig/merge_config.sh" ]; then
        ./scripts/kconfig/merge_config.sh -m .config nethunter.config
    else
        # Manual merge
        cat nethunter.config >> .config
        make olddefconfig
    fi
    
    # Open menuconfig for final adjustments (optional)
    if [ "${INTERACTIVE_CONFIG}" = "yes" ]; then
        log_info "Opening menuconfig for final adjustments..."
        make menuconfig
    else
        make olddefconfig
    fi
    
    log_info "Kernel configuration complete!"
}

################################################################################
# Build Kernel
################################################################################

build_kernel() {
    log_step "Building kernel..."
    
    cd "${KERNEL_DIR}"
    
    # Set up build environment
    setup_build_env
    
    # Check if GKI build
    if [ "${GKI_ENABLE}" = "true" ]; then
        log_info "Using GKI build process..."
        
        # Build GKI kernel
        build_gki_kernel
        
        # Build vendor modules if enabled
        if [ "${GKI_BUILD_VENDOR_MODULES}" = "true" ]; then
            build_vendor_modules
        fi
    else
        # Legacy non-GKI build
        log_info "Starting kernel compilation with ${JOBS} parallel jobs..."
        
        make -j"${JOBS}" LLVM=1 LLVM_IAS=1 Image.gz 2>&1 | tee "${OUTPUT_DIR}/build.log"
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log_error "Kernel build failed! Check ${OUTPUT_DIR}/build.log for details."
            exit 1
        fi
        
        # Build dtbs
        log_info "Building device tree blobs..."
        make -j"${JOBS}" LLVM=1 LLVM_IAS=1 dtbs 2>&1 | tee -a "${OUTPUT_DIR}/build.log"
        
        # Build modules
        log_info "Building kernel modules..."
        make -j"${JOBS}" LLVM=1 LLVM_IAS=1 modules 2>&1 | tee -a "${OUTPUT_DIR}/build.log"
    fi
    
    log_info "Kernel build completed successfully!"
}

################################################################################
# Package Kernel
################################################################################

package_kernel() {
    log_step "Packaging kernel..."
    
    cd "${KERNEL_DIR}"

    # Set up build environment (needed for strip tool paths)
    setup_build_env
    
    # Check if GKI build
    if [ "${GKI_ENABLE}" = "true" ]; then
        log_info "Using GKI packaging process..."
        package_gki_kernel
        return 0
    fi
    
    # Legacy non-GKI packaging
    
    # Create output directories
    mkdir -p "${OUTPUT_DIR}/kernel"
    mkdir -p "${MODULES_DIR}"
    
    # Copy kernel image
    log_info "Copying kernel image..."
    if [ -f "arch/arm64/boot/Image.gz" ]; then
        cp "arch/arm64/boot/Image.gz" "${OUTPUT_DIR}/kernel/Image.gz"
    fi
    
    if [ -f "arch/arm64/boot/Image" ]; then
        cp "arch/arm64/boot/Image" "${OUTPUT_DIR}/kernel/Image"
    fi
    
    # Copy dtb files
    log_info "Copying device tree blobs..."
    if [ -d "arch/arm64/boot/dts" ]; then
        find "arch/arm64/boot/dts" -name "*.dtb" -exec cp {} "${OUTPUT_DIR}/kernel/" \; 2>/dev/null || true
    fi
    
    # Create dtb.img if multiple dtbs exist
    if [ $(find "${OUTPUT_DIR}/kernel" -name "*.dtb" | wc -l) -gt 0 ]; then
        cat "${OUTPUT_DIR}/kernel"/*.dtb > "${OUTPUT_DIR}/kernel/dtb.img" 2>/dev/null || true
    fi
    
    # Install modules
    log_info "Installing kernel modules..."
    make modules_install INSTALL_MOD_PATH="${MODULES_DIR}" 2>/dev/null || true
    
    # Strip modules
    log_info "Stripping kernel modules..."
    find "${MODULES_DIR}" -name "*.ko" -exec ${CROSS_COMPILE}strip --strip-unneeded {} \; 2>/dev/null || true
    
    # Create flashable zip using AnyKernel3
    create_anykernel_zip
    
    log_info "Kernel packaging complete!"
}

################################################################################
# Create AnyKernel3 Flashable Zip
################################################################################

create_anykernel_zip() {
    log_step "Creating AnyKernel3 flashable zip..."
    
    cd "${BUILD_DIR}"
    
    # Clone AnyKernel3
    if [ -d "AnyKernel3" ]; then
        rm -rf AnyKernel3
    fi
    
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git
    
    cd AnyKernel3
    
    # Configure AnyKernel3 for gts8wifi
    cat > anykernel.sh << EOF
### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { 
kernel.string=NetHunter Kernel for Galaxy Tab S8 (gts8wifi)
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=gts8wifi
device.name2=gts8
device.name3=SM-X700
device.name4=SM-X706
device.name5=
supported.versions=12.0-14.0
supported.patchlevels=

block=boot
is_slot_device=auto
ramdisk_compression=auto
}

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

# boot shell variables
slot_select=none

# boot install
dump_boot

write_boot
## end boot install
EOF
    
    # Copy kernel image
    cp "${OUTPUT_DIR}/kernel/Image.gz" zImage 2>/dev/null || \
    cp "${OUTPUT_DIR}/kernel/Image" zImage 2>/dev/null || \
    log_warn "No kernel image found"
    
    # Copy dtb
    if [ -f "${OUTPUT_DIR}/kernel/dtb.img" ]; then
        cp "${OUTPUT_DIR}/kernel/dtb.img" dtb.img
    fi
    
    # Copy modules
    if [ -d "${MODULES_DIR}/lib/modules" ]; then
        mkdir -p modules
        cp -r "${MODULES_DIR}/lib/modules"/* modules/ 2>/dev/null || true
    fi
    
    # Create zip
    ZIP_NAME="NetHunter-kernel-${DEVICE_CODENAME}-$(date +%Y%m%d).zip"
    zip -r9 "${OUTPUT_DIR}/${ZIP_NAME}" * -x "*.git*" -x "README.md" -x "LICENSE"
    
    log_info "AnyKernel3 zip created: ${ZIP_NAME}"
}

################################################################################
# Full Build Process
################################################################################

full_build() {
    print_banner
    
    log_info "Starting full NetHunter kernel build for ${DEVICE_MODEL} (${DEVICE_CODENAME})"
    log_info "Android Version: ${ANDROID_VERSION}"
    log_info "Chipset: ${CHIPSET}"
    log_info "Parallel Jobs: ${JOBS}"
    
    setup_environment
    download_toolchains
    download_kernel_source
    setup_nethunter_patches
    apply_nethunter_patches
    configure_kernel
    build_kernel
    package_kernel
    
    print_banner
    log_info "Build completed successfully!"
    log_info "Output files are in: ${OUTPUT_DIR}"
    log_info ""
    log_info "Flashable zip: $(ls -1 ${OUTPUT_DIR}/*.zip 2>/dev/null | head -1)"
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                     NetHunter Kernel Builder Menu                            ║"
    echo "║                    Samsung Galaxy Tab S8 (gts8wifi)                          ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  1. Full Build (Setup + Download + Configure + Build + Package)              ║"
    echo "║  2. Setup Environment Only                                                   ║"
    echo "║  3. Download Toolchains Only                                                 ║"
    echo "║  4. Download Kernel Source Only                                              ║"
    echo "║  5. Configure Kernel Only                                                    ║"
    echo "║  6. Build Kernel Only                                                        ║"
    echo "║  7. Package Kernel Only                                                      ║"
    echo "║  8. Clean Build Directory                                                    ║"
    echo "║  9. Exit                                                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

main() {
    # Check if running in interactive mode
    if [ -n "$1" ]; then
        case "$1" in
            full|1)
                full_build
                ;;
            setup|2)
                setup_environment
                ;;
            toolchains|3)
                download_toolchains
                ;;
            source|4)
                download_kernel_source
                ;;
            configure|5)
                configure_kernel
                ;;
            build|6)
                build_kernel
                ;;
            package|7)
                package_kernel
                ;;
            clean|8)
                rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
                log_info "Build directories cleaned!"
                ;;
            *)
                echo "Usage: $0 {full|setup|toolchains|source|configure|build|package|clean}"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Interactive menu
    while true; do
        show_menu
        read -p "Select an option [1-9]: " choice
        
        case $choice in
            1)
                full_build
                ;;
            2)
                setup_environment
                ;;
            3)
                download_toolchains
                ;;
            4)
                download_kernel_source
                ;;
            5)
                INTERACTIVE_CONFIG=yes
                configure_kernel
                ;;
            6)
                build_kernel
                ;;
            7)
                package_kernel
                ;;
            8)
                rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
                log_info "Build directories cleaned!"
                ;;
            9)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option!"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
