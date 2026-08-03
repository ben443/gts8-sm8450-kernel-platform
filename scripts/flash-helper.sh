#!/bin/bash
################################################################################
# NetHunter Kernel Flash Helper for Samsung Galaxy Tab S8 (gts8wifi/SM-X700)
# Helper script for flashing and managing NetHunter kernel
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Device info
DEVICE_CODENAME="gts8wifi"
DEVICE_MODEL="SM-X700"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"

################################################################################
# Helper Functions
################################################################################

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

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║              NetHunter Flash Helper for Galaxy Tab S8                        ║"
    echo "║                         gts8wifi (SM-X700)                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

################################################################################
# Check Device Connection
################################################################################

check_device() {
    log_step "Checking device connection..."
    
    if ! adb devices | grep -q "device$"; then
        log_error "No device connected in ADB mode!"
        log_info "Please connect your device with USB debugging enabled."
        return 1
    fi
    
    DEVICE=$(adb shell getprop ro.product.device 2>/dev/null || echo "unknown")
    MODEL=$(adb shell getprop ro.product.model 2>/dev/null || echo "unknown")
    
    log_info "Connected device: ${MODEL} (${DEVICE})"
    
    if [[ "${DEVICE}" != *"gts8"* ]] && [[ "${DEVICE}" != "${DEVICE_CODENAME}" ]]; then
        log_warn "Device codename mismatch! Expected: ${DEVICE_CODENAME}, Found: ${DEVICE}"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

################################################################################
# Check Root Access
################################################################################

check_root() {
    log_step "Checking root access..."
    
    if ! adb shell "su -c 'id'" | grep -q "uid=0"; then
        log_error "Root access not available!"
        log_info "Please ensure your device is rooted with Magisk or similar."
        return 1
    fi
    
    log_info "Root access confirmed!"
    return 0
}

################################################################################
# Backup Current Kernel
################################################################################

backup_kernel() {
    log_step "Backing up current kernel..."
    
    BACKUP_DIR="${SCRIPT_DIR}/backups"
    mkdir -p "${BACKUP_DIR}"
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/boot_backup_${TIMESTAMP}.img"
    
    log_info "Dumping current boot image..."
    adb shell "su -c 'dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot_backup.img'"
    adb pull /sdcard/boot_backup.img "${BACKUP_FILE}"
    adb shell "rm /sdcard/boot_backup.img"
    
    if [ -f "${BACKUP_FILE}" ]; then
        log_info "Backup saved to: ${BACKUP_FILE}"
        echo "${BACKUP_FILE}" > "${BACKUP_DIR}/latest_backup.txt"
    else
        log_error "Backup failed!"
        return 1
    fi
    
    return 0
}

################################################################################
# Restore Kernel Backup
################################################################################

restore_backup() {
    log_step "Restoring kernel backup..."
    
    BACKUP_DIR="${SCRIPT_DIR}/backups"
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        log_error "No backup directory found!"
        return 1
    fi
    
    # List available backups
    echo "Available backups:"
    ls -1t "${BACKUP_DIR}"/boot_backup_*.img 2>/dev/null || {
        log_error "No backups found!"
        return 1
    }
    
    read -p "Enter backup filename (or press Enter for latest): " backup_file
    
    if [ -z "$backup_file" ]; then
        if [ -f "${BACKUP_DIR}/latest_backup.txt" ]; then
            backup_file=$(cat "${BACKUP_DIR}/latest_backup.txt")
        else
            backup_file=$(ls -1t "${BACKUP_DIR}"/boot_backup_*.img | head -1)
        fi
    else
        backup_file="${BACKUP_DIR}/${backup_file}"
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_info "Restoring from: $backup_file"
    
    # Push backup to device
    adb push "$backup_file" /sdcard/boot_restore.img
    
    # Flash backup
    adb shell "su -c 'dd if=/sdcard/boot_restore.img of=/dev/block/bootdevice/by-name/boot'"
    adb shell "rm /sdcard/boot_restore.img"
    
    log_info "Backup restored successfully!"
    log_info "Rebooting device..."
    adb reboot
}

################################################################################
# Flash Kernel via Fastboot
################################################################################

flash_fastboot() {
    log_step "Flashing kernel via Fastboot..."
    
    # Find kernel image
    if [ -f "${OUTPUT_DIR}/kernel/Image.gz" ]; then
        KERNEL_IMG="${OUTPUT_DIR}/kernel/Image.gz"
    elif [ -f "${OUTPUT_DIR}/kernel/Image" ]; then
        KERNEL_IMG="${OUTPUT_DIR}/kernel/Image"
    else
        log_error "Kernel image not found in ${OUTPUT_DIR}/kernel/"
        return 1
    fi
    
    # Create boot image if needed
    if [ ! -f "${OUTPUT_DIR}/boot.img" ]; then
        log_info "Creating boot image..."
        
        # Check for ramdisk
        if [ ! -f "${SCRIPT_DIR}/ramdisk.gz" ]; then
            log_warn "Ramdisk not found. Attempting to extract from current boot..."
            adb shell "su -c 'dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/current_boot.img'"
            adb pull /sdcard/current_boot.img "${OUTPUT_DIR}/current_boot.img"
            adb shell "rm /sdcard/current_boot.img"
            
            # Extract ramdisk using magiskboot if available
            if command -v magiskboot &> /dev/null; then
                magiskboot unpack "${OUTPUT_DIR}/current_boot.img"
                mv ramdisk.cpio "${SCRIPT_DIR}/ramdisk.gz"
            else
                log_error "magiskboot not found. Please install Magisk or provide ramdisk.gz"
                return 1
            fi
        fi
        
        # Create boot image
        if command -v magiskboot &> /dev/null; then
            magiskboot repack "${OUTPUT_DIR}/current_boot.img" "${OUTPUT_DIR}/boot.img"
        else
            log_error "magiskboot not found. Cannot create boot image."
            return 1
        fi
    fi
    
    # Reboot to bootloader
    log_info "Rebooting to bootloader..."
    adb reboot bootloader
    
    sleep 5
    
    # Check fastboot connection
    if ! fastboot devices | grep -q "fastboot"; then
        log_error "Device not in fastboot mode!"
        return 1
    fi
    
    # Flash boot image
    log_info "Flashing boot image..."
    fastboot flash boot "${OUTPUT_DIR}/boot.img"
    
    # Reboot
    log_info "Rebooting device..."
    fastboot reboot
    
    log_info "Kernel flashed successfully!"
    return 0
}

################################################################################
# Flash Kernel via TWRP
################################################################################

flash_twrp() {
    log_step "Flashing kernel via TWRP..."
    
    # Find AnyKernel zip
    AK_ZIP=$(ls -1t "${OUTPUT_DIR}"/*.zip 2>/dev/null | head -1)
    
    if [ -z "$AK_ZIP" ]; then
        log_error "No AnyKernel zip found in ${OUTPUT_DIR}/"
        log_info "Please run the build script first to create a flashable zip."
        return 1
    fi
    
    log_info "Found: $(basename "$AK_ZIP")"
    
    # Push zip to device
    log_info "Pushing kernel zip to device..."
    adb push "$AK_ZIP" /sdcard/
    
    # Reboot to recovery
    log_info "Rebooting to TWRP..."
    adb reboot recovery
    
    log_info "Please install the zip from /sdcard/$(basename "$AK_ZIP") in TWRP"
    log_info "After flashing, reboot to system."
    
    return 0
}

################################################################################
# Flash Kernel via Magisk
################################################################################

flash_magisk() {
    log_step "Flashing kernel via Magisk..."
    
    # Find AnyKernel zip
    AK_ZIP=$(ls -1t "${OUTPUT_DIR}"/*.zip 2>/dev/null | head -1)
    
    if [ -z "$AK_ZIP" ]; then
        log_error "No AnyKernel zip found in ${OUTPUT_DIR}/"
        return 1
    fi
    
    log_info "Found: $(basename "$AK_ZIP")"
    
    # Push zip to device
    log_info "Pushing kernel zip to device..."
    adb push "$AK_ZIP" /sdcard/Download/
    
    log_info "Kernel zip pushed to /sdcard/Download/"
    log_info "Please install via Magisk Manager:"
    log_info "  1. Open Magisk Manager"
    log_info "  2. Go to Modules"
    log_info "  3. Select 'Install from storage'"
    log_info "  4. Choose $(basename "$AK_ZIP")"
    log_info "  5. Reboot device"
    
    return 0
}

################################################################################
# Test Kernel (Temporary Boot)
################################################################################

test_kernel() {
    log_step "Testing kernel (temporary boot)..."
    
    if [ ! -f "${OUTPUT_DIR}/boot.img" ]; then
        log_error "boot.img not found!"
        return 1
    fi
    
    # Reboot to bootloader
    log_info "Rebooting to bootloader..."
    adb reboot bootloader
    
    sleep 5
    
    # Check fastboot connection
    if ! fastboot devices | grep -q "fastboot"; then
        log_error "Device not in fastboot mode!"
        return 1
    fi
    
    # Boot kernel temporarily
    log_info "Booting test kernel..."
    fastboot boot "${OUTPUT_DIR}/boot.img"
    
    log_info "Test kernel booted!"
    log_info "If the device boots successfully, you can flash permanently."
    log_info "If not, simply reboot to restore original kernel."
    
    return 0
}

################################################################################
# Check Kernel Status
################################################################################

check_kernel() {
    log_step "Checking kernel status..."
    
    if ! check_device; then
        return 1
    fi
    
    log_info "Kernel version:"
    adb shell uname -r
    
    log_info "Kernel command line:"
    adb shell cat /proc/cmdline | head -c 200
    echo ""
    
    log_info "Loaded modules:"
    adb shell "su -c 'lsmod'" | head -20
    
    log_info "USB devices:"
    adb shell "su -c 'lsusb'" 2>/dev/null || adb shell "cat /sys/kernel/debug/usb/devices" 2>/dev/null | head -30
    
    log_info "Network interfaces:"
    adb shell "su -c 'ifconfig -a'" | head -30
    
    return 0
}

################################################################################
# Install WiFi Drivers
################################################################################

install_wifi_drivers() {
    log_step "Installing WiFi drivers..."
    
    if ! check_device; then
        return 1
    fi
    
    if ! check_root; then
        return 1
    fi
    
    MODULES_DIR="${OUTPUT_DIR}/modules"
    
    if [ ! -d "${MODULES_DIR}" ]; then
        log_error "Modules directory not found!"
        return 1
    fi
    
    # Push modules to device
    log_info "Pushing WiFi driver modules..."
    adb push "${MODULES_DIR}" /sdcard/nethunter_modules
    
    # Install modules
    log_info "Installing modules..."
    adb shell "su -c 'cp /sdcard/nethunter_modules/*.ko /system/lib/modules/'" 2>/dev/null || \
    adb shell "su -c 'cp /sdcard/nethunter_modules/*.ko /vendor/lib/modules/'" 2>/dev/null || \
    adb shell "su -c 'insmod /sdcard/nethunter_modules/*.ko'"
    
    # Load specific drivers
    log_info "Loading WiFi drivers..."
    adb shell "su -c 'modprobe 88XXau'" 2>/dev/null || true
    adb shell "su -c 'modprobe r8188eu'" 2>/dev/null || true
    adb shell "su -c 'modprobe ath9k_htc'" 2>/dev/null || true
    adb shell "su -c 'modprobe mt7601u'" 2>/dev/null || true
    
    # Cleanup
    adb shell "rm -rf /sdcard/nethunter_modules"
    
    log_info "WiFi drivers installed!"
    
    return 0
}

################################################################################
# Setup NetHunter Chroot
################################################################################

setup_chroot() {
    log_step "Setting up NetHunter chroot..."
    
    if ! check_device; then
        return 1
    fi
    
    if ! check_root; then
        return 1
    fi
    
    log_info "Downloading NetHunter chroot..."
    
    # Download full chroot
    adb shell "su -c 'cd /data/local && wget https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz'"
    
    log_info "Extracting chroot..."
    adb shell "su -c 'cd /data/local && mkdir -p nhsystem && tar -xJf kalifs-arm64-full.tar.xz -C nhsystem && mv nhsystem/kalifs-* nhsystem/kali-arm64'"
    
    log_info "Setting up chroot..."
    adb shell "su -c '/data/data/com.offsec.nethunter/files/scripts/bootkali_init'"
    adb shell "su -c '/data/data/com.offsec.nethunter/files/scripts/bootkali_login'"
    
    log_info "NetHunter chroot setup complete!"
    
    return 0
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                     NetHunter Flash Helper Menu                              ║"
    echo "║                    Samsung Galaxy Tab S8 (gts8wifi)                          ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  1. Full Flash (Backup + Flash via Fastboot)                                 ║"
    echo "║  2. Backup Current Kernel                                                    ║"
    echo "║  3. Flash via Fastboot                                                       ║"
    echo "║  4. Flash via TWRP (AnyKernel zip)                                           ║"
    echo "║  5. Flash via Magisk (AnyKernel zip)                                         ║"
    echo "║  6. Test Kernel (Temporary Boot)                                             ║"
    echo "║  7. Restore Kernel Backup                                                    ║"
    echo "║  8. Check Kernel Status                                                      ║"
    echo "║  9. Install WiFi Drivers                                                     ║"
    echo "║ 10. Setup NetHunter Chroot                                                   ║"
    echo "║ 11. Exit                                                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

main() {
    print_banner
    
    while true; do
        show_menu
        read -p "Select an option [1-11]: " choice
        
        case $choice in
            1)
                if check_device && backup_kernel && flash_fastboot; then
                    log_info "Full flash completed!"
                else
                    log_error "Full flash failed!"
                fi
                ;;
            2)
                if check_device && backup_kernel; then
                    log_info "Backup completed!"
                else
                    log_error "Backup failed!"
                fi
                ;;
            3)
                if flash_fastboot; then
                    log_info "Flash completed!"
                else
                    log_error "Flash failed!"
                fi
                ;;
            4)
                if flash_twrp; then
                    log_info "TWRP flash prepared!"
                else
                    log_error "TWRP flash preparation failed!"
                fi
                ;;
            5)
                if check_device && flash_magisk; then
                    log_info "Magisk flash prepared!"
                else
                    log_error "Magisk flash preparation failed!"
                fi
                ;;
            6)
                if test_kernel; then
                    log_info "Test boot completed!"
                else
                    log_error "Test boot failed!"
                fi
                ;;
            7)
                if restore_backup; then
                    log_info "Restore completed!"
                else
                    log_error "Restore failed!"
                fi
                ;;
            8)
                check_kernel
                ;;
            9)
                if install_wifi_drivers; then
                    log_info "WiFi drivers installed!"
                else
                    log_error "WiFi driver installation failed!"
                fi
                ;;
            10)
                if setup_chroot; then
                    log_info "Chroot setup completed!"
                else
                    log_error "Chroot setup failed!"
                fi
                ;;
            11)
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
main
