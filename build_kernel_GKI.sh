#!/bin/bash
set -euo pipefail

BUILD_TARGET="${BUILD_TARGET:-gts8wifi_eur_open}"
export MODEL=$(echo "$BUILD_TARGET" | cut -d'_' -f1)
export PROJECT_NAME=${MODEL}
export REGION=$(echo "$BUILD_TARGET" | cut -d'_' -f2)
export CARRIER=$(echo "$BUILD_TARGET" | cut -d'_' -f3)
export TARGET_BUILD_VARIANT=user

CHIPSET_NAME=waipio
cd "$(dirname "$(readlink -f "$0")")"
export ANDROID_BUILD_TOP=$(pwd)
export TARGET_PRODUCT=gki
export TARGET_BOARD_PLATFORM=gki

export ANDROID_PRODUCT_OUT=${ANDROID_BUILD_TOP}/out/target/product/${MODEL}
export OUT_DIR=${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}

# Curated prebuilt output. prepare_vendor.sh derives this from
# TARGET_BOARD_PLATFORM; set it explicitly so it is unambiguous.
export ANDROID_KERNEL_OUT=${ANDROID_BUILD_TOP}/device/qcom/${TARGET_BOARD_PLATFORM}-kernel

# for Lcd(techpack) driver build
export KBUILD_EXTRA_SYMBOLS=${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/mmrm-driver/Module.symvers

# for Audio(techpack) driver build
export MODNAME=audio_dlkm

export KBUILD_EXT_MODULES="../vendor/qcom/opensource/datarmnet-ext/wlan \
  ../vendor/qcom/opensource/datarmnet/core \
  ../vendor/qcom/opensource/mmrm-driver \
  ../vendor/qcom/opensource/audio-kernel \
  ../vendor/qcom/opensource/camera-kernel \
  ../vendor/qcom/opensource/display-drivers/msm \
"

# prepare_vendor.sh runs its Android-integration stage only when BOTH
# ANDROID_PRODUCT_OUT and ANDROID_BUILD_TOP are set. That stage deletes every
# Android.mk/Android.bp under kernel_platform/ and then requires bionic/,
# device/, and vendor/*-devicetree from a full platform tree. On a kernel-only
# checkout it fails *after* the kernel has already been built. Skip it.
if [ ! -d "${ANDROID_BUILD_TOP}/bionic/libc/kernel/uapi" ]; then
  echo "NOTE: no bionic/ - skipping prepare_vendor.sh Android integration stage"
  unset ANDROID_PRODUCT_OUT
fi

RECOMPILE_KERNEL=1 ./kernel_platform/build/android/prepare_vendor.sh sec ${TARGET_PRODUCT}
