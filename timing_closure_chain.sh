#!/bin/bash
# 时序归零链：
# 1) 带正式 Viterbi 许可证全量重建 openwifi FPGA（IP 重新打包，去掉评估版时间炸弹）
# 2) 多策略并行实现扫描，目标 WNS>=0 && WHS>=0
# 3) 收敛则刷新顶层 XSA 并自动重打 PetaLinux 镜像
cd /home/li/work/15eg || exit 1

echo "== phase 1: full rebuild with licensed IP =="
./build_openwifi.sh > /tmp/ow_rebuild.log 2>&1
rc=$?
echo "BUILD_EXIT=$rc" >> /tmp/ow_rebuild.log
if [ $rc -ne 0 ]; then exit $rc; fi

echo "== phase 2: multi-strategy timing sweep =="
cd openwifi-hw/boards/rk15eg_fmcsdc || exit 1
source /opt/Xilinx/Vitis/2022.2/settings64.sh
vivado -mode batch -notrace -source timing_sweep.tcl > /tmp/timing_sweep.log 2>&1
echo "SWEEP_EXIT=$?" >> /tmp/timing_sweep.log

if grep -q TIMING_CLOSED_XSA_WRITTEN /tmp/timing_sweep.log; then
  echo "== phase 3: refresh XSA + rebuild image =="
  cp openwifi_rk15eg_fmcsdc/system_top.xsa /home/li/work/15eg/IMAGE_15EG_openwifi_wrapper.xsa
  rm -f /home/li/work/15eg/pl_fix_ftr.log
  podman run --rm --userns=keep-id:uid=1000,gid=1000 --user vivado --network=pasta \
    -v /home/li/work/15eg:/workspace -w /workspace \
    localhost/ubuntu_petalinux_rk3588:v3 \
    bash -c "./fix_openwifi_ftr.sh > /workspace/pl_fix_ftr.log 2>&1; echo DONE_EXIT=\$? >> /workspace/pl_fix_ftr.log"
else
  echo "TIMING SWEEP DID NOT CLOSE - see /tmp/timing_sweep.log"
fi
