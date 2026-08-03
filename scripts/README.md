# NetHunter Kernel for Samsung Galaxy Tab S8 (gts8wifi/SM-X700)

This repository contains the build environment and scripts for compiling a Kali NetHunter kernel for the **Samsung Galaxy Tab S8 (gts8wifi/SM-X700)** with the **SM8450 (Snapdragon 8 Gen 1)** chipset.

**⚠️ This device uses GKI (Generic Kernel Image). The build process has been adapted for GKI compatibility.**

![NetHunter Logo](https://www.kali.org/images/nethunter-logo.svg)

## 📋 Table of Contents

- [Overview](#overview)
- [GKI Information](#gki-information)
- [Prerequisites](#prerequisites)
- [Device Specifications](#device-specifications)
- [Features](#features)
- [Build Instructions](#build-instructions)
  - [Native Build](#native-build)
  - [Docker Build](#docker-build)
- [Installation](#installation)
- [WiFi Adapters](#wifi-adapters)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

## 🔍 Overview

This project provides a complete build environment for creating a custom NetHunter kernel for the Samsung Galaxy Tab S8. The kernel includes:

- ✅ USB HID (Keyboard/Mouse) support
- ✅ Wi-Fi frame injection
- ✅ RTL8812AU/RTL8814AU driver support
- ✅ RTL8188EUS driver support
- ✅ Atheros AR9271 (ATH9K_HTC) support
- ✅ MediaTek MT7601U support
- ✅ Bluetooth RFCOMM support
- ✅ USB Gadget mode support
- ✅ TUN/TAP support
- ✅ Full kernel module support

## 🔄 GKI Information

### What is GKI?

GKI (Generic Kernel Image) is a architecture introduced by Google starting with Android 11 (kernel 5.4+) that separates the generic kernel from vendor-specific modules. This allows for:
- Faster security updates
- Reduced fragmentation
- Better compatibility across devices

### GKI on Galaxy Tab S8 (SM8450)

The Samsung Galaxy Tab S8 with SM8450 uses:
- **GKI Version**: android13-5.10
- **Kernel**: 5.10.x (Generic)
- **Vendor Modules**: Device-specific drivers

### How This Build Handles GKI

This build environment:
1. Uses the GKI defconfig (`gki_defconfig`) as the base
2. Builds the generic kernel image
3. Builds vendor-specific modules separately
4. Packages both for installation

### Important Notes for GKI Devices

- The kernel image (Image.gz) is the **generic** GKI kernel
- Vendor modules are built as **loadable modules (.ko)**
- Some features require loading modules after boot
- The boot partition contains the GKI kernel + vendor ramdisk

## 📋 Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04/22.04 LTS or Debian 11/12 (recommended)
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: At least 50GB free space
- **Internet**: Stable internet connection for downloading sources

### Required Packages

```bash
sudo apt-get update
sudo apt-get install -y \
    git build-essential bc bison flex libssl-dev \
    libncurses5-dev libncursesw5-dev device-tree-compiler \
    lz4 xz-utils wget curl python3 python3-pip ccache \
    libelf-dev libxml2-utils kmod cpio qttools5-dev \
    libqt5widgets5 fakeroot zip unzip lynx pandoc \
    axel binutils-aarch64-linux-gnu
```

## 📱 Device Specifications

| Specification | Details |
|--------------|---------|
| **Device** | Samsung Galaxy Tab S8 |
| **Codename** | gts8wifi |
| **Model** | SM-X700 (WiFi) |
| **Chipset** | Qualcomm SM8450 (Snapdragon 8 Gen 1) |
| **CPU** | Octa-core (1x3.00 GHz Cortex-X2 & 3x2.50 GHz Cortex-A710 & 4x1.80 GHz Cortex-A510) |
| **GPU** | Adreno 730 |
| **RAM** | 8GB |
| **Storage** | 128GB/256GB |
| **Display** | 11.0" 2560x1600 TFT LCD |
| **Battery** | 8000 mAh |
| **Android** | 12/13/14 (One UI 4.1/5.0/6.0) |
| **Kernel** | 5.10.x |
| **GKI Version** | android13-5.10 |
| **GKI Enabled** | Yes |

## ✨ Features

### NetHunter Features

| Feature | Status | Description |
|---------|--------|-------------|
| HID (Keyboard/Mouse) | ✅ | USB HID gadget support for rubber ducky attacks |
| Wi-Fi Injection | ✅ | 802.11 frame injection for aircrack-ng |
| Monitor Mode | ✅ | Wi-Fi monitor mode support |
| Bluetooth RFCOMM | ✅ | Bluetooth serial support |
| USB Gadget | ✅ | USB gadget mode for various attacks |
| TUN/TAP | ✅ | VPN and tunneling support |

### Supported WiFi Adapters

| Adapter | Chipset | Status |
|---------|---------|--------|
| TP-Link TL-WN722N v1 | Atheros AR9271 | ✅ |
| TP-Link TL-WN722N v2/v3 | Realtek RTL8188EUS | ✅ |
| ALFA AWUS036ACH | Realtek RTL8812AU | ✅ |
| ALFA AWUS036NHA | Atheros AR9271 | ✅ |
| Panda PAU09 | Ralink RT5572 | ✅ |
| Edimax EW-7811Un | Realtek RTL8188CUS | ✅ |
| MediaTek MT7601U | MediaTek MT7601U | ✅ |

## 🔨 Build Instructions

### Native Build

#### 1. Clone this repository

```bash
git clone https://github.com/yourusername/nethunter-gts8wifi.git
cd nethunter-gts8wifi
```

#### 2. Run the build script

```bash
# Make the script executable
chmod +x build-nethunter.sh

# Run full build (recommended for first time)
./build-nethunter.sh full

# Or use the interactive menu
./build-nethunter.sh
```

#### 3. Build Options

The script provides several build options:

```bash
# Full build (setup + download + configure + build + package)
./build-nethunter.sh full

# Individual steps
./build-nethunter.sh setup        # Setup environment only
./build-nethunter.sh toolchains   # Download toolchains only
./build-nethunter.sh source       # Download kernel source only
./build-nethunter.sh configure    # Configure kernel only
./build-nethunter.sh build        # Build kernel only
./build-nethunter.sh package      # Package kernel only
./build-nethunter.sh clean        # Clean build directory
```

### Docker Build

Docker provides a consistent build environment across different systems.

#### 1. Build Docker Image

```bash
docker build -t nethunter-gts8wifi-builder .
```

#### 2. Run Docker Container

```bash
# Interactive mode
docker run -it \
    -v $(pwd)/output:/build/output \
    -v nethunter-ccache:/build/.ccache \
    nethunter-gts8wifi-builder

# Run build directly
docker run \
    -v $(pwd)/output:/build/output \
    -v nethunter-ccache:/build/.ccache \
    nethunter-gts8wifi-builder \
    ./build-nethunter.sh full
```

#### 3. Using Docker Compose

```bash
# Build and run
docker-compose up --build

# Run with specific command
docker-compose run builder ./build-nethunter.sh full
```

## 📥 Installation

### Prerequisites

1. **Unlocked Bootloader**: Your device must have an unlocked bootloader
2. **Custom Recovery**: TWRP or similar custom recovery installed
3. **Root Access**: Magisk or similar root solution
4. **Backup**: Full backup of your device before proceeding

### ⚠️ Warning

> **Flashing custom kernels will trip Knox and void your warranty. Proceed at your own risk!**

### Installation Steps

#### Method 1: Flash via TWRP

1. Download the NetHunter kernel zip from the releases page or your build output
2. Boot into TWRP recovery
3. Select **Install** → Choose the NetHunter kernel zip
4. Swipe to flash
5. Reboot system

#### Method 2: Flash via Fastboot

```bash
# Boot into fastboot mode
adb reboot bootloader

# Flash kernel (if you have boot.img)
fastboot flash boot boot.img

# Or boot temporarily for testing
fastboot boot boot.img
```

#### Method 3: Flash via Magisk

1. Download the NetHunter kernel zip
2. Open Magisk Manager
3. Go to **Modules** → **Install from storage**
4. Select the NetHunter kernel zip
5. Reboot device

### Installing NetHunter App and Chroot

1. Download NetHunter Store from [store.nethunter.com](https://store.nethunter.com)
2. Install NetHunter app and NetHunter Terminal
3. Open NetHunter app and grant root permissions
4. Go to **Kali Chroot Manager** → **Install Kali Chroot**
5. Select "Full" or "Minimal" installation
6. Wait for download and installation to complete

## 📡 WiFi Adapters

### Using External WiFi Adapters

1. Connect your WiFi adapter via USB OTG cable
2. Open NetHunter Terminal
3. Check if adapter is detected:
   ```bash
   lsusb
   ```
4. Check if driver is loaded:
   ```bash
   lsmod | grep -E "rtl|ath|mt"
   ```
5. If driver is not loaded, load it manually:
   ```bash
   modprobe 88XXau  # For RTL8812AU
   modprobe r8188eu # For RTL8188EUS
   modprobe ath9k_htc # For AR9271
   modprobe mt7601u # For MT7601U
   ```

### Monitor Mode

```bash
# Enable monitor mode
airmon-ng start wlan1

# Check monitor interface
iwconfig

# Start airodump-ng
airodump-ng wlan1mon
```

## 🔧 Troubleshooting

### Build Issues

#### Issue: "command not found" errors

**Solution**: Install required packages
```bash
sudo apt-get install -y build-essential git bc bison flex
```

#### Issue: "No rule to make target"

**Solution**: Clean and rebuild
```bash
make clean && make mrproper
./build-nethunter.sh configure
./build-nethunter.sh build
```

#### Issue: Out of memory during build

**Solution**: Reduce parallel jobs
```bash
export JOBS=2
./build-nethunter.sh build
```

### Device Issues

#### Issue: Bootloop after flashing

**Solution**: 
1. Boot into recovery mode (Volume Up + Power)
2. Restore from backup
3. Or flash stock kernel

#### Issue: WiFi adapter not detected

**Solution**:
1. Check USB OTG connection
2. Verify adapter is supported
3. Load driver manually:
   ```bash
   modprobe 88XXau
   ```

#### Issue: HID attacks not working

**Solution**:
1. Ensure USB gadget is enabled
2. Check USB configuration:
   ```bash
   ls /sys/class/udc/
   ```
3. Try different USB cable/port

### Common Commands

```bash
# Check kernel version
uname -r

# Check loaded modules
lsmod

# Load specific module
modprobe <module_name>

# Check USB devices
lsusb

# Check wireless interfaces
iwconfig

# Check network interfaces
ifconfig -a

# Check dmesg for errors
dmesg | grep -i error
```

## 📚 Additional Resources

- [Kali NetHunter Documentation](https://www.kali.org/docs/nethunter/)
- [NetHunter Kernel Builder Guide](https://www.kali.org/docs/nethunter/porting-nethunter-kernel-builder/)
- [NetHunter GitLab](https://gitlab.com/kalilinux/nethunter)
- [XDA Forums - Galaxy Tab S8](https://xdaforums.com/c/samsung-galaxy-tab-s8.12693/)
- [Samsung Open Source](https://opensource.samsung.com/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the GPL-2.0 License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- **Kali NetHunter Team** - For the amazing NetHunter project
- **Samsung** - For releasing kernel sources
- **LineageOS Team** - For device trees and kernel contributions
- **XDA Community** - For continuous support and development
- **Offensive Security** - For maintaining Kali Linux

## ⚠️ Disclaimer

> This project is for educational and research purposes only. The authors are not responsible for any misuse or damage caused by this software. Always ensure you have proper authorization before testing networks or systems.

---

<p align="center">
  <b>Made with ❤️ for the NetHunter Community</b>
</p>

<p align="center">
  <a href="https://www.kali.org/">
    <img src="https://img.shields.io/badge/Kali-NetHunter-557C94?style=for-the-badge&logo=kalilinux" alt="Kali NetHunter">
  </a>
  <a href="https://www.samsung.com/">
    <img src="https://img.shields.io/badge/Samsung-Galaxy%20Tab%20S8-1428A0?style=for-the-badge&logo=samsung" alt="Samsung Galaxy Tab S8">
  </a>
</p>
