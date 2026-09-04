#!/bin/bash
# ==================================================================================
# openwifi FPGA build for RIGUKE ZU15EG + rk-fmc-ad9361 (board: rk15eg_fmcsdc)
#
# Flow: packages the openwifi IP repo (Vitis), then builds the Vivado project
# from boards/rk15eg_fmcsdc (openwifi zcu102_fmcs2 BD fork with our PS config,
# pin map and part xczu15eg-ffvb1156-2-i). Output:
#   openwifi-hw/boards/rk15eg_fmcsdc/openwifi_rk15eg_fmcsdc/system_top.xsa
# copied to ./IMAGE_15EG_openwifi_wrapper.xsa for build_petalinux.sh.
#
# Usage: ./build_openwifi.sh
# ==================================================================================
set -e
cd "$(dirname "$0")"

XILINX_DIR=/opt/Xilinx
source $XILINX_DIR/Vitis/2022.2/settings64.sh

BOARD_DIR=openwifi-hw/boards/rk15eg_fmcsdc

# Deterministic starting point: previous runs may have saved BD modifications
cp -f openwifi-hw/boards/zcu102_fmcs2/src/system.bd $BOARD_DIR/src/system.bd

# Protect custom board files from "git clean -dxf ./src/" in openwifi.tcl
git -C openwifi-hw add -f boards/rk15eg_fmcsdc/src boards/rk15eg_fmcsdc/set_files.tcl \
    boards/rk15eg_fmcsdc/bd_post_config.tcl boards/rk15eg_fmcsdc/ps_config_extracted.tcl \
    boards/rk15eg_fmcsdc/synth_impl_strategy.tcl \
    ip/parse_board_name.tcl boards/openwifi.tcl 2>/dev/null || true
git -C openwifi-hw -c user.email=port@local -c user.name=port commit -q -m "Add rk15eg_fmcsdc board port" --allow-empty 2>/dev/null || true

# Every parse_board_name.tcl copy must know rk15eg_fmcsdc
# (the ip/openofdm_rx submodule ships its own copy)
for pbf in $(find openwifi-hw -name parse_board_name.tcl); do
  if ! grep -q rk15eg_fmcsdc "$pbf"; then
    python3 - "$pbf" <<'PYEOF'
import sys
p = sys.argv[1]
t = open(p).read()
anchor = '} elseif {$BOARD_NAME=="zc706_fmcs2"} {'
blk = ('''} elseif {$BOARD_NAME=="rk15eg_fmcsdc"} {
   set ultra_scale_flag 1
   set part_string "xczu15eg-ffvb1156-2-i"
   set board_part_string []
   set board_id_string []
   set fpga_size_flag 1
''')
assert anchor in t, p
open(p, 'w').write(t.replace(anchor, blk + anchor))
print("patched", p)
PYEOF
  fi
done

# Make sure the ADI hdl libraries used by the openwifi BD are built (idempotent)
ADI_LIB_NEEDED="axi_ad9361 xilinx/util_clkdiv util_pack/util_cpack2 util_pack/util_upack2 util_rfifo util_tdd_sync util_wfifo"
for lib in $ADI_LIB_NEEDED; do
  if [ ! -f "openwifi-hw/adi-hdl/library/$lib/component.xml" ]; then
    echo "Building ADI hdl library $lib ..."
    (cd "openwifi-hw/adi-hdl/library/$lib" && make) || exit 1
  fi
done

# Build openwifi IP repo + Vivado project (synth/impl/bitstream).
# Package IPs with the zcu102_fmcs2 board define so they stay
# checksum-compatible with the shipped system.bd instances (no IP locking).
cd $BOARD_DIR
export OPENWIFI_BOARD_NAME_OVERRIDE=zcu102_fmcs2
bash ../create_ip_repo.sh $XILINX_DIR

cd ../../..
cp $BOARD_DIR/openwifi_rk15eg_fmcsdc/system_top.xsa ./IMAGE_15EG_openwifi_wrapper.xsa
echo ""
echo "==== openwifi FPGA build done: IMAGE_15EG_openwifi_wrapper.xsa ===="
echo "Next: ENABLE_OPENWIFI=1 ./build_petalinux.sh   (openwifi DT/driver/kernel variant)"
