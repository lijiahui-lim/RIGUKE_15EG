#!/bin/bash
# Build ADI HDL IP cores (from plutosdr-fw/hdl) needed by the AD9361 subsystem.
# Idempotent: skips libraries whose component.xml already exists.
# Requires Vivado 2022.2 in PATH (settings64.sh sourced).
set -e

HDL_DIR="$(cd "$(dirname "$0")/../plutosdr-fw/hdl" && pwd)"

LIBS=(
  library/interfaces
  library/axi_ad9361
  library/util_axis_fifo
  library/axi_dmac
  library/util_tdd_sync
  library/xilinx/util_clkdiv
  library/util_wfifo
  library/util_rfifo
  library/util_pack/util_cpack2
  library/util_pack/util_upack2
)

for lib in "${LIBS[@]}"; do
  dir="$HDL_DIR/$lib"
  name=$(basename "$dir")
  if [ -f "$dir/$name.component.xml" ] || [ -f "$dir/component.xml" ]; then
    echo "[ADI-IP] $name already built, skipping"
    continue
  fi
  echo "[ADI-IP] Building $name ..."
  make -C "$dir"
done

echo "[ADI-IP] All ADI IP cores ready."
