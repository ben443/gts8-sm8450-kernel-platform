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
    log_step "Downloading kernel source..."
    
    if [ -d "${KERNEL_DIR}" ]; then
        log_warn "Kernel directory exists. Removing..."
        rm -rf "${KERNEL_DIR}"
    fi
    
    log_info "Cloning kernel source from ${KERNEL_SOURCE_URL}..."
    git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_SOURCE_URL}" "${KERNEL_DIR}"
    
    cd "${KERNEL_DIR}"
    
    # Initialize submodules if any
    git submodule update --init --recursive 2>/dev/null || true
    
    log_info "Kernel source downloaded successfully!"
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
    cat > "${KERNEL_DIR}/nethunter.config" << 'EOF'
# NetHunter Kernel Configuration Options

# USB Gadget Support
CONFIG_USB_GADGET=y
CONFIG_USB_GADGET_DEBUG_FS=y
CONFIG_USB_GADGET_VBUS_DRAW=500
CONFIG_USB_GADGET_STORAGE_NUM_BUFFERS=2
CONFIG_USB_GADGET_UASP=y

# USB HID Support
CONFIG_USB_HID=y
CONFIG_USB_HIDDEV=y
CONFIG_HIDRAW=y
CONFIG_UHID=y

# USB Ethernet/RNDIS
CONFIG_USB_NET_RNDIS_HOST=y
CONFIG_USB_NET_RNDIS_WLAN=y
CONFIG_USB_USBNET=y

# USB Serial/ACM
CONFIG_USB_ACM=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_CP210X=y
CONFIG_USB_SERIAL_FTDI_SIO=y
CONFIG_USB_SERIAL_PL2303=y
CONFIG_USB_SERIAL_CH341=y

# USB Storage
CONFIG_USB_STORAGE=y
CONFIG_USB_STORAGE_REALTEK=y
CONFIG_USB_STORAGE_DATAFAB=y
CONFIG_USB_STORAGE_FREECOM=y
CONFIG_USB_STORAGE_ISD200=y
CONFIG_USB_STORAGE_USBAT=y
CONFIG_USB_STORAGE_SDDR09=y
CONFIG_USB_STORAGE_SDDR55=y
CONFIG_USB_STORAGE_JUMPSHOT=y
CONFIG_USB_STORAGE_ALAUDA=y
CONFIG_USB_STORAGE_ONETOUCH=y
CONFIG_USB_STORAGE_KARMA=y
CONFIG_USB_STORAGE_CYPRESS_ATACB=y
CONFIG_USB_STORAGE_ENE_UB6250=y

# Wireless LAN Support
CONFIG_WLAN=y
CONFIG_WIRELESS=y
CONFIG_CFG80211=y
CONFIG_CFG80211_WEXT=y
CONFIG_MAC80211=y
CONFIG_MAC80211_MESH=y
CONFIG_MAC80211_LEDS=y
CONFIG_MAC80211_DEBUGFS=y

# RTL8812AU/RTL8814AU Support
CONFIG_RTL8812AU=m
CONFIG_RTL8814AU=m
CONFIG_RTL88XXAU=m

# RTL8188EUS Support
CONFIG_R8188EU=m

# RTL8188FU Support
CONFIG_RTL8188FU=m

# MT7601U Support
CONFIG_MT7601U=m

# ATH9K HTC Support
CONFIG_ATH9K_HTC=m

# Atheros Support
CONFIG_ATH_COMMON=m
CONFIG_ATH_CARDS=m

# Bluetooth Support
CONFIG_BT=y
CONFIG_BT_BREDR=y
CONFIG_BT_RFCOMM=y
CONFIG_BT_RFCOMM_TTY=y
CONFIG_BT_BNEP=y
CONFIG_BT_BNEP_MC_FILTER=y
CONFIG_BT_BNEP_PROTO_FILTER=y
CONFIG_BT_HIDP=y
CONFIG_BT_HS=y
CONFIG_BT_LE=y
CONFIG_BT_LEDS=y

# Bluetooth USB
CONFIG_BT_HCIBTUSB=y
CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y
CONFIG_BT_HCIBTUSB_BCM=y
CONFIG_BT_HCIBTUSB_MTK=y
CONFIG_BT_HCIBTUSB_RTL=y

# Network Packet Filtering
CONFIG_NETFILTER=y
CONFIG_NETFILTER_ADVANCED=y
CONFIG_NETFILTER_XTABLES=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_COMMENT=y
CONFIG_NETFILTER_XT_MATCH_CONNLIMIT=y
CONFIG_NETFILTER_XT_MATCH_CONNMARK=y
CONFIG_NETFILTER_XT_MATCH_CONNTRACK=y
CONFIG_NETFILTER_XT_MATCH_HASHLIMIT=y
CONFIG_NETFILTER_XT_MATCH_HELPER=y
CONFIG_NETFILTER_XT_MATCH_IPRANGE=y
CONFIG_NETFILTER_XT_MATCH_LENGTH=y
CONFIG_NETFILTER_XT_MATCH_LIMIT=y
CONFIG_NETFILTER_XT_MATCH_MAC=y
CONFIG_NETFILTER_XT_MATCH_MARK=y
CONFIG_NETFILTER_XT_MATCH_MULTIPORT=y
CONFIG_NETFILTER_XT_MATCH_OWNER=y
CONFIG_NETFILTER_XT_MATCH_POLICY=y
CONFIG_NETFILTER_XT_MATCH_PHYSDEV=y
CONFIG_NETFILTER_XT_MATCH_PKTTYPE=y
CONFIG_NETFILTER_XT_MATCH_QUOTA=y
CONFIG_NETFILTER_XT_MATCH_RATEEST=y
CONFIG_NETFILTER_XT_MATCH_REALM=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y
CONFIG_NETFILTER_XT_MATCH_SCTP=y
CONFIG_NETFILTER_XT_MATCH_STATE=y
CONFIG_NETFILTER_XT_MATCH_STATISTIC=y
CONFIG_NETFILTER_XT_MATCH_STRING=y
CONFIG_NETFILTER_XT_MATCH_TCPMSS=y
CONFIG_NETFILTER_XT_MATCH_TIME=y
CONFIG_NETFILTER_XT_MATCH_U32=y

# IP Tables
CONFIG_IP_NF_IPTABLES=y
CONFIG_IP_NF_FILTER=y
CONFIG_IP_NF_TARGET_REJECT=y
CONFIG_IP_NF_NAT=y
CONFIG_IP_NF_TARGET_MASQUERADE=y
CONFIG_IP_NF_TARGET_REDIRECT=y
CONFIG_IP_NF_MANGLE=y
CONFIG_IP_NF_RAW=y
CONFIG_IP_NF_ARPTABLES=y
CONFIG_IP_NF_ARPFILTER=y

# IPv6 Support
CONFIG_IP6_NF_IPTABLES=y
CONFIG_IP6_NF_FILTER=y
CONFIG_IP6_NF_TARGET_REJECT=y
CONFIG_IP6_NF_MANGLE=y
CONFIG_IP6_NF_RAW=y

# TUN/TAP Support
CONFIG_TUN=y
CONFIG_TAP=y

# PPP Support
CONFIG_PPP=y
CONFIG_PPP_BSDCOMP=y
CONFIG_PPP_DEFLATE=y
CONFIG_PPP_FILTER=y
CONFIG_PPP_MPPE=y
CONFIG_PPP_MULTILINK=y
CONFIG_PPPOE=y
CONFIG_PPP_ASYNC=y
CONFIG_PPP_SYNC_TTY=y

# SDR (Software Defined Radio) Support
CONFIG_MEDIA_SDR_SUPPORT=y
CONFIG_SDR_MAX2175=y

# USB Video Class (UVC)
CONFIG_USB_VIDEO_CLASS=y
CONFIG_USB_VIDEO_CLASS_INPUT_EVDEV=y

# V4L2 Support
CONFIG_VIDEO_V4L2=y
CONFIG_VIDEOBUF2_VMALLOC=y

# Input Device Support
CONFIG_INPUT_UINPUT=y
CONFIG_INPUT_MISC=y
CONFIG_INPUT_GPIO=y

# LED Support
CONFIG_NEW_LEDS=y
CONFIG_LEDS_CLASS=y
CONFIG_LEDS_TRIGGERS=y

# GPIO Support
CONFIG_GPIOLIB=y
CONFIG_GPIO_SYSFS=y

# Sysfs Support
CONFIG_SYSFS=y

# Debug Support
CONFIG_DEBUG_FS=y
CONFIG_DYNAMIC_DEBUG=y

# FUSE Support
CONFIG_FUSE_FS=y
CONFIG_CUSE=y

# OverlayFS Support
CONFIG_OVERLAY_FS=y

# SquashFS Support
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_LZ4=y
CONFIG_SQUASHFS_LZO=y
CONFIG_SQUASHFS_XZ=y
CONFIG_SQUASHFS_ZLIB=y

# CIFS Support
CONFIG_CIFS=y
CONFIG_CIFS_STATS=y
CONFIG_CIFS_STATS2=y
CONFIG_CIFS_WEAK_PW_HASH=y
CONFIG_CIFS_UPCALL=y
CONFIG_CIFS_XATTR=y
CONFIG_CIFS_POSIX=y
CONFIG_CIFS_ACL=y
CONFIG_CIFS_DEBUG=y
CONFIG_CIFS_DFS_UPCALL=y
CONFIG_CIFS_SMB311=y
CONFIG_CIFS_FSCACHE=y

# NFS Support
CONFIG_NFS_FS=y
CONFIG_NFS_V2=y
CONFIG_NFS_V3=y
CONFIG_NFS_V3_ACL=y
CONFIG_NFS_V4=y
CONFIG_NFS_V4_1=y
CONFIG_NFS_V4_2=y
CONFIG_NFS_FSCACHE=y
CONFIG_NFS_USE_KERNEL_DNS=y
CONFIG_NFS_ACL_SUPPORT=y
CONFIG_NFS_COMMON=y

# 9P Support
CONFIG_9P_FS=y
CONFIG_9P_FS_POSIX_ACL=y
CONFIG_9P_FS_SECURITY=y

# Security Options
CONFIG_SECURITY=y
CONFIG_SECURITY_NETWORK=y
CONFIG_SECURITY_NETWORK_XFRM=y
CONFIG_SECURITY_PATH=y
CONFIG_SECURITY_SELINUX=y
CONFIG_SECURITY_SELINUX_BOOTPARAM=y
CONFIG_SECURITY_SELINUX_DISABLE=y
CONFIG_SECURITY_SELINUX_DEVELOP=y
CONFIG_SECURITY_SELINUX_AVC_STATS=y
CONFIG_SECURITY_SELINUX_CHECKREQPROT_VALUE=1

# Namespaces
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y

# Cgroups
CONFIG_CGROUPS=y
CONFIG_CGROUP_NS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_MEM_RES_CTLR=y
CONFIG_CGROUP_MEM_RES_CTLR_SWAP=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_RDMA=y
CONFIG_CGROUP_BPF=y

# BPF Support
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_EVENTS=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NET_SOCK_MSG=y

# Audit Support
CONFIG_AUDIT=y
CONFIG_AUDITSYSCALL=y

# Kernel Samepage Merging
CONFIG_KSM=y

# Memory Hotplug
CONFIG_MEMORY_HOTPLUG=y
CONFIG_MEMORY_HOTREMOVE=y

# Huge Pages
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y

# NUMA Support
CONFIG_NUMA=y

# Kernel Debugging
CONFIG_MAGIC_SYSRQ=y
CONFIG_DEBUG_KERNEL=y
CONFIG_DEBUG_MISC=y

# Scheduler
CONFIG_SCHED_DEBUG=y
CONFIG_SCHEDSTATS=y

# Lock Debugging
CONFIG_PROVE_LOCKING=y
CONFIG_LOCK_STAT=y
CONFIG_DEBUG_RT_MUTEXES=y
CONFIG_DEBUG_SPINLOCK=y
CONFIG_DEBUG_MUTEXES=y
CONFIG_DEBUG_WW_MUTEX_SLOWPATH=y
CONFIG_DEBUG_RWSEMS=y

# Memory Debugging
CONFIG_DEBUG_MEMORY_INIT=y
CONFIG_DEBUG_PAGEALLOC=y
CONFIG_DEBUG_SLAB=y

# Tracing
CONFIG_FTRACE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_FUNCTION_GRAPH_TRACER=y
CONFIG_DYNAMIC_FTRACE=y
CONFIG_TRACING=y

# Kprobes
CONFIG_KPROBES=y
CONFIG_KPROBES_ON_FTRACE=y
CONFIG_KRETPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_HAVE_KRETPROBES=y

# Uprobes
CONFIG_UPROBES=y
CONFIG_UPROBE_EVENTS=y

# Perf Events
CONFIG_PERF_EVENTS=y
CONFIG_HW_PERF_EVENTS=y

# OProfile
CONFIG_OPROFILE=y

# Kexec/Kdump
CONFIG_KEXEC=y
CONFIG_CRASH_DUMP=y
CONFIG_KEXEC_FILE=y

# Module Support
CONFIG_MODULES=y
CONFIG_MODULE_FORCE_LOAD=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODULE_FORCE_UNLOAD=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_SRCVERSION_ALL=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA512=y
CONFIG_MODULE_SIG_HASH="sha512"

# Enable loadable module support
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y

# Firmware Loader
CONFIG_FW_LOADER=y
CONFIG_FIRMWARE_IN_KERNEL=y
CONFIG_EXTRA_FIRMWARE=""

# DMA Contiguous Memory Allocator
CONFIG_DMA_CMA=y

# Contiguous Memory Allocator
CONFIG_CMA=y
CONFIG_CMA_DEBUG=y
CONFIG_CMA_DEBUGFS=y
CONFIG_CMA_AREAS=7

# ZRAM Support
CONFIG_ZRAM=y
CONFIG_ZRAM_WRITEBACK=y
CONFIG_ZRAM_MEMORY_TRACKING=y

# ZSWAP Support
CONFIG_ZSWAP=y
CONFIG_ZSWAP_COMPRESSOR_DEFAULT=zstd
CONFIG_ZSWAP_ZPOOL_DEFAULT=zsmalloc

# ZBUD Support
CONFIG_ZBUD=y

# ZSMALLOC Support
CONFIG_ZSMALLOC=y
CONFIG_ZSMALLOC_STAT=y

# Swap Support
CONFIG_SWAP=y
CONFIG_SWAPFILE=y
CONFIG_FRONTSWAP=y

# Block Layer
CONFIG_BLOCK=y
CONFIG_BLK_DEV_BSG=y
CONFIG_BLK_DEV_BSGLIB=y
CONFIG_BLK_DEV_INTEGRITY=y
CONFIG_BLK_DEV_THROTTLING=y
CONFIG_BLK_WBT=y
CONFIG_BLK_WBT_MQ=y

# IO Schedulers
CONFIG_IOSCHED_NOOP=y
CONFIG_IOSCHED_DEADLINE=y
CONFIG_IOSCHED_CFQ=y
CONFIG_CFQ_GROUP_IOSCHED=y
CONFIG_DEFAULT_CFQ=y
CONFIG_DEFAULT_IOSCHED="cfq"

# Multi-Queue Block IO Queueing Mechanism
CONFIG_BLK_MQ=y
CONFIG_BLK_MQ_PCI=y
CONFIG_BLK_MQ_RDMA=y
CONFIG_BLK_MQ_VIRTIO=y

# NVMe Support
CONFIG_NVME_CORE=y
CONFIG_NVME_FABRICS=y
CONFIG_NVME_RDMA=y
CONFIG_NVME_FC=y
CONFIG_NVME_TCP=y
CONFIG_NVME_TARGET=y
CONFIG_NVME_TARGET_LOOP=y
CONFIG_NVME_TARGET_RDMA=y
CONFIG_NVME_TARGET_FC=y
CONFIG_NVME_TARGET_FCLOOP=y
CONFIG_NVME_TARGET_TCP=y

# SCSI Support
CONFIG_SCSI=y
CONFIG_SCSI_DMA=y
CONFIG_SCSI_NETLINK=y
CONFIG_SCSI_PROC_FS=y
CONFIG_BLK_DEV_SD=y
CONFIG_BLK_DEV_SR=y
CONFIG_CHR_DEV_SG=y
CONFIG_CHR_DEV_SCH=y
CONFIG_SCSI_MULTI_LUN=y
CONFIG_SCSI_CONSTANTS=y
CONFIG_SCSI_LOGGING=y
CONFIG_SCSI_SCAN_ASYNC=y

# SATA/PATA Support
CONFIG_SATA_AHCI=y
CONFIG_SATA_AHCI_PLATFORM=y
CONFIG_ATA=y
CONFIG_ATA_VERBOSE_ERROR=y
CONFIG_ATA_ACPI=y
CONFIG_SATA_PMP=y

# MD RAID Support
CONFIG_MD=y
CONFIG_BLK_DEV_MD=y
CONFIG_MD_AUTODETECT=y
CONFIG_MD_LINEAR=y
CONFIG_MD_RAID0=y
CONFIG_MD_RAID1=y
CONFIG_MD_RAID10=y
CONFIG_MD_RAID456=y
CONFIG_MD_MULTIPATH=y
CONFIG_MD_FAULTY=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_CRYPT=y
CONFIG_DM_SNAPSHOT=y
CONFIG_DM_THIN_PROVISIONING=y
CONFIG_DM_CACHE=y
CONFIG_DM_WRITECACHE=y
CONFIG_DM_MIRROR=y
CONFIG_DM_RAID=y
CONFIG_DM_ZERO=y
CONFIG_DM_MULTIPATH=y
CONFIG_DM_DELAY=y

# Loop Device
CONFIG_BLK_DEV_LOOP=y
CONFIG_BLK_DEV_LOOP_MIN_COUNT=8

# RAM Disk
CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_RAM_COUNT=16
CONFIG_BLK_DEV_RAM_SIZE=8192

# VirtIO Support
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_PCI_LEGACY=y
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_INPUT=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_MMIO_CMDLINE_DEVICES=y

# Network Drivers
CONFIG_NET=y
CONFIG_INET=y
CONFIG_IP_MULTICAST=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_FIB_TRIE_STATS=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IP_ROUTE_MULTIPATH=y
CONFIG_IP_ROUTE_VERBOSE=y
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_IP_PNP_BOOTP=y
CONFIG_IP_PNP_RARP=y
CONFIG_NET_IPIP=y
CONFIG_NET_IPGRE_DEMUX=y
CONFIG_NET_IPGRE=y
CONFIG_NET_IPGRE_BROADCAST=y
CONFIG_IP_MROUTE=y
CONFIG_IP_MROUTE_MULTIPLE_TABLES=y
CONFIG_IP_PIMSM_V1=y
CONFIG_IP_PIMSM_V2=y
CONFIG_SYN_COOKIES=y
CONFIG_NET_IPVTI=y
CONFIG_INET_AH=y
CONFIG_INET_ESP=y
CONFIG_INET_IPCOMP=y
CONFIG_INET_XFRM_TUNNEL=y
CONFIG_INET_TUNNEL=y
CONFIG_INET_XFRM_MODE_TRANSPORT=y
CONFIG_INET_XFRM_MODE_TUNNEL=y
CONFIG_INET_XFRM_MODE_BEET=y
CONFIG_INET_DIAG=y
CONFIG_INET_TCP_DIAG=y
CONFIG_INET_UDP_DIAG=y
CONFIG_INET_RAW_DIAG=y
CONFIG_INET_DIAG_DESTROY=y
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BIC=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_TCP_CONG_WESTWOOD=y
CONFIG_TCP_CONG_HTCP=y
CONFIG_TCP_CONG_HSTCP=y
CONFIG_TCP_CONG_HYBLA=y
CONFIG_TCP_CONG_VEGAS=y
CONFIG_TCP_CONG_NV=y
CONFIG_TCP_CONG_SCALABLE=y
CONFIG_TCP_CONG_LP=y
CONFIG_TCP_CONG_VENO=y
CONFIG_TCP_CONG_YEAH=y
CONFIG_TCP_CONG_ILLINOIS=y
CONFIG_TCP_CONG_DCTCP=y
CONFIG_TCP_CONG_CDG=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="cubic"
CONFIG_TCP_MD5SIG=y
CONFIG_IPV6=y
CONFIG_IPV6_ROUTER_PREF=y
CONFIG_IPV6_ROUTE_INFO=y
CONFIG_IPV6_OPTIMISTIC_DAD=y
CONFIG_INET6_AH=y
CONFIG_INET6_ESP=y
CONFIG_INET6_IPCOMP=y
CONFIG_IPV6_MIP6=y
CONFIG_IPV6_ILA=y
CONFIG_INET6_XFRM_TUNNEL=y
CONFIG_INET6_TUNNEL=y
CONFIG_INET6_XFRM_MODE_TRANSPORT=y
CONFIG_INET6_XFRM_MODE_TUNNEL=y
CONFIG_INET6_XFRM_MODE_BEET=y
CONFIG_INET6_XFRM_MODE_ROUTEOPTIMIZATION=y
CONFIG_IPV6_VTI=y
CONFIG_IPV6_SIT=y
CONFIG_IPV6_SIT_6RD=y
CONFIG_IPV6_NDISC_NODETYPE=y
CONFIG_IPV6_TUNNEL=y
CONFIG_IPV6_GRE=y
CONFIG_IPV6_MULTIPLE_TABLES=y
CONFIG_IPV6_SUBTREES=y
CONFIG_IPV6_MROUTE=y
CONFIG_IPV6_MROUTE_MULTIPLE_TABLES=y
CONFIG_IPV6_PIMSM_V2=y
CONFIG_IPV6_SEG6_LWTUNNEL=y
CONFIG_IPV6_SEG6_HMAC=y
CONFIG_IPV6_RPL_LWTUNNEL=y
CONFIG_NETLABEL=y
CONFIG_NETWORK_SECMARK=y
CONFIG_NET_PTP_CLASSIFY=y
CONFIG_NETFILTER=y
CONFIG_BRIDGE=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_VLAN_8021Q=y
CONFIG_VLAN_8021Q_GVRP=y
CONFIG_VLAN_8021Q_MVRP=y
CONFIG_LLC=y
CONFIG_STP=y
CONFIG_GARP=y
CONFIG_MRP=y
CONFIG_NET_SCHED=y
CONFIG_NET_SCH_HTB=y
CONFIG_NET_SCH_HFSC=y
CONFIG_NET_SCH_PRIO=y
CONFIG_NET_SCH_MULTIQ=y
CONFIG_NET_SCH_RED=y
CONFIG_NET_SCH_SFB=y
CONFIG_NET_SCH_SFQ=y
CONFIG_NET_SCH_TEQL=y
CONFIG_NET_SCH_TBF=y
CONFIG_NET_SCH_CBS=y
CONFIG_NET_SCH_ETF=y
CONFIG_NET_SCH_TAPRIO=y
CONFIG_NET_SCH_GRED=y
CONFIG_NET_SCH_DSMARK=y
CONFIG_NET_SCH_NETEM=y
CONFIG_NET_SCH_DRR=y
CONFIG_NET_SCH_MQPRIO=y
CONFIG_NET_SCH_SKBPRIO=y
CONFIG_NET_SCH_CHOKE=y
CONFIG_NET_SCH_QFQ=y
CONFIG_NET_SCH_CODEL=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_NET_SCH_CAKE=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_HHF=y
CONFIG_NET_SCH_PIE=y
CONFIG_NET_SCH_INGRESS=y
CONFIG_NET_SCH_PLUG=y
CONFIG_NET_CLS=y
CONFIG_NET_CLS_BASIC=y
CONFIG_NET_CLS_TCINDEX=y
CONFIG_NET_CLS_ROUTE4=y
CONFIG_NET_CLS_FW=y
CONFIG_NET_CLS_U32=y
CONFIG_CLS_U32_PERF=y
CONFIG_CLS_U32_MARK=y
CONFIG_NET_CLS_RSVP=y
CONFIG_NET_CLS_RSVP6=y
CONFIG_NET_CLS_FLOW=y
CONFIG_NET_CLS_CGROUP=y
CONFIG_NET_CLS_BPF=y
CONFIG_NET_CLS_FLOWER=y
CONFIG_NET_CLS_MATCHALL=y
CONFIG_NET_EMATCH=y
CONFIG_NET_EMATCH_CMP=y
CONFIG_NET_EMATCH_NBYTE=y
CONFIG_NET_EMATCH_U32=y
CONFIG_NET_EMATCH_META=y
CONFIG_NET_EMATCH_TEXT=y
CONFIG_NET_EMATCH_CANID=y
CONFIG_NET_EMATCH_IPSET=y
CONFIG_NET_EMATCH_IPT=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_POLICE=y
CONFIG_NET_ACT_GACT=y
CONFIG_GACT_PROB=y
CONFIG_NET_ACT_MIRRED=y
CONFIG_NET_ACT_SAMPLE=y
CONFIG_NET_ACT_IPT=y
CONFIG_NET_ACT_NAT=y
CONFIG_NET_ACT_PEDIT=y
CONFIG_NET_ACT_SIMP=y
CONFIG_NET_ACT_SKBEDIT=y
CONFIG_NET_ACT_CSUM=y
CONFIG_NET_ACT_MPLS=y
CONFIG_NET_ACT_VLAN=y
CONFIG_NET_ACT_BPF=y
CONFIG_NET_ACT_CONNMARK=y
CONFIG_NET_ACT_CTINFO=y
CONFIG_NET_ACT_SKBMOD=y
CONFIG_NET_ACT_IFE=y
CONFIG_NET_ACT_TUNNEL_KEY=y
CONFIG_NET_ACT_CT=y
CONFIG_NET_IFE_SKBMARK=y
CONFIG_NET_IFE_SKBPRIO=y
CONFIG_NET_IFE_SKBTCINDEX=y
CONFIG_NET_TC_SKB_EXT=y
CONFIG_NET_SCH_FIFO=y
CONFIG_DCB=y
CONFIG_DNS_RESOLVER=y
CONFIG_BATMAN_ADV=y
CONFIG_BATMAN_ADV_BATMAN_V=y
CONFIG_BATMAN_ADV_BLA=y
CONFIG_BATMAN_ADV_DAT=y
CONFIG_BATMAN_ADV_NC=y
CONFIG_BATMAN_ADV_MCAST=y
CONFIG_BATMAN_ADV_DEBUG=y
CONFIG_BATMAN_ADV_TRACING=y
CONFIG_OPENVSWITCH=y
CONFIG_OPENVSWITCH_GRE=y
CONFIG_OPENVSWITCH_VXLAN=y
CONFIG_OPENVSWITCH_GENEVE=y
CONFIG_VSOCKETS=y
CONFIG_VSOCKETS_DIAG=y
CONFIG_VSOCKETS_LOOPBACK=y
CONFIG_VIRTIO_VSOCKETS=y
CONFIG_VIRTIO_VSOCKETS_COMMON=y
CONFIG_NETLINK_DIAG=y
CONFIG_MPLS=y
CONFIG_NET_MPLS_GSO=y
CONFIG_MPLS_ROUTING=y
CONFIG_MPLS_IPTUNNEL=y
CONFIG_NET_NSH=y
CONFIG_HSR=y
CONFIG_NET_SWITCHDEV=y
CONFIG_NET_L3_MASTER_DEV=y
CONFIG_QRTR=y
CONFIG_QRTR_SMD=y
CONFIG_QRTR_TUN=y
CONFIG_QRTR_MHI=y
CONFIG_NET_NCSI=y
CONFIG_NCSI_OEM_CMD_GET_MAC=y
CONFIG_CGROUP_NET_PRIO=y
CONFIG_CGROUP_NET_CLASSID=y
CONFIG_NET_RX_BUSY_POLL=y
CONFIG_BQL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NET_FLOW_LIMIT=y

# Wireless Extensions
CONFIG_WIRELESS_EXT=y
CONFIG_WEXT_CORE=y
CONFIG_WEXT_PROC=y
CONFIG_WEXT_PRIV=y

# RFKILL
CONFIG_RFKILL=y
CONFIG_RFKILL_INPUT=y
CONFIG_RFKILL_GPIO=y

# Netconsole
CONFIG_NETCONSOLE=y
CONFIG_NETCONSOLE_DYNAMIC=y

# Netpoll
CONFIG_NETPOLL=y
CONFIG_NET_POLL_CONTROLLER=y

# TIPC
CONFIG_TIPC=y
CONFIG_TIPC_MEDIA_IB=y
CONFIG_TIPC_MEDIA_UDP=y
CONFIG_TIPC_CRYPTO=y
CONFIG_TIPC_DIAG=y

# ATM
CONFIG_ATM=y
CONFIG_ATM_CLIP=y
CONFIG_ATM_CLIP_NO_ICMP=y
CONFIG_ATM_LANE=y
CONFIG_ATM_MPOA=y
CONFIG_ATM_BR2684=y
CONFIG_ATM_BR2684_IPFILTER=y

# L2TP
CONFIG_L2TP=y
CONFIG_L2TP_DEBUGFS=y
CONFIG_L2TP_V3=y
CONFIG_L2TP_IP=y
CONFIG_L2TP_ETH=y

# 802.1d Ethernet Bridging
CONFIG_BRIDGE=y
CONFIG_BRIDGE_IGMP_SNOOPING=y
CONFIG_BRIDGE_VLAN_FILTERING=y
CONFIG_BRIDGE_MRP=y
CONFIG_BRIDGE_CFM=y

# 802.1Q/802.1ad VLAN Support
CONFIG_VLAN_8021Q=y
CONFIG_VLAN_8021Q_GVRP=y
CONFIG_VLAN_8021Q_MVRP=y

# DECnet
CONFIG_DECNET=y
CONFIG_DECNET_ROUTER=y

# ANSI/IEEE 802.2 LLC type 2 Support
CONFIG_LLC2=y

# IPX
CONFIG_IPX=y
CONFIG_IPX_INTERN=y

# Appletalk
CONFIG_ATALK=y
CONFIG_DEV_APPLETALK=y
CONFIG_IPDDP=y
CONFIG_IPDDP_ENCAP=y
CONFIG_IPDDP_DECAP=y

# X25
CONFIG_X25=y
CONFIG_LAPB=y

# Phonet
CONFIG_PHONET=y
CONFIG_PHONET_PIPECTRLR=y

# 6LoWPAN
CONFIG_6LOWPAN=y
CONFIG_6LOWPAN_DEBUGFS=y
CONFIG_6LOWPAN_NHC=y
CONFIG_6LOWPAN_NHC_DEST=y
CONFIG_6LOWPAN_NHC_FRAGMENT=y
CONFIG_6LOWPAN_NHC_HOP=y
CONFIG_6LOWPAN_NHC_IPV6=y
CONFIG_6LOWPAN_NHC_MOBILITY=y
CONFIG_6LOWPAN_NHC_ROUTING=y
CONFIG_6LOWPAN_NHC_UDP=y
CONFIG_6LOWPAN_GHC_EXT_HDR_HOP=y
CONFIG_6LOWPAN_GHC_UDP=y
CONFIG_6LOWPAN_GHC_ICMPV6=y
CONFIG_6LOWPAN_GHC_EXT_HDR_DEST=y
CONFIG_6LOWPAN_GHC_EXT_HDR_FRAG=y
CONFIG_6LOWPAN_GHC_EXT_HDR_ROUTE=y

# IEEE 802.15.4
CONFIG_IEEE802154=y
CONFIG_IEEE802154_NL802154_EXPERIMENTAL=y
CONFIG_IEEE802154_SOCKET=y
CONFIG_IEEE802154_6LOWPAN=y
CONFIG_MAC802154=y
CONFIG_IEEE802154_DRIVERS=y
CONFIG_IEEE802154_FAKELB=y
CONFIG_IEEE802154_AT86RF230=y
CONFIG_IEEE802154_MRF24J40=y
CONFIG_IEEE802154_CC2520=y
CONFIG_IEEE802154_ATUSB=y
CONFIG_IEEE802154_ADF7242=y
CONFIG_IEEE802154_CA8210=y
CONFIG_IEEE802154_CC1200=y
CONFIG_IEEE802154_MCR20A=y
CONFIG_IEEE802154_HWSIM=y

# IEEE 802.15.4 MLME
CONFIG_IEEE802154_NL802154_EXPERIMENTAL=y

# MAC802154
CONFIG_MAC802154=y

# CAIF
CONFIG_CAIF=y
CONFIG_CAIF_DEBUG=y
CONFIG_CAIF_NETDEV=y
CONFIG_CAIF_USB=y

# NFC
CONFIG_NFC=y
CONFIG_NFC_DIGITAL=y
CONFIG_NFC_NCI=y
CONFIG_NFC_NCI_SPI=y
CONFIG_NFC_NCI_UART=y
CONFIG_NFC_HCI=y
CONFIG_NFC_SHDLC=y

# NFC Devices
CONFIG_NFC_TRF7970A=y
CONFIG_NFC_SIM=y
CONFIG_NFC_PORT100=y
CONFIG_NFC_VIRTUAL_NCI=y
CONFIG_NFC_FDP=y
CONFIG_NFC_FDP_I2C=y
CONFIG_NFC_PN544=y
CONFIG_NFC_PN544_I2C=y
CONFIG_NFC_PN533=y
CONFIG_NFC_PN533_USB=y
CONFIG_NFC_PN533_I2C=y
CONFIG_NFC_MICROREAD=y
CONFIG_NFC_MICROREAD_I2C=y
CONFIG_NFC_MRVL=y
CONFIG_NFC_MRVL_USB=y
CONFIG_NFC_MRVL_UART=y
CONFIG_NFC_MRVL_I2C=y
CONFIG_NFC_MRVL_SPI=y
CONFIG_NFC_ST21NFCA=y
CONFIG_NFC_ST21NFCA_I2C=y
CONFIG_NFC_ST_NCI=y
CONFIG_NFC_ST_NCI_I2C=y
CONFIG_NFC_ST_NCI_SPI=y
CONFIG_NFC_NXP_NCI=y
CONFIG_NFC_NXP_NCI_I2C=y
CONFIG_NFC_NXP_NCI_SPI=y
CONFIG_NFC_S3FWRN5=y
CONFIG_NFC_S3FWRN5_I2C=y
CONFIG_NFC_S3FWRN5_SPI=y
CONFIG_NFC_ST95HF=y

# CAN
CONFIG_CAN=y
CONFIG_CAN_RAW=y
CONFIG_CAN_BCM=y
CONFIG_CAN_GW=y
CONFIG_CAN_J1939=y
CONFIG_CAN_ISOTP=y

# CAN Device Drivers
CONFIG_CAN_VCAN=y
CONFIG_CAN_VXCAN=y
CONFIG_CAN_SLCAN=y
CONFIG_CAN_DEV=y
CONFIG_CAN_CALC_BITTIMING=y
CONFIG_CAN_FLEXCAN=y
CONFIG_CAN_GRCAN=y
CONFIG_CAN_TI_HECC=y
CONFIG_CAN_C_CAN=y
CONFIG_CAN_C_CAN_PLATFORM=y
CONFIG_CAN_C_CAN_PCI=y
CONFIG_CAN_CC770=y
CONFIG_CAN_CC770_ISA=y
CONFIG_CAN_CC770_PLATFORM=y
CONFIG_CAN_IFI_CANFD=y
CONFIG_CAN_M_CAN=y
CONFIG_CAN_M_CAN_PCI=y
CONFIG_CAN_PEAK_PCIEFD=y
CONFIG_CAN_SJA1000=y
CONFIG_CAN_EMS_PCI=y
CONFIG_CAN_EMS_PCMCIA=y
CONFIG_CAN_F81601=y
CONFIG_CAN_KVASER_PCI=y
CONFIG_CAN_PEAK_PCI=y
CONFIG_CAN_PEAK_PCIEC=y
CONFIG_CAN_PEAK_PCMCIA=y
CONFIG_CAN_PLX_PCI=y
CONFIG_CAN_SJA1000_ISA=y
CONFIG_CAN_SJA1000_PLATFORM=y
CONFIG_CAN_SOFTING=y
CONFIG_CAN_SOFTING_CS=y
CONFIG_CAN_DEBUG_DEVICES=y

# Bluetooth subsystem support
CONFIG_BT=y
CONFIG_BT_BREDR=y
CONFIG_BT_RFCOMM=y
CONFIG_BT_RFCOMM_TTY=y
CONFIG_BT_BNEP=y
CONFIG_BT_BNEP_MC_FILTER=y
CONFIG_BT_BNEP_PROTO_FILTER=y
CONFIG_BT_HIDP=y
CONFIG_BT_HS=y
CONFIG_BT_LE=y
CONFIG_BT_LEDS=y
CONFIG_BT_MSFTEXT=y
CONFIG_BT_DEBUGFS=y

# Bluetooth device drivers
CONFIG_BT_INTEL=y
CONFIG_BT_BCM=y
CONFIG_BT_RTL=y
CONFIG_BT_QCA=y
CONFIG_BT_HCIBTUSB=y
CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y
CONFIG_BT_HCIBTUSB_BCM=y
CONFIG_BT_HCIBTUSB_MTK=y
CONFIG_BT_HCIBTUSB_RTL=y
CONFIG_BT_HCIBTSDIO=y
CONFIG_BT_HCIUART=y
CONFIG_BT_HCIUART_SERDEV=y
CONFIG_BT_HCIUART_H4=y
CONFIG_BT_HCIUART_NOKIA=y
CONFIG_BT_HCIUART_BCSP=y
CONFIG_BT_HCIUART_ATH3K=y
CONFIG_BT_HCIUART_LL=y
CONFIG_BT_HCIUART_3WIRE=y
CONFIG_BT_HCIUART_INTEL=y
CONFIG_BT_HCIUART_BCM=y
CONFIG_BT_HCIUART_RTL=y
CONFIG_BT_HCIUART_QCA=y
CONFIG_BT_HCIUART_AG6XX=y
CONFIG_BT_HCIUART_MRVL=y
CONFIG_BT_HCIBCM203X=y
CONFIG_BT_HCIBPA10X=y
CONFIG_BT_HCIBFUSB=y
CONFIG_BT_HCIVHCI=y
CONFIG_BT_MRVL=y
CONFIG_BT_MRVL_SDIO=y
CONFIG_BT_ATH3K=y
CONFIG_BT_MTKSDIO=y
CONFIG_BT_MTKUART=y
CONFIG_BT_QTILINUX=y

# Wireless LAN
CONFIG_WLAN=y

# Wireless LAN drivers
CONFIG_WLAN_VENDOR_ADMTEK=y
CONFIG_ADM8211=m
CONFIG_WLAN_VENDOR_ATH=y
CONFIG_ATH_DEBUG=y
CONFIG_ATH5K=m
CONFIG_ATH5K_DEBUG=y
CONFIG_ATH5K_TRACER=y
CONFIG_ATH5K_PCI=y
CONFIG_ATH9K_HW=m
CONFIG_ATH9K_COMMON=m
CONFIG_ATH9K_BTCOEX_SUPPORT=y
CONFIG_ATH9K=m
CONFIG_ATH9K_PCI=y
CONFIG_ATH9K_AHB=y
CONFIG_ATH9K_DEBUGFS=y
CONFIG_ATH9K_STATION_STATISTICS=y
CONFIG_ATH9K_TX99=y
CONFIG_ATH9K_DFS_CERTIFIED=y
CONFIG_ATH9K_DYNACK=y
CONFIG_ATH9K_WOW=y
CONFIG_ATH9K_RFKILL=y
CONFIG_ATH9K_CHANNEL_CONTEXT=y
CONFIG_ATH9K_PCOEM=y
CONFIG_ATH9K_HTC=m
CONFIG_ATH9K_HTC_DEBUGFS=y
CONFIG_ATH9K_HWRNG=y
CONFIG_CARL9170=m
CONFIG_CARL9170_LEDS=y
CONFIG_CARL9170_DEBUGFS=y
CONFIG_CARL9170_WPC=y
CONFIG_CARL9170_HWRNG=y
CONFIG_ATH6KL=m
CONFIG_ATH6KL_SDIO=m
CONFIG_ATH6KL_USB=m
CONFIG_ATH6KL_DEBUG=y
CONFIG_ATH6KL_TRACING=y
CONFIG_AR5523=m
CONFIG_WIL6210=m
CONFIG_WIL6210_ISR_COR=y
CONFIG_WIL6210_TRACING=y
CONFIG_WIL6210_DEBUGFS=y
CONFIG_ATH10K=m
CONFIG_ATH10K_CE=y
CONFIG_ATH10K_PCI=m
CONFIG_ATH10K_SDIO=m
CONFIG_ATH10K_USB=m
CONFIG_ATH10K_DEBUG=y
CONFIG_ATH10K_DEBUGFS=y
CONFIG_ATH10K_SPECTRAL=y
CONFIG_ATH10K_TRACING=y
CONFIG_WCN36XX=m
CONFIG_WCN36XX_DEBUGFS=y
CONFIG_ATH11K=m
CONFIG_ATH11K_AHB=y
CONFIG_ATH11K_PCI=y
CONFIG_ATH11K_DEBUG=y
CONFIG_ATH11K_DEBUGFS=y
CONFIG_ATH11K_TRACING=y
CONFIG_ATH11K_SPECTRAL=y
CONFIG_WLAN_VENDOR_ATMEL=y
CONFIG_ATMEL=m
CONFIG_PCI_ATMEL=m
CONFIG_PCMCIA_ATMEL=m
CONFIG_AT76C50X_USB=m
CONFIG_WLAN_VENDOR_BROADCOM=y
CONFIG_B43=m
CONFIG_B43_BCMA=y
CONFIG_B43_SSB=y
CONFIG_B43_BUSES_BCMA_AND_SSB=y
CONFIG_B43_PCI_AUTOSELECT=y
CONFIG_B43_PCICORE_AUTOSELECT=y
CONFIG_B43_SDIO=y
CONFIG_B43_BCMA_PIO=y
CONFIG_B43_PIO=y
CONFIG_B43_PHY_G=y
CONFIG_B43_PHY_N=y
CONFIG_B43_PHY_LP=y
CONFIG_B43_PHY_HT=y
CONFIG_B43_LEDS=y
CONFIG_B43_HWRNG=y
CONFIG_B43_DEBUG=y
CONFIG_B43LEGACY=m
CONFIG_B43LEGACY_PCI_AUTOSELECT=y
CONFIG_B43LEGACY_PCICORE_AUTOSELECT=y
CONFIG_B43LEGACY_LEDS=y
CONFIG_B43LEGACY_HWRNG=y
CONFIG_B43LEGACY_DEBUG=y
CONFIG_B43LEGACY_DMA=y
CONFIG_B43LEGACY_PIO=y
CONFIG_B43LEGACY_DMA_AND_PIO_MODE=y
CONFIG_BRCMUTIL=m
CONFIG_BRCMSMAC=m
CONFIG_BRCMSMAC_LEDS=y
CONFIG_BRCMFMAC=m
CONFIG_BRCMFMAC_PROTO_BCDC=y
CONFIG_BRCMFMAC_PROTO_MSGBUF=y
CONFIG_BRCMFMAC_SDIO=y
CONFIG_BRCMFMAC_USB=y
CONFIG_BRCMFMAC_PCIE=y
CONFIG_BRCM_TRACING=y
CONFIG_BRCMDBG=y
CONFIG_WLAN_VENDOR_CISCO=y
CONFIG_AIRO=m
CONFIG_AIRO_CS=m
CONFIG_WLAN_VENDOR_INTEL=y
CONFIG_IPW2100=m
CONFIG_IPW2100_MONITOR=y
CONFIG_IPW2100_DEBUG=y
CONFIG_IPW2200=m
CONFIG_IPW2200_MONITOR=y
CONFIG_IPW2200_RADIOTAP=y
CONFIG_IPW2200_PROMISCUOUS=y
CONFIG_IPW2200_QOS=y
CONFIG_IPW2200_DEBUG=y
CONFIG_LIBIPW=m
CONFIG_LIBIPW_DEBUG=y
CONFIG_IWLEGACY=m
CONFIG_IWL4965=m
CONFIG_IWL3945=m
CONFIG_IWLWIFI=m
CONFIG_IWLWIFI_LEDS=y
CONFIG_IWLDVM=m
CONFIG_IWLMVM=m
CONFIG_IWLWIFI_OPMODE_MODULAR=y
CONFIG_IWLWIFI_DEBUG=y
CONFIG_IWLWIFI_DEBUGFS=y
CONFIG_IWLWIFI_DEVICE_TRACING=y
CONFIG_WLAN_VENDOR_INTERSIL=y
CONFIG_HOSTAP=m
CONFIG_HOSTAP_FIRMWARE=y
CONFIG_HOSTAP_FIRMWARE_NVRAM=y
CONFIG_HOSTAP_PLX=m
CONFIG_HOSTAP_PCI=m
CONFIG_HOSTAP_CS=m
CONFIG_HERMES=m
CONFIG_HERMES_PRISM=y
CONFIG_HERMES_CACHE_FW_ON_INIT=y
CONFIG_PLX_HERMES=m
CONFIG_TMD_HERMES=m
CONFIG_NORTEL_HERMES=m
CONFIG_PCI_HERMES=m
CONFIG_PCMCIA_HERMES=m
CONFIG_PCMCIA_SPECTRUM=m
CONFIG_ORINOCO_USB=m
CONFIG_P54_COMMON=m
CONFIG_P54_USB=m
CONFIG_P54_PCI=m
CONFIG_P54_SPI=m
CONFIG_P54_LEDS=y
CONFIG_WLAN_VENDOR_MARVELL=y
CONFIG_LIBERTAS=m
CONFIG_LIBERTAS_USB=m
CONFIG_LIBERTAS_SDIO=m
CONFIG_LIBERTAS_SPI=m
CONFIG_LIBERTAS_DEBUG=y
CONFIG_LIBERTAS_MESH=y
CONFIG_LIBERTAS_THINFIRM=m
CONFIG_LIBERTAS_THINFIRM_DEBUG=y
CONFIG_LIBERTAS_THINFIRM_USB=m
CONFIG_MWIFIEX=m
CONFIG_MWIFIEX_SDIO=m
CONFIG_MWIFIEX_PCIE=m
CONFIG_MWIFIEX_USB=m
CONFIG_MWL8K=m
CONFIG_WLAN_VENDOR_MEDIATEK=y
CONFIG_MT7601U=m
CONFIG_MT7603E=m
CONFIG_MT7615E=m
CONFIG_MT7663U=m
CONFIG_MT7663S=m
CONFIG_MT7915E=m
CONFIG_MT7921E=m
CONFIG_WLAN_VENDOR_MICROCHIP=y
CONFIG_WILC1000=m
CONFIG_WILC1000_SDIO=m
CONFIG_WILC1000_SPI=m
CONFIG_WILC1000_HW_OOB_INTR=y
CONFIG_WLAN_VENDOR_RALINK=y
CONFIG_RT2X00=m
CONFIG_RT2400PCI=m
CONFIG_RT2500PCI=m
CONFIG_RT61PCI=m
CONFIG_RT2800PCI=m
CONFIG_RT2800PCI_RT33XX=y
CONFIG_RT2800PCI_RT35XX=y
CONFIG_RT2800PCI_RT53XX=y
CONFIG_RT2800PCI_RT3290=y
CONFIG_RT2500USB=m
CONFIG_RT73USB=m
CONFIG_RT2800USB=m
CONFIG_RT2800USB_RT33XX=y
CONFIG_RT2800USB_RT35XX=y
CONFIG_RT2800USB_RT3573=y
CONFIG_RT2800USB_RT53XX=y
CONFIG_RT2800USB_RT55XX=y
CONFIG_RT2800USB_UNKNOWN=y
CONFIG_RT2800_LIB=m
CONFIG_RT2800_LIB_MMIO=m
CONFIG_RT2X00_LIB_MMIO=m
CONFIG_RT2X00_LIB_PCI=m
CONFIG_RT2X00_LIB_USB=m
CONFIG_RT2X00_LIB=m
CONFIG_RT2X00_LIB_FIRMWARE=y
CONFIG_RT2X00_LIB_CRYPTO=y
CONFIG_RT2X00_LIB_LEDS=y
CONFIG_RT2X00_LIB_DEBUGFS=y
CONFIG_RT2X00_DEBUG=y
CONFIG_WLAN_VENDOR_REALTEK=y
CONFIG_RTL8180=m
CONFIG_RTL8187=m
CONFIG_RTL8187_LEDS=y
CONFIG_RTL_CARDS=m
CONFIG_RTL8192CE=m
CONFIG_RTL8192SE=m
CONFIG_RTL8192DE=m
CONFIG_RTL8723AE=m
CONFIG_RTL8723BE=m
CONFIG_RTL8188EE=m
CONFIG_RTLBTCOEXIST=m
CONFIG_RTL8723_COMMON=m
CONFIG_RTL8821AE=m
CONFIG_RTL8192CU=m
CONFIG_RTLWIFI=m
CONFIG_RTLWIFI_PCI=m
CONFIG_RTLWIFI_USB=m
CONFIG_RTLWIFI_DEBUG=y
CONFIG_RTL8192C_COMMON=m
CONFIG_RTL8723BS=m
CONFIG_R8712U=m
CONFIG_R8188EU=m
CONFIG_RTS5208=m
CONFIG_RTL8822BU=m
CONFIG_RTL8821CU=m
CONFIG_RTL8822CS=m
CONFIG_88XXAU=m
CONFIG_RTL8192EU=m
CONFIG_RTL8188FU=m
CONFIG_WLAN_VENDOR_RSI=y
CONFIG_RSI_91X=m
CONFIG_RSI_DEBUGFS=y
CONFIG_RSI_SDIO=m
CONFIG_RSI_USB=m
CONFIG_RSI_COEX=y
CONFIG_WLAN_VENDOR_ST=y
CONFIG_CW1200=m
CONFIG_CW1200_WLAN_SDIO=m
CONFIG_CW1200_WLAN_SPI=m
CONFIG_WLAN_VENDOR_TI=y
CONFIG_WL1251=m
CONFIG_WL1251_SDIO=m
CONFIG_WL1251_SPI=m
CONFIG_WL12XX=m
CONFIG_WL18XX=m
CONFIG_WLCORE=m
CONFIG_WLCORE_SDIO=m
CONFIG_WLAN_VENDOR_ZYDAS=y
CONFIG_USB_ZD1201=m
CONFIG_ZD1211RW=m
CONFIG_ZD1211RW_DEBUG=y
CONFIG_WLAN_VENDOR_QUANTENNA=y
CONFIG_QTNFMAC=m
CONFIG_QTNFMAC_PCIE=m
CONFIG_PCMCIA_RAYCS=m
CONFIG_PCMCIA_WL3501=m
CONFIG_MAC80211_HWSIM=m
CONFIG_USB_NET_RNDIS_WLAN=m
CONFIG_VIRT_WIFI=m

# Enable mac80211 mesh support
CONFIG_MAC80211_MESH=y

# Enable LED triggers
CONFIG_MAC80211_LEDS=y

# Enable debugfs
CONFIG_MAC80211_DEBUGFS=y

# Enable frame injection
CONFIG_MAC80211_INJECT=y
EOF
    
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
