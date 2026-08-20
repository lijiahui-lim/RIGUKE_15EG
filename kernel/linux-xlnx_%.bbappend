FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# 内核源切换为 ADI 内核（与 plutosdr-fw/linux 完全一致的快照，pluto 0.38），
# tarball 由 build_petalinux.sh 同步进 meta-user。保留 yocto kmeta 元数据
# （bsp 定义/特性 scc），仅替换机器源码。
SRC_URI = "file://linux-adi-5.15-plutosdr-fw.tar.gz ${YOCTO_META}"
SRCREV_FORMAT = "meta"
KBRANCH = ""
# tarball 内核树无 xlnx SRCREV（checkout 时才 git init），跳过分支校验
do_validate_branches[noexec] = "1"
PV = "5.15+adi"
LINUX_VERSION = "5.15"
S = "${WORKDIR}/linux"

SRC_URI:append = " file://bsp.cfg"
KERNEL_FEATURES:append = " bsp.cfg"

# 保险措施：configme 早于旧 defconfig 生成时若丢弃片段中的符号，
# 在 olddefconfig 前重新追加（幂等，olddefconfig 会去重/解析依赖）
do_configure:prepend() {
    if [ -f ${B}/.config ]; then
        cat ${WORKDIR}/bsp.cfg >> ${B}/.config
    fi
}
