FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# openwifi 模式：内核切换为 ADI 2026_R1（Linux 6.12，openwifi master 官方支持的内核）。
# tarball 由 build_petalinux.sh 同步进 meta-user。保留 yocto kmeta 元数据
# （bsp 定义/特性 scc），仅替换机器源码。
SRC_URI = "file://linux-adi-6.12-openwifi.tar.gz ${YOCTO_META}"
SRCREV_FORMAT = "meta"
KBRANCH = ""
# tarball 内核树无 xlnx SRCREV（checkout 时才 git init），跳过分支校验
do_validate_branches[noexec] = "1"
PV = "6.12+adi"
LINUX_VERSION = "6.12"
S = "${WORKDIR}/linux-2026_R1"

SRC_URI:append = " file://bsp.cfg"
KERNEL_FEATURES:append = " bsp.cfg"

# 6.12 的 modules_install 既不生成还会清掉 MODLIB 下的 source/build 符号链接，
# 而 kernel_do_install 里的裸 rm 无条件删除它们 → do_install 失败。
# 用 PATH 前置一个强制 -f 的 rm 包装脚本规避（作用域仅 do_install）
do_install:prepend() {
	mkdir -p ${WORKDIR}/rmfix
	printf '#!/bin/sh\nexec /bin/rm -f "$@"\n' > ${WORKDIR}/rmfix/rm
	chmod 0755 ${WORKDIR}/rmfix/rm
	export PATH=${WORKDIR}/rmfix:$PATH
}

# 保险措施：configme 早于旧 defconfig 生成时若丢弃片段中的符号，
# 在 olddefconfig 前重新追加（幂等，olddefconfig 会去重/解析依赖）
do_configure:prepend() {
    if [ -f ${B}/.config ]; then
        cat ${WORKDIR}/bsp.cfg >> ${B}/.config
    fi
}
