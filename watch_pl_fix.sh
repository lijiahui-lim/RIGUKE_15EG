#!/bin/bash
# 等待 petalinux_openwifi_build 容器结束且主构建成功，然后自动运行
# fix_openwifi_ftr.sh（.ftr 补丁 + 改进版 XSA 重导入 + 增量重打）。
while podman container exists petalinux_openwifi_build 2>/dev/null; do sleep 30; done
sleep 10
if grep -q "^DONE_EXIT=0" /home/li/work/15eg/pl_openwifi_build.log; then
  echo "Main build OK, running fix_openwifi_ftr.sh" > /home/li/work/15eg/pl_fix_ftr.log
  podman run --rm --userns=keep-id:uid=1000,gid=1000 --user vivado --network=pasta \
    -v /home/li/work/15eg:/workspace -w /workspace \
    localhost/ubuntu_petalinux_rk3588:v3 \
    bash -c "./fix_openwifi_ftr.sh >> /workspace/pl_fix_ftr.log 2>&1; echo DONE_EXIT=\$? >> /workspace/pl_fix_ftr.log"
else
  echo "Main build failed again, not running fix" >> /home/li/work/15eg/pl_fix_ftr.log
fi
