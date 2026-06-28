# Block Design creation (auto-generated)
set script_dir [file dirname [info script]]
source ${script_dir}/create_bd.tcl

puts "==== STARTING CUSTOM 10G AND AXI DMA INJECTION (V4 FINAL) ===="

# 1. 扩展中断
set xlcon [get_bd_cells xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {4}] $xlcon

# 2. 启用 Zynq PS HP0 接口
set_property -dict [list \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__SAXIGP2__DATA_WIDTH {64} \
] [get_bd_cells zynq_ultra_ps_e_0]

# 3. 实例化 XXV_Ethernet
create_bd_cell -type ip -vlnv xilinx.com:ip:xxv_ethernet:4.1 xxv_ethernet_0
set_property -dict [list \
  CONFIG.BASE_R_KR {BASE-R} \
  CONFIG.INCLUDE_AXI4_INTERFACE {1} \
  CONFIG.INCLUDE_USER_FIFO {1} \
  CONFIG.GT_REF_CLK_FREQ {156.25} \
] [get_bd_cells xxv_ethernet_0]

# 外部引脚
make_bd_intf_pins_external  [get_bd_intf_pins xxv_ethernet_0/gt_rx]
set_property name sfp1_gt_rx [get_bd_intf_ports gt_rx_0]
make_bd_intf_pins_external  [get_bd_intf_pins xxv_ethernet_0/gt_tx]
set_property name sfp1_gt_tx [get_bd_intf_ports gt_tx_0]
make_bd_intf_pins_external  [get_bd_intf_pins xxv_ethernet_0/gt_ref_clk]
set_property name sfp1_refclk [get_bd_intf_ports gt_ref_clk_0]

# 4. 实例化 AXI DMA (关键：40位地址 + 异步模式)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
  CONFIG.c_include_sg {1} \
  CONFIG.c_addr_width {40} \
  CONFIG.c_sg_length_width {16} \
  CONFIG.c_mm2s_clk_s2mm_same_clk {0} \
  CONFIG.c_include_mm2s_dre {1} \
  CONFIG.c_include_s2mm_dre {1} \
  CONFIG.c_m_axi_s2mm_data_width {64} \
  CONFIG.c_m_axi_mm2s_data_width {64} \
] [get_bd_cells axi_dma_0]

# 5. AXI Stream 连接 (必须在同一时钟域)
connect_bd_intf_net [get_bd_intf_pins xxv_ethernet_0/axis_rx_0] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins xxv_ethernet_0/axis_tx_0]

# 6. 修正后的混合时钟连接
set pl_clk [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
set tx_clk [get_bd_pins xxv_ethernet_0/tx_clk_out_0]
set rx_clk [get_bd_pins xxv_ethernet_0/rx_clk_out_0]

# A. 控制面使用稳定时钟 (100MHz)
connect_bd_net $pl_clk [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net $pl_clk [get_bd_pins axi_dma_0/m_axi_sg_aclk]
connect_bd_net $pl_clk [get_bd_pins xxv_ethernet_0/dclk]
connect_bd_net $pl_clk [get_bd_pins xxv_ethernet_0/s_axi_aclk_0]

# B. 数据面使用以太网时钟 (156.25MHz) - 解决报错
connect_bd_net $tx_clk [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net $rx_clk [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net $rx_clk [get_bd_pins xxv_ethernet_0/rx_core_clk_0]

# 7. 复位逻辑
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_inv
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] [get_bd_cells reset_inv]
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins reset_inv/Op1]
connect_bd_net [get_bd_pins reset_inv/Res] [get_bd_pins xxv_ethernet_0/sys_reset]
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins xxv_ethernet_0/s_axi_aresetn_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 dma_rx_rst
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells dma_rx_rst]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_prmry_reset_out_n] [get_bd_pins dma_rx_rst/Op1]
connect_bd_net [get_bd_pins dma_rx_rst/Res] [get_bd_pins xxv_ethernet_0/rx_reset_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 dma_tx_rst
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells dma_tx_rst]
connect_bd_net [get_bd_pins axi_dma_0/mm2s_prmry_reset_out_n] [get_bd_pins dma_tx_rst/Op1]
connect_bd_net [get_bd_pins dma_tx_rst/Res] [get_bd_pins xxv_ethernet_0/tx_reset_0]

# 8. SmartConnect 数据通路 (配置为多时钟域)
set axi_smc_dma [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_dma ]
set_property -dict [list CONFIG.NUM_SI {3} CONFIG.NUM_CLKS {3}] $axi_smc_dma

connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc_dma/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc_dma/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_SG]   [get_bd_intf_pins axi_smc_dma/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc_dma/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

# SmartConnect 必须感知所有 3 个时钟
connect_bd_net $pl_clk [get_bd_pins axi_smc_dma/aclk]
connect_bd_net $tx_clk [get_bd_pins axi_smc_dma/aclk1]
connect_bd_net $rx_clk [get_bd_pins axi_smc_dma/aclk2]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk] $pl_clk
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins axi_smc_dma/aresetn]

# 9. 控制通路自动化
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/axi_dma_0/S_AXI_LITE} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/xxv_ethernet_0/s_axi_0} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins xxv_ethernet_0/s_axi_0]

# 10. 中断
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In3]

# 11. SFP TX Disable
set sfp_en_logic [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 sfp_en_logic ]
set_property CONFIG.CONST_VAL {0} $sfp_en_logic
for {set i 1} {$i <= 4} {incr i} {
  set p [ create_bd_port -dir O sfp${i}_tx_dis ]
  connect_bd_net [get_bd_pins sfp_en_logic/dout] $p
}

# 12. 校验与地址分配
assign_bd_address
validate_bd_design -force
