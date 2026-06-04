#!/bin/bash
# Vivado build script for IMAGE_15EG TCL migration

# Set up Vivado 2022.2 environment
source /opt/Xilinx/Vivado/2022.2/settings64.sh

# Run Vivado in batch mode with the build Tcl script
echo "Starting Vivado batch mode..."
vivado -mode batch -source tcl/build_master.tcl
