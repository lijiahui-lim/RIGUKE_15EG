#!/bin/bash
# 增量补丁：把 .ftr（AD9361 FIR 系数文件）补进 openwifi-tools 并重新打包
# 用法（在 podman 容器内）: ./fix_openwifi_ftr.sh
# 场景：主镜像构建启动早于 build_petalinux.sh 的 .ftr 修复，
# 无需全量重建，只需重编 openwifi-tools + 重新打包 rootfs/BOOT.BIN。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRJ="$SCRIPT_DIR/petalinux_prj"
TOOLS_DIR="$PRJ/project-spec/meta-user/recipes-apps/openwifi-tools"

export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
source /home/vivado/petalinux/settings.sh

echo "Syncing .ftr files into openwifi-tools recipe..."
cp "$SCRIPT_DIR/openwifi/user_space/"*.ftr "$TOOLS_DIR/files/scripts/"

# 确保 do_install 里有 .ftr 安装行（build_petalinux.sh 生成时已包含；旧 recipe 兜底）
if ! grep -q '\.ftr' "$TOOLS_DIR/openwifi-tools.bb"; then
    sed -i 's|install -m 0644 ${WORKDIR}/scripts/\*.conf ${D}${datadir}/openwifi/|&\n    install -m 0644 ${WORKDIR}/scripts/*.ftr ${D}${datadir}/openwifi/ 2>/dev/null \|\| true|' \
        "$TOOLS_DIR/openwifi-tools.bb"
fi

cd "$PRJ"

# 时序重跑后的改进版 XSA 重新导入（硬件寄存器结构与旧版一致，仅比特流不同）
if [ -f "$SCRIPT_DIR/IMAGE_15EG_openwifi_wrapper.xsa" ]; then
    echo "Re-importing hardware description from IMAGE_15EG_openwifi_wrapper.xsa..."
    petalinux-config --get-hw-description "$SCRIPT_DIR/IMAGE_15EG_openwifi_wrapper.xsa" --silentconfig
fi

echo "Rebuilding openwifi-tools..."
petalinux-build -c openwifi-tools

echo "Repackaging rootfs + BOOT.BIN..."
petalinux-build
petalinux-package --boot \
    --fsbl images/linux/zynqmp_fsbl.elf \
    --u-boot images/linux/u-boot.elf \
    --pmufw images/linux/pmufw.elf \
    --fpga images/linux/system.bit \
    --force

echo "==== .ftr incremental update done ===="
