# Block Design creation (auto-generated)
set script_dir [file dirname [info script]]
source ${script_dir}/create_bd.tcl

puts "==== STARTING CUSTOM 10G AND AXI DMA INJECTION (V4 FINAL) ===="

# 1. 扩展中断
set xlcon [get_bd_cells xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {4}] $xlcon

# 2. 启用 Zynq PS HP0 接口，数据位宽128bit（与参考实例一致）
set_property -dict [list \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__SAXIGP2__DATA_WIDTH {128} \
  CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;1|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;1|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;1|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
] [get_bd_cells zynq_ultra_ps_e_0]

# 3. 实例化 XXV_Ethernet
create_bd_cell -type ip -vlnv xilinx.com:ip:xxv_ethernet:4.1 xxv_ethernet_0
set_property -dict [list \
  CONFIG.BASE_R_KR {BASE-R} \
  CONFIG.GT_GROUP_SELECT {Quad_X0Y2} \
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

# 4. 实例化 AXI DMA
# M_AXI 位宽=64: axienet 驱动 sizeof(axidma_bd)=80字节, 64bit DMA 的 BD 间隔与之匹配
# (128bit DMA 会使 BD 间隔变为128字节, 与驱动的80字节不匹配, 导致 SGIncErr 丢包)
# HP0 保持 128bit, Interconnect 自动做 64->128 位宽转换, 带宽仍远超 10G
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
  CONFIG.c_include_sg {1} \
  CONFIG.c_sg_length_width {16} \
  CONFIG.c_include_mm2s_dre {1} \
  CONFIG.c_include_mm2s_sf {1} \
  CONFIG.c_include_s2mm_dre {1} \
  CONFIG.c_include_s2mm_sf {1} \
  CONFIG.c_m_axi_s2mm_data_width {64} \
  CONFIG.c_m_axi_mm2s_data_width {64} \
  CONFIG.c_m_axis_mm2s_tdata_width {64} \
  CONFIG.c_s_axis_s2mm_tdata_width {64} \
  CONFIG.c_mm2s_burst_size {64} \
  CONFIG.c_s2mm_burst_size {8} \
  CONFIG.c_sg_include_stscntrl_strm {0} \
  CONFIG.c_sg_use_stsapp_length {0} \
] [get_bd_cells axi_dma_0]

# 5. 时钟变量
set pl_clk   [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]  ;# 100MHz  控制面
set pl_clk1  [get_bd_pins zynq_ultra_ps_e_0/pl_clk1]  ;# 300MHz  HP0数据面(SAXIGP2规格上限333MHz)
set tx_clk   [get_bd_pins xxv_ethernet_0/tx_clk_out_0] ;# 156.25MHz
set rx_clk   [get_bd_pins xxv_ethernet_0/rx_clk_out_0] ;# 156.25MHz

# 6. 时钟连接
# A. 控制面使用稳定时钟 (100MHz)
connect_bd_net $pl_clk [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net $pl_clk [get_bd_pins axi_dma_0/m_axi_sg_aclk]
connect_bd_net $pl_clk [get_bd_pins xxv_ethernet_0/dclk]
connect_bd_net $pl_clk [get_bd_pins xxv_ethernet_0/s_axi_aclk_0]

# B. 数据面使用以太网时钟 (156.25MHz)
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

# 8. AXI Interconnect 数据通路（替代 SmartConnect）
# AXI Interconnect 支持每端口独立时钟：
#   ACLK = pl_clk1 (300MHz) — 交叉开关时钟(高速，避免节流)
#   S00_ACLK = pl_clk (100MHz) — SG同域
#   S01_ACLK = tx_clk (156.25MHz) — MM2S异域，自动插CDC
#   S02_ACLK = rx_clk (156.25MHz) — S2MM异域，自动插CDC
#   M00_ACLK = pl_clk1 (300MHz) — HP0同域，无需CDC
set axi_intc_dma [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_intc_dma ]
set_property -dict [list CONFIG.NUM_SI {3} CONFIG.NUM_MI {1} CONFIG.SYNCHRONIZATION_STAGES {2}] $axi_intc_dma

# SI 端口连接
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_SG]    [get_bd_intf_pins axi_intc_dma/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S]  [get_bd_intf_pins axi_intc_dma/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]  [get_bd_intf_pins axi_intc_dma/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_intc_dma/M00_AXI]  [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

# AXI Interconnect 时钟连接
# ACLK/M00_ACLK 改用 pl_clk1(300MHz) 作为交叉开关与 HP0 端口时钟，避免 100MHz 节流
# S01/S02 仍为 tx_clk/rx_clk(156.25MHz)，Interconnect 自动插入异步 CDC
connect_bd_net $pl_clk1 [get_bd_pins axi_intc_dma/ACLK]
connect_bd_net $pl_clk  [get_bd_pins axi_intc_dma/S00_ACLK]
connect_bd_net $tx_clk  [get_bd_pins axi_intc_dma/S01_ACLK]
connect_bd_net $rx_clk  [get_bd_pins axi_intc_dma/S02_ACLK]
connect_bd_net $pl_clk1 [get_bd_pins axi_intc_dma/M00_ACLK]

# HP0 端口时钟用 pl_clk1(300MHz)：SAXIGP2 最小周期 3.0ns(上限333MHz)，375MHz 会违例；
# 300MHz 下 128bit HP0 带宽 4.8GB/s，仍远超 10G 线速需求
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk] $pl_clk1

# 8b. user_reset 反相（官方参考设计：用XXV复位复位外部FIFO和互联）
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 tx_rst_n
set_property CONFIG.C_SIZE {1} [get_bd_cells tx_rst_n]
set_property CONFIG.C_OPERATION {not} [get_bd_cells tx_rst_n]
connect_bd_net [get_bd_pins xxv_ethernet_0/user_tx_reset_0] [get_bd_pins tx_rst_n/Op1]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 rx_rst_n
set_property CONFIG.C_SIZE {1} [get_bd_cells rx_rst_n]
set_property CONFIG.C_OPERATION {not} [get_bd_cells rx_rst_n]
connect_bd_net [get_bd_pins xxv_ethernet_0/user_rx_reset_0] [get_bd_pins rx_rst_n/Op1]

# 复位连接：异步端口使用DMA自身的复位输出（同步到对应时钟域）
# ARESETN/M00_ARESETN 现属 pl_clk1(300MHz) 域，用专用 proc_sys_reset 同步复位
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_1_300M
connect_bd_net $pl_clk1 [get_bd_pins rst_ps8_1_300M/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_ps8_1_300M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps8_1_300M/peripheral_aresetn] [get_bd_pins axi_intc_dma/ARESETN]
connect_bd_net [get_bd_pins rst_ps8_0_96M/peripheral_aresetn] [get_bd_pins axi_intc_dma/S00_ARESETN]
connect_bd_net [get_bd_pins tx_rst_n/Res] [get_bd_pins axi_intc_dma/S01_ARESETN]
connect_bd_net [get_bd_pins rx_rst_n/Res] [get_bd_pins axi_intc_dma/S02_ARESETN]
connect_bd_net [get_bd_pins rst_ps8_1_300M/peripheral_aresetn] [get_bd_pins axi_intc_dma/M00_ARESETN]

# 9. AXIS Data FIFO（官方参考设计标配，增加抖动容限）
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_tx
set_property -dict [list CONFIG.FIFO_DEPTH {32768} CONFIG.FIFO_MODE {2} CONFIG.HAS_RD_DATA_COUNT {1} CONFIG.HAS_WR_DATA_COUNT {1}] [get_bd_cells axis_data_fifo_tx]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S]  [get_bd_intf_pins axis_data_fifo_tx/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_data_fifo_tx/M_AXIS] [get_bd_intf_pins xxv_ethernet_0/axis_tx_0]
connect_bd_net $tx_clk [get_bd_pins axis_data_fifo_tx/s_axis_aclk]
connect_bd_net [get_bd_pins tx_rst_n/Res] [get_bd_pins axis_data_fifo_tx/s_axis_aresetn]

create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_rx
set_property -dict [list CONFIG.FIFO_DEPTH {32768} CONFIG.FIFO_MODE {2} CONFIG.HAS_RD_DATA_COUNT {1} CONFIG.HAS_WR_DATA_COUNT {1}] [get_bd_cells axis_data_fifo_rx]
connect_bd_intf_net [get_bd_intf_pins xxv_ethernet_0/axis_rx_0] [get_bd_intf_pins axis_data_fifo_rx/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_data_fifo_rx/M_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
connect_bd_net $rx_clk [get_bd_pins axis_data_fifo_rx/s_axis_aclk]
connect_bd_net [get_bd_pins rx_rst_n/Res] [get_bd_pins axis_data_fifo_rx/s_axis_aresetn]

# 10. 控制通路自动化
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/axi_dma_0/S_AXI_LITE} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/xxv_ethernet_0/s_axi_0} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins xxv_ethernet_0/s_axi_0]

# 11. 中断
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In3]

# 12. SFP TX Disable & RX_LOS
set sfp_en_logic [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 sfp_en_logic ]
set_property CONFIG.CONST_VAL {0} $sfp_en_logic
for {set i 1} {$i <= 4} {incr i} {
  set p [ create_bd_port -dir O sfp${i}_tx_dis ]
  connect_bd_net [get_bd_pins sfp_en_logic/dout] $p
}
# SFP1 RX_LOS — SFP模块输出到FPGA，输入带PULLDOWN（板级上拉，这里拉低欺骗MAC）
# XXV MAC不使用RX_LOS，仅留作监测
set sfp1_loss [ create_bd_port -dir I sfp1_loss ]

# 12b. PL LED GPIO（2bit 全输出，D16/C16；挂 HPM0_LPD，供 R5 直接控制）
set axi_gpio_led [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_led ]
set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_ALL_OUTPUTS {1}] $axi_gpio_led
make_bd_intf_pins_external [get_bd_intf_pins axi_gpio_led/GPIO]
set pl_led_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_gpio_led/GPIO]]]
set_property name PL_LED $pl_led_port
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/axi_gpio_led/S_AXI} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_gpio_led/S_AXI]

# 13. 校验与地址分配
assign_bd_address
assign_bd_address -offset 0x80060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_gpio_led/S_AXI/Reg] -force
validate_bd_design -force
