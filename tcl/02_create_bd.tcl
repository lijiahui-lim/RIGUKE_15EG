# Block Design creation (auto-generated)
set script_dir [file dirname [info script]]
source ${script_dir}/create_bd.tcl
# create_root_design ""

# Add tie-off for SFP TX Disable (Drive Low to enable TX)
create_bd_port -dir O sfp1_tx_disable
# We'll stick a constant 0 into it.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 sfp1_tx_disable_const
set_property CONFIG.CONST_VAL {0} [get_bd_cells sfp1_tx_disable_const]
connect_bd_net [get_bd_pins sfp1_tx_disable_const/dout] [get_bd_ports sfp1_tx_disable]
