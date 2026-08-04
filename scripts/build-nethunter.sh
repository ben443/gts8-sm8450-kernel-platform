#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GKI_SCRIPT="${REPO_ROOT}/build_kernel_GKI.sh"

BUILD_TARGET_DEFAULT="gts8wifi_eur_open"

usage() {
  cat << 'USAGE'
Usage: ./scripts/build-nethunter.sh <command>

Commands:
  full       Build Samsung sec gki kernel with NetHunter fragment enabled (default)
  build      Same as full
  configure  Alias of full (Samsung build flow configures during build)
  package    Alias of full (Samsung build flow packages during build)
  verify     Verify expected NetHunter config options in the resulting .config
  clean      Remove local build outputs
  help       Show this message
USAGE
}

run_build() {
  if [ ! -x "${GKI_SCRIPT}" ]; then
    chmod +x "${GKI_SCRIPT}"
  fi

  export BUILD_TARGET="${BUILD_TARGET:-${BUILD_TARGET_DEFAULT}}"
  export NETHUNTER_ENABLE="${NETHUNTER_ENABLE:-1}"

  echo "BUILD_TARGET=${BUILD_TARGET} NETHUNTER_ENABLE=${NETHUNTER_ENABLE}"
  (cd "${REPO_ROOT}" && ./build_kernel_GKI.sh)
}

verify_config() {
  local cfg="${REPO_ROOT}/device/qcom/gki-kernel/.config"

  if [ ! -f "${cfg}" ]; then
    cfg="$(find "${REPO_ROOT}/out" -path "*/dist/.config" | head -n 1 || true)"
  fi

  if [ -z "${cfg}" ] || [ ! -f "${cfg}" ]; then
    echo "No built .config found. Run a build first."
    return 1
  fi

  echo "Using config: ${cfg}"
  grep -E '^CONFIG_(USB_SERIAL|USB_MON|USB_NET_RNDIS_HOST|USB_NET_QMI_WWAN|BT_BNEP|ATH9K_HTC|MT7601U|R8188EU)=' "${cfg}" || true
}

clean_outputs() {
  rm -rf "${REPO_ROOT}/out" "${REPO_ROOT}/device/qcom"/*-kernel
  echo "Cleaned out/ and device/qcom/*-kernel"
}

cmd="${1:-full}"

case "${cmd}" in
  full|build|configure|package)
    run_build
    ;;
  verify)
    verify_config
    ;;
  clean)
    clean_outputs
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
