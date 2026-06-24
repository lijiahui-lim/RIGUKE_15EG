# Block Design creation (auto-generated)
set script_dir [file dirname [info script]]
source ${script_dir}/create_bd.tcl
# create_root_design ""

# Add tie-off for SFP TX Disable (Drive Low to enable TX)
# We'll stick a constant 0 into it.

puts "==== STARTING CUSTOM 10G AND AXI DMA INJECTION ===="

# 1. Expand Interrupt Concat to 4 inputs
set xlcon [get_bd_cells xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {4}] $xlcon

# 2. Enable Zynq PS HP0_FPD (S_AXI_GP2) for DMA access to PS DDR
set_property -dict [list CONFIG.PSU__USE__S_AXI_GP2 {1}] [get_bd_cells zynq_ultra_ps_e_0]

# 3. Instantiate XXV_Ethernet and AXI DMA
create_bd_cell -type ip -vlnv xilinx.com:ip:xxv_ethernet:4.1 xxv_ethernet_0
set_property -dict [list \
  CONFIG.BASE_R_KR {BASE-R} \
  CONFIG.INCLUDE_AXI4_INTERFACE {1} \
  CONFIG.INCLUDE_USER_FIFO {1} \
  CONFIG.GT_REF_CLK_FREQ {156.25} \
] [get_bd_cells xxv_ethernet_0]

make_bd_intf_pins_external  [get_bd_intf_pins xxv_ethernet_0/gt_rx]
set_property name sfp1_gt_rx [get_bd_intf_ports gt_rx_0]
make_bd_intf_pins_external  [get_bd_intf_pins xxv_ethernet_0/gt_tx]
set_property name sfp1_gt_tx [get_bd_intf_ports gt_tx_0]
make_bd_intf_pins_external  [get_bd_intf_pins xxv_ethernet_0/gt_ref_clk]
set_property name sfp1_refclk [get_bd_intf_ports gt_ref_clk_0]


create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
  CONFIG.c_include_sg {1} \
  CONFIG.c_sg_length_width {16} \
  CONFIG.c_include_mm2s_dre {1} \
  CONFIG.c_include_s2mm_dre {1} \
  CONFIG.c_m_axi_s2mm_data_width {64} \
  CONFIG.c_m_axi_mm2s_data_width {64} \
  CONFIG.c_m_axis_mm2s_tdata_width {64} \
  CONFIG.c_s_axis_s2mm_tdata_width {64} \
] [get_bd_cells axi_dma_0]

# 4. Connect AXI Streams (Ethernet <-> DMA)
connect_bd_intf_net [get_bd_intf_pins xxv_ethernet_0/axis_rx_0] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins xxv_ethernet_0/axis_tx_0]

# Route Ethernet clocks to DMA Stream clocks (Independent TX and RX domains)
connect_bd_net [get_bd_pins xxv_ethernet_0/tx_clk_out_0] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net [get_bd_pins xxv_ethernet_0/rx_clk_out_0] [get_bd_pins xxv_ethernet_0/rx_core_clk_0]
connect_bd_net [get_bd_pins xxv_ethernet_0/rx_clk_out_0] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]

# Route stable helper dclk and s_axi clock from PS (100MHz)
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins xxv_ethernet_0/dclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins xxv_ethernet_0/s_axi_aclk_0]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_dma_0/m_axi_sg_aclk]

# Invert system reset for Ethernet sys_reset (Active High)
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_inv
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] [get_bd_cells reset_inv]
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins reset_inv/Op1]
connect_bd_net [get_bd_pins reset_inv/Res] [get_bd_pins xxv_ethernet_0/sys_reset]

# Connect active-low reset for Ethernet AXI-Lite register interface
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins xxv_ethernet_0/s_axi_aresetn_0]

# Invert DMA primary channel resets to active-high physical datapath resets
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 dma_rx_rst
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells dma_rx_rst]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_prmry_reset_out_n] [get_bd_pins dma_rx_rst/Op1]
connect_bd_net [get_bd_pins dma_rx_rst/Res] [get_bd_pins xxv_ethernet_0/rx_reset_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 dma_tx_rst
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells dma_tx_rst]
connect_bd_net [get_bd_pins axi_dma_0/mm2s_prmry_reset_out_n] [get_bd_pins dma_tx_rst/Op1]
connect_bd_net [get_bd_pins dma_tx_rst/Res] [get_bd_pins xxv_ethernet_0/tx_reset_0]

puts "==== RUNNING AXI AUTOMATION ===="
# 5. Connect AXI DMA to PS DDR (Manual Routing to avoid Automation Errors)

# Enable HP0 on Zynq PS
set_property -dict [list \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__SAXIGP2__DATA_WIDTH {64} \
] [get_bd_cells zynq_ultra_ps_e_0]

# Create a dedicated SmartConnect for DMA -> PS path with multiple clock domain support (3 clocks)
set axi_smc_dma [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_dma ]
set_property -dict [list CONFIG.NUM_SI {3} CONFIG.NUM_CLKS {3}] $axi_smc_dma

# Connect DMA Masters to SmartConnect
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc_dma/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc_dma/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_SG]   [get_bd_intf_pins axi_smc_dma/S02_AXI]

# Connect SmartConnect to PS HP0
connect_bd_intf_net [get_bd_intf_pins axi_smc_dma/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

# Clock and Reset for the DMA Data Path
# Use pl_clk0 (100MHz) as the main fabric interconnect clock and SG descriptor ring clock
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_smc_dma/aclk]
# Use independent tx_clk_out_0 and rx_clk_out_0 for MM2S (S00) and S2MM (S01) data streams
connect_bd_net [get_bd_pins xxv_ethernet_0/tx_clk_out_0] [get_bd_pins axi_smc_dma/aclk1]
connect_bd_net [get_bd_pins xxv_ethernet_0/rx_clk_out_0] [get_bd_pins axi_smc_dma/aclk2]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins axi_smc_dma/aresetn]

# Control Path: Connect PS to DMA Lite interface and Ethernet AXI Lite interface
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/axi_dma_0/S_AXI_LITE} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/xxv_ethernet_0/s_axi_0} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins xxv_ethernet_0/s_axi_0]

# 6. Connect DMA Interrupts to PS (Linux needs these!)
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In3]

# 7. SFP1 TX Disable control
# In the original design, GPIO_1_tri_io[1] is already mapped to pin E12 (sfp1_tx_dis).
# Thus, we do not need to instantiate a static tie-off port, allowing OS-level GPIO driver control.

# 8. Validate and map memory properly
assign_bd_address
validate_bd_design -force
catch {
  set exclusions [get_bd_addr_segs -of_objects [get_bd_addr_spaces axi_dma_0/*] -filter {is_excluded == "TRUE"}]
  foreach excl $exclusions {
    include_bd_addr_seg $excl
  }
}
puts "==== CUSTOM 10G AND AXI DMA INJECTION COMPLETE ===="
