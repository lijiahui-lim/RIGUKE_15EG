SUMMARY = "Library for interfacing with Linux IIO devices (AD9361 userspace)"
HOMEPAGE = "https://wiki.analog.com/resources/tools-software/linux-software/libiio"
LICENSE = "LGPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING.txt;md5=7c13b3376cea0ce68d2d2da0a1b3a72c"

SRC_URI = "file://libiio-0.25.tar.gz file://S99iiod"
S = "${WORKDIR}/libiio-0.25"

DEPENDS = "libxml2 bison-native flex-native"

inherit cmake update-rc.d

EXTRA_OECMAKE = " \
    -DWITH_TESTS=ON \
    -DWITH_DOC=OFF \
    -DWITH_MAN=OFF \
    -DWITH_PYTHON_BINDINGS=OFF \
    -DWITH_CSHARP_BINDINGS=OFF \
    -DWITH_MATLAB_BINDINGS=OFF \
    -DWITH_USB_BACKEND=OFF \
    -DWITH_SERIAL_BACKEND=OFF \
    -DWITH_IIOD=ON \
    -DWITH_AIO=OFF \
    -DHAVE_DNS_SD=OFF \
    -DWITH_LOCAL_BACKEND=ON \
    -DWITH_NETWORK_BACKEND=ON \
    -DINSTALL_UDEV_RULE=OFF \
"

INITSCRIPT_NAME = "iiod"
INITSCRIPT_PARAMS = "start 99 5 2 . stop 20 0 1 6 ."

do_install:append() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/S99iiod ${D}${sysconfdir}/init.d/iiod
}

# 本地无 libusb/libaio 等可选依赖；打包所有产物到主包，简化 rootfs 配置
FILES:${PN} += "${libdir} ${bindir} ${sbindir} ${includedir}"
