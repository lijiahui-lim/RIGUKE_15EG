# Vivado project creation
create_project -force IMAGE_15EG_TCL ./IMAGE_15EG_TCL -part xczu15eg-ffvb1156-2-i
add_files -fileset constrs_1 -norecurse ./src/constrs/IMAGE_15EG.xdc
add_files -fileset constrs_1 -norecurse ./src/constrs/ad9361_fmc.xdc

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
