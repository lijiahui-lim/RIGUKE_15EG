#!/bin/bash
# PetaLinux build script for IMAGE_15EG

# ==========================================
# Configuration
# ==========================================
# PetaLinux installation path (Update this if your path is different)
PETALINUX_INSTALL_DIR="/home/vivado/petalinux"
PROJECT_NAME="petalinux_prj"
XSA_FILE="$(pwd)/IMAGE_15EG_wrapper.xsa"

# ==========================================
# Environment Setup
# ==========================================
# Resolve locale warnings during PetaLinux build
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

if [ ! -f "$PETALINUX_INSTALL_DIR/settings.sh" ]; then
    echo "Error: PetaLinux environment not found at $PETALINUX_INSTALL_DIR"
    exit 1
fi

echo "Sourcing PetaLinux environment..."
source "$PETALINUX_INSTALL_DIR/settings.sh"

# Check if XSA file exists
if [ ! -f "$XSA_FILE" ]; then
    echo "Error: Hardware platform file ($XSA_FILE) not found!"
    echo "Please run ./build.sh first to generate the XSA file."
    exit 1
fi

# ==========================================
# Create & Configure Project
# ==========================================
if [ -d "$PROJECT_NAME" ]; then
    echo "PetaLinux project '$PROJECT_NAME' already exists. Skipping creation."
    cd "$PROJECT_NAME"
else
    echo "Creating PetaLinux project for ZynqMP..."
    petalinux-create -t project --template zynqMP -n "$PROJECT_NAME"
    cd "$PROJECT_NAME"
fi

echo "Configuring project with hardware platform..."
# Abort on error to prevent cascading failures
set -e

# --silentconfig applies the default configuration non-interactively
petalinux-config --get-hw-description="$XSA_FILE" 
set +e

petalinux-config -c rootfs 

# ==========================================
# Build
# ==========================================
echo "Building PetaLinux project (This will take a while)..."
petalinux-build

# ==========================================
# Package Boot Image (BOOT.BIN)
# ==========================================
echo "Packaging BOOT.BIN..."
petalinux-package --boot --fsbl images/linux/zynqmp_fsbl.elf --u-boot images/linux/u-boot.elf --pmufw images/linux/pmufw.elf --fpga images/linux/system.bit --force

echo "=========================================="
echo "PetaLinux build complete!"
echo "Boot images are located in: $(pwd)/images/linux/"
echo "=========================================="
