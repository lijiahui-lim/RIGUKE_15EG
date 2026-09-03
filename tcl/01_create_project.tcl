# Vivado project creation
create_project -force IMAGE_15EG_TCL ./IMAGE_15EG_TCL -part xczu15eg-ffvb1156-2-i
add_files -fileset constrs_1 -norecurse ./src/constrs/IMAGE_15EG.xdc

# bank67 VCCO 核心板固定 1.8V：AD9361(1.8V LVDS) 与 MIPI D-PHY(1.2V) 互斥，
# 只能二选一构建：
#   ENABLE_AD9361=1 ENABLE_MIPI=0 ./build.sh   # 默认，AD9361 版
#   ENABLE_AD9361=0 ENABLE_MIPI=1 ./build.sh   # MIPI 相机版
proc env_flag {name default} {
  if {[info exists ::env($name)]} { return $::env($name) }
  return $default
}
set ENABLE_AD9361 [env_flag ENABLE_AD9361 1]
set ENABLE_MIPI   [env_flag ENABLE_MIPI 0]
puts "==== SUBSYSTEM SWITCHES: ENABLE_AD9361=$ENABLE_AD9361 ENABLE_MIPI=$ENABLE_MIPI ===="

if {$ENABLE_AD9361} {
  add_files -fileset constrs_1 -norecurse ./src/constrs/ad9361_fmc.xdc
}
if {$ENABLE_MIPI} {
  add_files -fileset constrs_1 -norecurse ./src/constrs/mipi_cam.xdc
}

# ADI HDL IP repository (built by tcl/build_adi_ip.sh)
set_property ip_repo_paths [list \
  ./plutosdr-fw/hdl/library/interfaces \
  ./plutosdr-fw/hdl/library/axi_ad9361 \
  ./plutosdr-fw/hdl/library/axi_dmac \
  ./plutosdr-fw/hdl/library/util_axis_fifo \
  ./plutosdr-fw/hdl/library/util_cdc \
  ./plutosdr-fw/hdl/library/util_tdd_sync \
  ./plutosdr-fw/hdl/library/xilinx/util_clkdiv \
  ./plutosdr-fw/hdl/library/util_wfifo \
  ./plutosdr-fw/hdl/library/util_rfifo \
  ./plutosdr-fw/hdl/library/util_pack/util_cpack2 \
  ./plutosdr-fw/hdl/library/util_pack/util_upack2 \
] [current_project]
update_ip_catalog
