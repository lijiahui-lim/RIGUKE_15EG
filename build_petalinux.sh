#!/bin/bash
# PetaLinux build script for IMAGE_15EG

# ==========================================
# Configuration
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PETALINUX_INSTALL_DIR="/home/vivado/petalinux"
PROJECT_NAME="petalinux_prj"

# ENABLE_OPENWIFI=1 selects the openwifi hardware/DT variant
# (XSA from ./build_openwifi.sh, dts/system-user-openwifi.dtsi)
ENABLE_OPENWIFI=${ENABLE_OPENWIFI:-0}
if [ "$ENABLE_OPENWIFI" = "1" ]; then
    XSA_FILE="$SCRIPT_DIR/IMAGE_15EG_openwifi_wrapper.xsa"
    DTSI_FILE="$SCRIPT_DIR/dts/system-user-openwifi.dtsi"
else
    XSA_FILE="$SCRIPT_DIR/IMAGE_15EG_wrapper.xsa"
    DTSI_FILE="$SCRIPT_DIR/dts/system-user.dtsi"
fi

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
cp "$DTSI_FILE" \
   "$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi"
cp "$SCRIPT_DIR/dts/u-boot-bsp.cfg" \
   "$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-bsp/u-boot/files/bsp.cfg"
# plnx_workspace 里的副本也要同步：device-tree recipe 从该目录编译，
# XSA 变更后 petalinux-config 重新生成 workspace 时此副本可能丢失
cp "$DTSI_FILE" \
   "$SCRIPT_DIR/$PROJECT_NAME/components/plnx_workspace/device-tree/device-tree/system-user.dtsi"

# AD9361：内核切换为 ADI 内核 + bbappend + bsp.cfg 同步进 meta-user
# - IIO 模式：linux-adi-5.15-plutosdr-fw.tar.gz（与 plutosdr-fw/linux 一致的快照）
# - openwifi 模式：linux-adi-6.12-openwifi.tar.gz（ADI 2026_R1，openwifi master
#   官方支持的内核，其驱动用了 6.x mac80211 API）
if [ "$ENABLE_OPENWIFI" = "1" ]; then
    KERNEL_TARBALL="linux-adi-6.12-openwifi.tar.gz"
    KERNEL_BBAPPEND="linux-xlnx-openwifi.bbappend"
else
    KERNEL_TARBALL="linux-adi-5.15-plutosdr-fw.tar.gz"
    KERNEL_BBAPPEND="linux-xlnx_%.bbappend"
fi
echo "Syncing ADI kernel source into project-spec ($KERNEL_TARBALL)..."
KDIR="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-kernel/linux"
mkdir -p "$KDIR/linux-xlnx"
if [ ! -f "$SCRIPT_DIR/kernel/$KERNEL_TARBALL" ]; then
    echo "Error: kernel tarball kernel/$KERNEL_TARBALL not found!"
    exit 1
fi
cp "$SCRIPT_DIR/kernel/$KERNEL_TARBALL" "$KDIR/linux-xlnx/"
cp "$SCRIPT_DIR/kernel/$KERNEL_BBAPPEND" "$KDIR/linux-xlnx_%.bbappend"
cp "$SCRIPT_DIR/kernel/bsp.cfg" "$KDIR/linux-xlnx/"
if [ "$ENABLE_OPENWIFI" = "1" ]; then
    cat "$SCRIPT_DIR/kernel/bsp-openwifi.cfg" >> "$KDIR/linux-xlnx/bsp.cfg"
    echo "Merged openwifi kernel config fragment into bsp.cfg"
fi
rm -rf "$KDIR/linux-xlnx/adi-drivers"

# 内核源切换后清理 work-shared 里的旧内核树（否则 kernel_checkout
# 会在残留的旧 git 状态上报 "not a git repository"）：
# - IIO 模式：linux-xlnx 5.15.36 的 Makefile 有 SUBLEVEL = 36，ADI 快照是 SUBLEVEL = 0
# - openwifi 模式：期望 6.12（VERSION = 6），残留的 5.15 树要清掉
KERN_SRC="$SCRIPT_DIR/$PROJECT_NAME/build/tmp/work-shared/zynqmp-generic/kernel-source"
if [ -d "$KERN_SRC" ] && { [ -f "$KERN_SRC/.git" ] ||
   { [ "$ENABLE_OPENWIFI" = "1" ] && ! grep -q "^VERSION = 6" "$KERN_SRC/Makefile" 2>/dev/null; } ||
   { [ "$ENABLE_OPENWIFI" != "1" ] && grep -q "^SUBLEVEL = 36" "$KERN_SRC/Makefile" 2>/dev/null; }; }; then
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

# openwifi：驱动（out-of-tree 内核模块）+ sdrctl 工具打包进 rootfs
if [ "$ENABLE_OPENWIFI" = "1" ]; then
    echo "Syncing openwifi driver/tools recipes into project-spec..."
    DRV_DIR="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-kernel/openwifi-driver"
    mkdir -p "$DRV_DIR/files"
    rm -rf "$DRV_DIR/files/driver"
    cp -r "$SCRIPT_DIR/openwifi/driver" "$DRV_DIR/files/driver"
    rm -rf "$DRV_DIR/files/driver/.git"
    # sdr.c 用相对路径 ../user_space/sdrctl_src/ 包含 testmode 定义，需保持目录布局
    rm -rf "$DRV_DIR/files/user_space"
    mkdir -p "$DRV_DIR/files/user_space/sdrctl_src"
    cp "$SCRIPT_DIR/openwifi/user_space/sdrctl_src/nl80211_testmode_def.h" \
       "$DRV_DIR/files/user_space/sdrctl_src/"
    # make_all.sh 生成的两个头文件（USE_NEW_RX_INTERRUPT 为官方默认）
    echo "#define USE_NEW_RX_INTERRUPT 1" > "$DRV_DIR/files/driver/pre_def.h"
    if git -C "$SCRIPT_DIR/openwifi" log -1 --pretty=%h >/dev/null 2>&1; then
        echo "#define GIT_REV 0x$(git -C "$SCRIPT_DIR/openwifi" log -1 --pretty=%h)" \
            > "$DRV_DIR/files/driver/git_rev.h"
    else
        echo "#define GIT_REV 0xFFFFFFFF" > "$DRV_DIR/files/driver/git_rev.h"
    fi
    cat > "$DRV_DIR/openwifi-driver.bb" <<'EOF'
SUMMARY = "openwifi 802.11 SDR kernel driver (out-of-tree)"
LICENSE = "CLOSED"

# module-base（而非 module）：不做模块自动拆包，也就不会自动生成
# kernel-module-* RDEPENDS —— openwifi 模块随本包装到 /lib/modules/<ver>/extra
inherit module-base

SRC_URI = "file://driver/ file://user_space/"

S = "${WORKDIR}/driver"

do_compile() {
    make KDIR=${STAGING_KERNEL_DIR} -C ${S} all
}

do_install() {
    install -d ${D}/lib/modules/${KERNEL_VERSION}/extra
    for ko in ${S}/*.ko ${S}/*/*.ko; do
        [ -e "$ko" ] && install -m 0644 $ko ${D}/lib/modules/${KERNEL_VERSION}/extra/
    done
    # wgd.sh insmod's the sub-modules from its own directory, so keep a copy
    # next to the helper scripts
    install -d ${D}${datadir}/openwifi
    for ko in ${S}/*.ko ${S}/*/*.ko; do
        [ -e "$ko" ] && install -m 0644 $ko ${D}${datadir}/openwifi/
    done
}

FILES:${PN} += "/lib/modules ${datadir}/openwifi"
EOF

    TOOLS_DIR="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/recipes-apps/openwifi-tools"
    mkdir -p "$TOOLS_DIR/files"
    rm -rf "$TOOLS_DIR/files/sdrctl_src" "$TOOLS_DIR/files/scripts"
    cp -r "$SCRIPT_DIR/openwifi/user_space/sdrctl_src" "$TOOLS_DIR/files/sdrctl_src"
    mkdir -p "$TOOLS_DIR/files/scripts"
    cp "$SCRIPT_DIR/openwifi/user_space/"*.sh "$TOOLS_DIR/files/scripts/"
    cp "$SCRIPT_DIR/openwifi/user_space/"*.conf "$TOOLS_DIR/files/scripts/" 2>/dev/null || true
    cp "$SCRIPT_DIR/openwifi/user_space/"*.ftr "$TOOLS_DIR/files/scripts/" 2>/dev/null || true
    # 本板 AD9361 SPI 接在 EMIO SPI0（spi0.0），上游脚本在 ZynqMP 上硬编码
    # spi1.0 —— 打包副本里加回退逻辑（不动 openwifi 源码）
    sed -i 's|^  SPI_DEVNAME="spi1.0"$|  if [ -e /sys/bus/spi/devices/spi1.0 ]; then SPI_DEVNAME="spi1.0"; else SPI_DEVNAME="spi0.0"; fi|' \
        "$TOOLS_DIR/files/scripts/load_fpga_img.sh"
    cat > "$TOOLS_DIR/openwifi-tools.bb" <<'EOF'
SUMMARY = "openwifi sdrctl tool and helper scripts"
LICENSE = "CLOSED"
DEPENDS = "libnl pkgconfig-native"

SRC_URI = "file://sdrctl_src/ file://scripts/"

S = "${WORKDIR}/sdrctl_src"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${S}/sdrctl ${D}${sbindir}/
    install -d ${D}${datadir}/openwifi
    install -m 0755 ${WORKDIR}/scripts/*.sh ${D}${datadir}/openwifi/
    install -m 0644 ${WORKDIR}/scripts/*.conf ${D}${datadir}/openwifi/
    install -m 0644 ${WORKDIR}/scripts/*.ftr ${D}${datadir}/openwifi/ 2>/dev/null || true
}

FILES:${PN} = "${sbindir} ${datadir}/openwifi"
RDEPENDS:${PN} = "bash"
EOF
fi

echo "Configuring rootfs..."
petalinux-config -c rootfs --silentconfig

# 启用 R5 固件包：必须在 petalinux-config 之后追加，
# 否则重新生成的 rootfs_config 会把未知条目丢掉
if [ -f "$FW_DIR/r5-firmware.bb" ] && ! grep -q "^CONFIG_r5-firmware=y" "$ROOTFS_CFG"; then
    echo "CONFIG_r5-firmware=y" >> "$ROOTFS_CFG"
    echo "Enabled CONFIG_r5-firmware in rootfs"
fi

# openwifi 包加入 rootfs
if [ "$ENABLE_OPENWIFI" = "1" ]; then
    USER_ROOTFS_CFG="$SCRIPT_DIR/$PROJECT_NAME/project-spec/meta-user/conf/user-rootfsconfig"
    for pkg in openwifi-driver openwifi-tools; do
        if ! grep -q "^CONFIG_${pkg}$" "$USER_ROOTFS_CFG"; then
            echo "CONFIG_${pkg}" >> "$USER_ROOTFS_CFG"
        fi
        if ! grep -q "^CONFIG_${pkg}=y" "$ROOTFS_CFG"; then
            echo "CONFIG_${pkg}=y" >> "$ROOTFS_CFG"
            echo "Enabled CONFIG_${pkg} in rootfs"
        fi
    done
    # 无线用户空间工具（hostapd 用于 AP 模式）
    for pkg in wpa-supplicant iw hostapd; do
        if ! grep -q "^CONFIG_${pkg}=y" "$ROOTFS_CFG"; then
            echo "CONFIG_${pkg}=y" >> "$ROOTFS_CFG"
            echo "Enabled CONFIG_${pkg} in rootfs"
        fi
    done
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
