#!/bin/bash
# 准备 openwifi 模式内核：ADI 2026_R1 (Linux 6.12) + openwifi kernel_boot 补丁，
# 重打包为 kernel/linux-adi-6.12-openwifi.tar.gz（顶层目录 linux-2026_R1，
# 与 kernel/linux-xlnx-openwifi.bbappend 的 S 一致）。
# 完成后自动重启 openwifi 镜像构建并挂上 fix watcher。
set -e
cd /home/li/work/15eg/kernel
echo "== downloading adi-linux 2026_R1 =="
rm -f linux-adi-6.12-openwifi.tar.gz linux-2026_R1.tar.gz
wget --no-proxy -O linux-2026_R1.tar.gz \
  https://github.com/analogdevicesinc/linux/archive/refs/heads/2026_R1.tar.gz
echo "== unpacking =="
rm -rf linux-2026_R1
tar xzf linux-2026_R1.tar.gz
cd linux-2026_R1
echo "== applying openwifi kernel patches =="
for p in axi_hdmi_crtc.patch ad9361_v6_12.patch ad9361_private.patch ad9361_conv.patch; do
  echo "--- $p"
  patch -p1 < "/home/li/work/15eg/openwifi/kernel_boot/$p"
done
cd ..
rm linux-2026_R1.tar.gz
echo "== repacking =="
tar czf linux-adi-6.12-openwifi.tar.gz linux-2026_R1
rm -rf linux-2026_R1
ls -la linux-adi-6.12-openwifi.tar.gz
echo "KERNEL_PREP_DONE"

echo "== restarting openwifi image build =="
podman rm -f petalinux_openwifi_build 2>/dev/null || true
rm -f /home/li/work/15eg/pl_fix_ftr.log
podman run -d --rm --name petalinux_openwifi_build \
  --userns=keep-id:uid=1000,gid=1000 --user vivado --network=pasta \
  -v /home/li/work/15eg:/workspace -w /workspace \
  localhost/ubuntu_petalinux_rk3588:v3 \
  bash -c 'ENABLE_OPENWIFI=1 ./build_petalinux.sh > /workspace/pl_openwifi_build.log 2>&1; echo DONE_EXIT=$? >> /workspace/pl_openwifi_build.log'
/home/li/work/15eg/watch_pl_fix.sh
