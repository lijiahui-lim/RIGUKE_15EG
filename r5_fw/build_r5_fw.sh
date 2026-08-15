#!/bin/bash
# 构建 R5 LED 固件（需要 XSA 已生成）
set -e
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source /opt/Xilinx/Vitis/2022.2/settings64.sh

# 修复 Ubuntu 24.04 上捆绑交叉工具链的 GLIBC 冲突：
# 各工具经 RPATH 加载捆绑 sysroot 的旧 libc，但 libgmp 来自主机，
# 需要 __isoc23_strtol@GLIBC_2.38。shim 库补上该符号。
# 注意：必须"覆盖"而非"追加" LD_PRELOAD —— Vitis 环境自带的
# libgmp 预载会触发严格版本检查；且 Eclipse/make 子进程不透传
# 外层环境，故用 toolchain_shim_bin 的包装脚本做 PATH 遮蔽。
SHIM=r5_fw/glibc_shim.so
[ -f "$SHIM" ] || gcc -shared -fPIC -o "$SHIM" r5_fw/glibc_shim.c
export LD_PRELOAD=$PWD/$SHIM
export PATH=$PWD/r5_fw/toolchain_shim_bin:$PATH

xsct r5_fw/build_r5_fw.tcl
