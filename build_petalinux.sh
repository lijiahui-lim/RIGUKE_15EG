#!/bin/bash
# PetaLinux build script for IMAGE_15EG

# ==========================================
# Configuration
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PETALINUX_INSTALL_DIR="/home/vivado/petalinux"
PROJECT_NAME="petalinux_prj"
XSA_FILE="$SCRIPT_DIR/IMAGE_15EG_wrapper.xsa"

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
if [ -d "$SCRIPT_DIR/$PROJECT_NAME" ]; then
    echo "PetaLinux project '$PROJECT_NAME' already exists. Skipping creation."
else
    echo "Creating PetaLinux project for ZynqMP..."
    petalinux-create -t project --template zynqMP -n "$PROJECT_NAME" || {
        echo "Error: Failed to create PetaLinux project"
        exit 1
    }
fi

cd "$SCRIPT_DIR/$PROJECT_NAME" || {
    echo "Error: Cannot enter project directory"
    exit 1
}

# Sync version-controlled hardware config into project-spec
# (petalinux_prj/ is gitignored; dts/ is the single source of truth)
echo "Syncing dts/ overlays into project-spec..."
cp "$SCRIPT_DIR/dts/system-user.dtsi" \
   "$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi"
cp "$SCRIPT_DIR/dts/u-boot-bsp.cfg" \
   "$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-bsp/u-boot/files/bsp.cfg"
# plnx_workspace 里的副本也要同步：device-tree recipe 从该目录编译，
# XSA 变更后 petalinux-config 重新生成 workspace 时此副本可能丢失
cp "$SCRIPT_DIR/dts/system-user.dtsi" \
   "$SCRIPT_DIR/$PROJECT_NAME/components/plnx_workspace/device-tree/device-tree/system-user.dtsi"

# AD9361：内核切换为 ADI 内核（kernel/linux-adi-5.15-plutosdr-fw.tar.gz，
# 与 plutosdr-fw/linux 一致的快照）+ bbappend + bsp.cfg 同步进 meta-user
echo "Syncing ADI kernel source into project-spec..."
KDIR="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-kernel/linux"
mkdir -p "$KDIR/linux-xlnx"
cp "$SCRIPT_DIR/kernel/linux-adi-5.15-plutosdr-fw.tar.gz" "$KDIR/linux-xlnx/"
cp "$SCRIPT_DIR/kernel/linux-xlnx_%.bbappend" "$KDIR/"
cp "$SCRIPT_DIR/kernel/bsp.cfg" "$KDIR/linux-xlnx/"
rm -rf "$KDIR/linux-xlnx/adi-drivers"

# 内核源切换后清理 work-shared 里的旧内核树（否则 kernel_checkout
# 会在残留的旧 git 状态上报 "not a git repository"）：
# linux-xlnx 5.15.36 的 Makefile 有 SUBLEVEL = 36，ADI 快照是 SUBLEVEL = 0
KERN_SRC="$SCRIPT_DIR/$PROJECT_NAME/build/tmp/work-shared/zynqmp-generic/kernel-source"
if [ -d "$KERN_SRC" ] && { grep -q "^SUBLEVEL = 36" "$KERN_SRC/Makefile" 2>/dev/null || [ -f "$KERN_SRC/.git" ]; }; then
    echo "Removing stale work-shared kernel source..."
    rm -rf "$KERN_SRC"
fi

# R5 固件打包：r5_fw/r5_led.elf → rootfs 的 /lib/firmware/
# （remoteproc 加载用；recipe 由本脚本生成，ELF 来自 r5_fw/）
FW_DIR="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-apps/r5-firmware"
ROOTFS_CFG="$SCRIPT_DIR/$PROJECT_NAME/project-spec/configs/rootfs_config"
if [ -f "$SCRIPT_DIR/r5_fw/r5_led.elf" ]; then
    echo "Syncing R5 firmware recipe into project-spec..."
    mkdir -p "$FW_DIR/files"
    cp "$SCRIPT_DIR/r5_fw/r5_led.elf" "$FW_DIR/files/"
    cat > "$FW_DIR/r5-firmware.bb" <<'EOF'
SUMMARY = "R5 remoteproc firmware (PL LED control)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://r5_led.elf"

S = "${WORKDIR}"

# R5 固件是 32 位 ARM ELF，rootfs 目标是 AArch64 —— 架构检查不适用；
# 固件不能被 strip
INSANE_SKIP:${PN} = "arch"
INHIBIT_PACKAGE_STRIP = "1"

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/r5_led.elf ${D}${nonarch_base_libdir}/firmware/
}

FILES:${PN} = "${nonarch_base_libdir}/firmware"
EOF
else
    echo "Warning: r5_fw/r5_led.elf 不存在，跳过 R5 固件打包（先运行 ./r5_fw/build_r5_fw.sh）"
fi

echo "Configuring project with hardware platform..."
petalinux-config --get-hw-description "$XSA_FILE" --silentconfig || {
    echo "Error: petalinux-config failed"
    exit 1
}

echo "Configuring rootfs..."
petalinux-config -c rootfs --silentconfig

# 启用 R5 固件包：必须在 petalinux-config 之后追加，
# 否则重新生成的 rootfs_config 会把未知条目丢掉
if [ -f "$FW_DIR/r5-firmware.bb" ] && ! grep -q "^CONFIG_r5-firmware=y" "$ROOTFS_CFG"; then
    echo "CONFIG_r5-firmware=y" >> "$ROOTFS_CFG"
    echo "Enabled CONFIG_r5-firmware in rootfs"
fi

# AD9361 应用层：libiio（含 iiod 与 iio_info/iio_readdev/iio_writedev 工具）
echo "Syncing libiio recipe into project-spec..."
LIBIIO_DIR="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-iio/libiio"
mkdir -p "$LIBIIO_DIR/files"
cp "$SCRIPT_DIR/apps/libiio/libiio_0.25.bb" "$LIBIIO_DIR/"
cp "$SCRIPT_DIR/apps/libiio/files/libiio-0.25.tar.gz" "$LIBIIO_DIR/files/"
cp "$SCRIPT_DIR/apps/libiio/files/S99iiod" "$LIBIIO_DIR/files/"
USER_ROOTFS_CFG="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/conf/user-rootfsconfig"
if ! grep -q "^CONFIG_libiio$" "$USER_ROOTFS_CFG"; then
    echo "CONFIG_libiio" >> "$USER_ROOTFS_CFG"
fi
if ! grep -q "^CONFIG_libiio=y" "$ROOTFS_CFG"; then
    echo "CONFIG_libiio=y" >> "$ROOTFS_CFG"
    echo "Enabled CONFIG_libiio in rootfs"
fi

# MIPI 摄像头 V4L2 调试工具（media-ctl / v4l2-ctl）
if ! grep -q "^CONFIG_v4l-utils=y" "$ROOTFS_CFG"; then
    echo "CONFIG_v4l-utils=y" >> "$ROOTFS_CFG"
    echo "Enabled CONFIG_v4l-utils in rootfs"
fi

# ==========================================
# Build
# ==========================================
echo "Building PetaLinux project (This will take a while)..."
petalinux-build || {
    echo "Error: petalinux-build failed"
    exit 1
}

# ==========================================
# Package Boot Image (BOOT.BIN)
# ==========================================
echo "Packaging BOOT.BIN..."
petalinux-package --boot \
    --fsbl images/linux/zynqmp_fsbl.elf \
    --u-boot images/linux/u-boot.elf \
    --pmufw images/linux/pmufw.elf \
    --fpga images/linux/system.bit \
    --force || {
    echo "Error: petalinux-package failed"
    exit 1
}

echo "=========================================="
echo "PetaLinux build complete!"
echo "Boot images are located in: $(pwd)/images/linux/"
echo "=========================================="
