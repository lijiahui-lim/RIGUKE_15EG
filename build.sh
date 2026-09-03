#!/bin/bash
# Vivado build script for IMAGE_15EG TCL migration
#
# bank67 VCCO 核心板固定 1.8V，AD9361(1.8V) 与 MIPI D-PHY(1.2V) 互斥，二选一：
#   ./build.sh                                  # 默认 AD9361 版
#   ENABLE_AD9361=0 ENABLE_MIPI=1 ./build.sh    # MIPI 相机版

# Set up Vivado 2022.2 environment
source /opt/Xilinx/Vivado/2022.2/settings64.sh

# Build ADI IP cores (idempotent) used by the AD9361 subsystem
bash tcl/build_adi_ip.sh

# Run Vivado in batch mode with the build Tcl script
echo "Starting Vivado batch mode..."
vivado -mode batch -source tcl/build_master.tcl
