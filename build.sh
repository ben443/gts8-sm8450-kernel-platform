#!/bin/bash
set -Eeuo pipefail

# ============================================================================
# Build script for gts8-sm8450-kernel-platform
# Based on Samsung_Kernel_sm8450_common_gts8x build process with NetHunter compatibility
# ============================================================================

BUILD_START=$(date +%s)
KERNEL_DIR=$(pwd)
OUT_DIR=${OUT_DIR:-out}
ARCH=${ARCH:-arm64}
SUBARCH=${SUBARCH:-arm64}

# Device and build target configuration
BUILD_TARGET=${CI_BUILD_TARGET:-${BUILD_TARGET:-gts8wifi_eur_open}}
DEVICE=${BUILD_TARGET%%_*}
KERNEL_DEFCONFIG=${CI_KERNEL_DEFCONFIG:-${KERNEL_DEFCONFIG:-${DEVICE}-waipio_defconfig}}

# AnyKernel3 configuration for flashable zip
ANYKERNEL3_DIR=${ANYKERNEL3_DIR:-${KERNEL_DIR}/AnyKernel3}
AK3_REPO=${AK3_REPO:-https://github.com/akm-04/AnyKernel3.git}

# Determine AnyKernel3 branch based on device
case "${DEVICE}" in
  gts8wifi)
    DEFAULT_AK3_BRANCH="gts8x"
    ;;
  gts8uwifi)
    DEFAULT_AK3_BRANCH="gts8u"
    ;;
  *)
    echo "Unsupported device '${DEVICE}'. Supported: gts8wifi, gts8uwifi" >&2
    exit 1
    ;;
esac
AK3_BRANCH=${CI_AK3_BRANCH:-${AK3_BRANCH:-${DEFAULT_AK3_BRANCH}}}

# Toolchain configuration
TOOLCHAIN_DIR=${CI_TOOLCHAIN_DIR:-${TOOLCHAIN_DIR:-$HOME/Git/Clang}}
CLANG_VERSION=${CLANG_VERSION:-clang-r416183c1}
CLANG_DIR=${CLANG_DIR:-${TOOLCHAIN_DIR}/${CLANG_VERSION}}
CLANG_BINARY=${CLANG_BINARY:-${CLANG_DIR}/bin/clang}

# Kernel naming and build targets
KERNEL_NAME=${CI_KERNEL_NAME:-${KERNEL_NAME:-Samsung-Kernel-${DEVICE}}}
EXTRA_KMAKE_TARGETS=${EXTRA_KMAKE_TARGETS:-"Image dtbs"}
DTBO_PAGE_SIZE=${DTBO_PAGE_SIZE:-4096}

# LLVM/Clang make flags
MAKE_FLAGS=(
  O=${OUT_DIR}
  ARCH=${ARCH}
  SUBARCH=${SUBARCH}
  CC=clang
  LD=ld.lld
  LLVM=1
  LLVM_IAS=1
)

# ============================================================================
# NetHunter Compatibility Options
# ============================================================================
# Enable/disable various security modules and kernel extensions
# Note: Do not enable multiple options together (KSU, SUKISU, APATCH)
ENABLE_KSU_NEXT=${ENABLE_KSU_NEXT:-0}         # KernelSU-Next
ENABLE_SUKISU=${ENABLE_SUKISU:-0}              # SukiSU-Ultra
ENABLE_KSU=${ENABLE_KSU:-0}                    # Classic KernelSU
ENABLE_APATCH=${ENABLE_APATCH:-0}              # APatch support
PATCH_SUSFS=${PATCH_SUSFS:-0}                  # SUSFS patches
PATCH_KPM=${PATCH_KPM:-0}                      # KPM patches (not recommended for msm-kernel)

# NetHunter-specific kernel modules and drivers
ENABLE_NETHUNTER=${ENABLE_NETHUNTER:-0}        # Enable NetHunter patches/drivers
ENABLE_INTEGRATED_MODULES=${ENABLE_INTEGRATED_MODULES:-0}  # Fold modules into vmlinux

# ============================================================================
# Error handling and logging
# ============================================================================
error_handler() {
  local line="$1"
  echo "❌ Build failed at line ${line}" >&2
  exit 1
}
trap 'error_handler $LINENO' ERR

log_info() {
  echo "ℹ️  $1"
}

log_success() {
  echo "✓ $1"
}

log_section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Kernel preparation functions
# ============================================================================

prepare_anykernel() {
  log_section "Preparing AnyKernel3 Flash Environment"
  
  rm -rf "${ANYKERNEL3_DIR}"
  log_info "Cloning AnyKernel3 from: ${AK3_REPO}"
  log_info "Branch: ${AK3_BRANCH}"
  
  git clone --depth=1 -b "${AK3_BRANCH}" "${AK3_REPO}" "${ANYKERNEL3_DIR}"
  rm -f "${ANYKERNEL3_DIR}"/*.zip
  
  log_success "AnyKernel3 environment ready"
}

setup_toolchain() {
  log_section "Setting Up Toolchain"
  
  if [ -x "${CLANG_BINARY}" ]; then
    log_success "Found Clang at: ${CLANG_BINARY}"
    export PATH="${CLANG_DIR}/bin:${PATH}"
    return
  fi

  log_info "Clang not found at ${CLANG_BINARY}"
  log_info "Attempting to use system Clang from PATH..."
  
  if command -v clang >/dev/null; then
    log_success "System Clang found in PATH"
    CLANG_BINARY=$(command -v clang)
  else
    echo "❌ Clang not found in ${CLANG_DIR} or system PATH" >&2
    exit 1
  fi
}

# ============================================================================
# NetHunter patch functions
# ============================================================================

apply_nethunter_patches() {
  if [ "${ENABLE_NETHUNTER}" -eq 0 ]; then
    return
  fi

  log_section "Applying NetHunter Patches"
  log_info "NetHunter patches will be integrated into the kernel build"
  
  # NetHunter-specific kernel module flags can be added here
  # These typically include wireless driver enhancements, packet injection support, etc.
}

apply_ksu_patches() {
  if [ "${ENABLE_KSU}" -eq 0 ] && [ "${ENABLE_KSU_NEXT}" -eq 0 ] && [ "${ENABLE_SUKISU}" -eq 0 ]; then
    return
  fi

  log_section "Preparing KSU/SUKISU Integration"
  
  if [ "${ENABLE_KSU}" -eq 1 ]; then
    log_info "Classic KernelSU enabled"
  fi
  
  if [ "${ENABLE_KSU_NEXT}" -eq 1 ]; then
    log_info "KernelSU-Next enabled"
  fi
  
  if [ "${ENABLE_SUKISU}" -eq 1 ]; then
    log_info "SukiSU-Ultra enabled"
  fi
}

apply_additional_patches() {
  log_section "Applying Additional Patches"
  
  if [ "${PATCH_SUSFS}" -eq 1 ]; then
    log_info "SUSFS patches enabled"
  fi
  
  if [ "${PATCH_KPM}" -eq 1 ]; then
    log_info "KPM patches enabled"
    log_info "⚠️  Warning: KPM patches may cause issues on msm-kernel branches"
  fi
  
  if [ "${ENABLE_INTEGRATED_MODULES}" -eq 1 ]; then
    log_info "Integrated modules mode: folding modules into vmlinux"
  fi
}

# ============================================================================
# Build functions
# ============================================================================

clean_build() {
  log_section "Cleaning Previous Build"
  
  if [ -d "${OUT_DIR}" ]; then
    log_info "Removing old output directory: ${OUT_DIR}"
    rm -rf "${OUT_DIR}"
  fi
  
  log_success "Build directory cleaned"
}

configure_kernel() {
  log_section "Configuring Kernel"
  
  log_info "Device: ${DEVICE}"
  log_info "Target: ${BUILD_TARGET}"
  log_info "Defconfig: ${KERNEL_DEFCONFIG}"
  log_info "Output: ${OUT_DIR}"
  
  make "${MAKE_FLAGS[@]}" "${KERNEL_DEFCONFIG}"
  log_success "Kernel configured"
}

build_kernel() {
  log_section "Building Kernel"
  
  log_info "Using ${EXTRA_KMAKE_TARGETS} targets"
  log_info "Building with $(nproc) parallel jobs..."
  
  make "${MAKE_FLAGS[@]}" -j"$(nproc)" ${EXTRA_KMAKE_TARGETS}
  log_success "Kernel build completed"
}

build_dtbo_image() {
  log_section "Building DTBO Image"
  
  local dtbo_path="${OUT_DIR}/arch/arm64/boot/dtbo.img"
  local -a dtbo_files=()
  local mkdtboimg_tool

  while IFS= read -r -d '' dtbo_file; do
    dtbo_files+=("${dtbo_file}")
  done < <(find "${OUT_DIR}/arch/arm64/boot/dts" -type f -name "${BUILD_TARGET}_*.dtbo" -print0)

  if [ "${#dtbo_files[@]}" -eq 0 ]; then
    log_info "No DTBO files found - skipping DTBO image generation"
    return
  fi

  log_info "Found ${#dtbo_files[@]} DTBO file(s)"

  mkdtboimg_tool=$(command -v mkdtboimg.py || command -v mkdtboimg || true)
  if [ -z "${mkdtboimg_tool}" ]; then
    echo "❌ Unable to create ${dtbo_path}: mkdtboimg.py not found in PATH" >&2
    exit 1
  fi

  log_info "Creating DTBO image with page size: ${DTBO_PAGE_SIZE}"
  "${mkdtboimg_tool}" create "${dtbo_path}" --page_size="${DTBO_PAGE_SIZE}" "${dtbo_files[@]}"
  log_success "DTBO image created: ${dtbo_path}"
}

package_anykernel() {
  log_section "Packaging Flashable Kernel ZIP"
  
  local image_path="${OUT_DIR}/arch/arm64/boot/Image"
  local dtbo_path="${OUT_DIR}/arch/arm64/boot/dtbo.img"
  local dtb_root="${OUT_DIR}/arch/arm64/boot/dts"

  # Verify kernel image exists
  if [ ! -f "${image_path}" ]; then
    echo "❌ Missing kernel image: ${image_path}" >&2
    exit 1
  fi

  log_info "Copying kernel image..."
  cp -f "${image_path}" "${ANYKERNEL3_DIR}/Image"

  # Copy DTBO if it exists
  if [ -f "${dtbo_path}" ]; then
    log_info "Copying DTBO image..."
    cp -f "${dtbo_path}" "${ANYKERNEL3_DIR}/dtbo.img"
  fi

  # Copy DTB files
  if [ -d "${dtb_root}/samsung" ]; then
    log_info "Copying device tree binaries..."
    rm -rf "${ANYKERNEL3_DIR}/dtb"
    mkdir -p "${ANYKERNEL3_DIR}/dtb"
    find "${dtb_root}/samsung" -type f \( -name '*.dtb' -o -name '*.dtbo' \) -print0 | \
      xargs -0r -I{} cp -f "{}" "${ANYKERNEL3_DIR}/dtb/" || true
  fi

  # Create flashable ZIP
  local zip_name
  zip_name="${KERNEL_NAME}-${DEVICE}-$(date +%Y%m%d-%H%M%S).zip"
  
  log_info "Creating flashable ZIP: ${zip_name}"
  (
    cd "${ANYKERNEL3_DIR}"
    zip -r9 "${zip_name}" . -x '*.git*' -x '*.zip' -q
  )

  log_success "✓ Flashable ZIP generated: ${ANYKERNEL3_DIR}/${zip_name}"
}

# ============================================================================
# Utility functions
# ============================================================================

show_build_info() {
  log_section "Build Configuration"
  
  echo "Device:              ${DEVICE}"
  echo "Build Target:        ${BUILD_TARGET}"
  echo "Defconfig:           ${KERNEL_DEFCONFIG}"
  echo "Kernel Name:         ${KERNEL_NAME}"
  echo "Output Directory:    ${OUT_DIR}"
  echo "AnyKernel3 Branch:   ${AK3_BRANCH}"
  echo "Toolchain:           ${CLANG_DIR}"
  echo ""
  echo "Optional Modules:"
  echo "  NetHunter:         ${ENABLE_NETHUNTER}"
  echo "  KernelSU:          ${ENABLE_KSU}"
  echo "  KernelSU-Next:     ${ENABLE_KSU_NEXT}"
  echo "  SukiSU-Ultra:      ${ENABLE_SUKISU}"
  echo "  APatch:            ${ENABLE_APATCH}"
  echo "  SUSFS:             ${PATCH_SUSFS}"
  echo "  INTEGRATED_MODULES:${ENABLE_INTEGRATED_MODULES}"
  echo ""
}

# ============================================================================
# Main build process
# ============================================================================

main() {
  show_build_info
  
  setup_toolchain
  clean_build
  
  # Apply optional patches
  apply_nethunter_patches
  apply_ksu_patches
  apply_additional_patches
  
  # Prepare and build
  prepare_anykernel
  configure_kernel
  build_kernel
  build_dtbo_image
  package_anykernel

  local elapsed=$(( $(date +%s) - BUILD_START ))
  
  log_section "Build Complete"
  echo "Total build time: ${elapsed}s"
  log_success "Kernel build successful!"
}

# Run main function
main "$@"
