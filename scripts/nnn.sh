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
KERNEL_DIR="/kernel_platform/common"
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
    
    # Apply NetHunter configuration to GKI
    log_info "Applying NetHunter configuration to GKI kernel..."
    
    # Merge NetHunter config fragment
    if [ -f "${SCRIPT_DIR}/nethunter-config.fragment" ]; then
        cat "${SCRIPT_DIR}/nethunter-config.fragment" >> .config
    fi
    
    # Apply GKI-specific NetHunter options
    cat >> .config << 'EOF'

# GKI NetHunter Extensions
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA256=y
CONFIG_MODULE_SIG_HASH="sha256"

# GKI Module Signing (for inline modules)
CONFIG_MODULE_SIG_KEY=""

# Enable loadable module support for GKI
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y

# GKI Debug
CONFIG_DEBUG_FS=y
CONFIG_DEBUG_KERNEL=y
EOF
    
    make olddefconfig
    
    log_info "GKI kernel configuration complete!"
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
    cp "${OUTPUT_DIR}/.config.gki" "${OUTPUT_DIR}/kernel/config-gki"
    
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
    if [ -d "${MODULES_DIR}/modules" ]; then
        mkdir -p modules
        cp -r "${MODULES_DIR}/modules"/* modules/ 2>/dev/null || true
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
  
