# ==================================================================================
# MIPI CSI-2 camera (OV5647, 2-lane, RAW10) subsystem injection
#
# Pipeline: OV5647 -> D-PHY (bank67: W12/W11 clk, T13/R13 lane0, U10/T10 lane1)
#              -> mipi_csi2_rx_subsystem (RAW10, VFB, 2 lanes)
#              -> v_demosaic (BGGR10 -> RGB30)
#              -> v_frmbuf_wr  (xbgr2101010 = V4L2 XBGR30)
#              -> smartconnect -> S_AXI_HP3 (GP5) -> DDR
# Sensor I2C: AXI IIC on bank50 J16/J15 (CAM_SCL/CAM_SDA, 3.3V HR bank).
#
# Notes:
#  - D-PHY lane pin placement is done via IP params (CONFIG.*_IO_LOC), not XDC.
#    Board pins (2_底板 管脚定义.xls "MIPI & PL ETH"):
#      MIPI1_CLK_P/N  = W12/W11 (B67_L1)  MIPI1_LAN0_P/N = T13/R13 (B67_L2)
#      MIPI1_LAN1_P/N = U10/T10 (B67_L3)
#  - pl_ps_irq0 is 8-bit wide and already has 6/8 used (uart x2, axi_dma x2,
#    ad9361 dmac x2), so the 3 new irqs go to a new xlconcat_1 -> pl_ps_irq1:
#      In0 csi2rx  -> SPI 167    In1 frmbuf -> SPI 168    In2 iic -> SPI 169
#  - V4L2 media graph, register map and interrupt numbers live in
#    dts/system-user.dtsi (fpga_axi bus + vcap-mipi container).
# ==================================================================================
puts "==== MIPI CSI-2 (OV5647) SUBSYSTEM INJECTION ===="

set ps [get_bd_cells zynq_ultra_ps_e_0]
set pl_clk   [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]  ;# 100MHz control domain
set pl_clk1  [get_bd_pins zynq_ultra_ps_e_0/pl_clk1]  ;# 300MHz video + HP domain
set rst_100m [get_bd_pins rst_ps8_0_96M/peripheral_aresetn]
set rst_300m [get_bd_pins rst_ps8_1_300M/peripheral_aresetn]

# ----------------------------------------------------------------------------------
# 1. PS: enable S_AXI_HP3 (GP5) 64-bit @300MHz and pl_ps_irq1
# ----------------------------------------------------------------------------------
set_property -dict [list \
  CONFIG.PSU__USE__S_AXI_GP5 {1} \
  CONFIG.PSU__SAXIGP5__DATA_WIDTH {64} \
  CONFIG.PSU__USE__IRQ1 {1} \
  CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;1|S_AXI_HP2_FPD:NA;1|S_AXI_HP1_FPD:NA;1|S_AXI_HP0_FPD:NA;1|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;1|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;1|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
] $ps
connect_bd_net $pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/saxihp3_fpd_aclk]

# ----------------------------------------------------------------------------------
# 2. D-PHY reference clocks (US+ XIPHY mode), two separate clk_wiz
#    (NUM_OUT_CLKS is disabled for this clk_wiz configuration):
#      200MHz -> dphy_clk_200M (IDELAY calibration)
#      800MHz -> clkoutphy_in  (XiPHY CLKOUTPHY = configured line rate,
#                               see mipi_dphy component.xml; 600MHz..4GHz)
# ----------------------------------------------------------------------------------
set dphy_clk [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 mipi_dphy_refclk]
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {99.999001} \
  CONFIG.PRIM_SOURCE {No_buffer} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.USE_RESET {false} \
  CONFIG.USE_LOCKED {false} \
] $dphy_clk
connect_bd_net $pl_clk [get_bd_pins $dphy_clk/clk_in1]

set line_rate_clk [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 mipi_line_rate_clk]
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {99.999001} \
  CONFIG.PRIM_SOURCE {No_buffer} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {800.000} \
  CONFIG.USE_RESET {false} \
  CONFIG.USE_LOCKED {false} \
] $line_rate_clk
connect_bd_net $pl_clk [get_bd_pins $line_rate_clk/clk_in1]

# ----------------------------------------------------------------------------------
# 3. MIPI CSI-2 Rx Subsystem (D-PHY included, 2 lanes, RAW10)
# ----------------------------------------------------------------------------------
set csi [create_bd_cell -type ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:5.2 mipi_csi2rx]
set_property -dict [list \
  CONFIG.CMN_NUM_LANES {2} \
  CONFIG.C_DPHY_LANES {2} \
  CONFIG.CMN_PXL_FORMAT {RAW10} \
  CONFIG.HP_IO_BANK_SELECTION {67} \
  CONFIG.CLK_LANE_IO_LOC {W12} \
  CONFIG.DATA_LANE0_IO_LOC {T13} \
  CONFIG.DATA_LANE1_IO_LOC {U10} \
] $csi

connect_bd_net $pl_clk   [get_bd_pins $csi/lite_aclk]
connect_bd_net $rst_100m [get_bd_pins $csi/lite_aresetn]
connect_bd_net $pl_clk1  [get_bd_pins $csi/video_aclk]
connect_bd_net $rst_300m [get_bd_pins $csi/video_aresetn]
connect_bd_net [get_bd_pins $dphy_clk/clk_out1] [get_bd_pins $csi/dphy_clk_200M]
connect_bd_net [get_bd_pins $line_rate_clk/clk_out1] [get_bd_pins $csi/clkoutphy_in]
# D-PHY 内部 PLL lock 指示：无外部 PLL，恒接高
connect_bd_net [get_bd_pins VCC/dout] [get_bd_pins $csi/pll_lock_in]
make_bd_intf_pins_external [get_bd_intf_pins $csi/mipi_phy_if]
set mipi_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects [get_bd_intf_pins $csi/mipi_phy_if]]]
set_property name MIPI_CAM $mipi_port

# ----------------------------------------------------------------------------------
# 4. Demosaic (HLS): BGGR10 -> RGB30 (sensor SBGGR10, 排列由驱动运行时配置)
# ----------------------------------------------------------------------------------
set dm [create_bd_cell -type ip -vlnv xilinx.com:ip:v_demosaic:1.1 mipi_demosaic]
set_property -dict [list \
  CONFIG.MAX_DATA_WIDTH {10} \
  CONFIG.SAMPLES_PER_CLOCK {1} \
  CONFIG.MAX_COLS {3840} \
  CONFIG.MAX_ROWS {2160} \
] $dm
connect_bd_net $pl_clk1 [get_bd_pins $dm/ap_clk]
# ap_rst_n 由 axi_gpio_mipi_rst 位0 驱动（驱动要求 reset-gpios，见第6b节）

# ----------------------------------------------------------------------------------
# 5. Frame Buffer Write: xbgr2101010 (V4L2_PIX_FMT_XBGR30) -> HP3
# ----------------------------------------------------------------------------------
set fb [create_bd_cell -type ip -vlnv xilinx.com:ip:v_frmbuf_wr:2.4 mipi_frmbuf_wr]
set_property -dict [list \
  CONFIG.SAMPLES_PER_CLOCK {1} \
  CONFIG.MAX_DATA_WIDTH {10} \
  CONFIG.HAS_RGBX10 {1} \
  CONFIG.MAX_COLS {3840} \
  CONFIG.MAX_ROWS {2160} \
] $fb
connect_bd_net $pl_clk1 [get_bd_pins $fb/ap_clk]
# ap_rst_n 由 axi_gpio_mipi_rst 位1 驱动（驱动要求 reset-gpios，见第6b节）

# Video chain: CSI2Rx(32bit padded) -> demosaic(取低16bit, LSB对齐) -> frmbuf(32bit)
connect_bd_intf_net [get_bd_intf_pins $csi/video_out]      [get_bd_intf_pins $dm/s_axis_video]
connect_bd_intf_net [get_bd_intf_pins $dm/m_axis_video]    [get_bd_intf_pins $fb/s_axis_video]

# frmbuf -> smartconnect -> S_AXI_HP3
set sc_hp3 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_hp3]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $sc_hp3
connect_bd_intf_net [get_bd_intf_pins $fb/m_axi_mm_video] [get_bd_intf_pins $sc_hp3/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc_hp3/M00_AXI]    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP3_FPD]
connect_bd_net $pl_clk1 [get_bd_pins $sc_hp3/aclk]
connect_bd_net $rst_300m [get_bd_pins $sc_hp3/aresetn]

# ----------------------------------------------------------------------------------
# 6. Sensor control I2C (AXI IIC -> J16/J15)
# ----------------------------------------------------------------------------------
set iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_cam]
connect_bd_net $pl_clk   [get_bd_pins $iic/s_axi_aclk]
connect_bd_net $rst_100m [get_bd_pins $iic/s_axi_aresetn]
make_bd_intf_pins_external [get_bd_intf_pins $iic/iic]
set iic_port [get_bd_intf_ports -of_objects [get_bd_intf_nets -of_objects [get_bd_intf_pins $iic/iic]]]
set_property name CAM_IIC $iic_port

# ----------------------------------------------------------------------------------
# 6b. IP 复位 GPIO：xilinx-demosaic.c / xilinx_frmbuf.c 都强制要求
#     reset-gpios（devm_gpiod_get，缺失即 probe 失败），复位为低有效，
#     DT 中须声明 GPIO_ACTIVE_LOW。位0 -> demosaic，位1 -> frmbuf。
# ----------------------------------------------------------------------------------
set rst_gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_mipi_rst]
set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_ALL_OUTPUTS {1}] $rst_gpio
connect_bd_net $pl_clk   [get_bd_pins $rst_gpio/s_axi_aclk]
connect_bd_net $rst_100m [get_bd_pins $rst_gpio/s_axi_aresetn]

set rst_slice0 [create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 mipi_rst_slice0]
set_property -dict [list CONFIG.DIN_WIDTH {2} CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DOUT_WIDTH {1}] $rst_slice0
connect_bd_net [get_bd_pins $rst_gpio/gpio_io_o] [get_bd_pins $rst_slice0/Din]
connect_bd_net [get_bd_pins $rst_slice0/Dout] [get_bd_pins $dm/ap_rst_n]

set rst_slice1 [create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 mipi_rst_slice1]
set_property -dict [list CONFIG.DIN_WIDTH {2} CONFIG.DIN_FROM {1} CONFIG.DIN_TO {1} CONFIG.DOUT_WIDTH {1}] $rst_slice1
connect_bd_net [get_bd_pins $rst_gpio/gpio_io_o] [get_bd_pins $rst_slice1/Din]
connect_bd_net [get_bd_pins $rst_slice1/Dout] [get_bd_pins $fb/ap_rst_n]

# ----------------------------------------------------------------------------------
# 7. Control plane: ps8_0_axi_periph M10..M14 (扩展自 M00..M09)
# ----------------------------------------------------------------------------------
set_property CONFIG.NUM_MI {15} [get_bd_cells ps8_0_axi_periph]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M10_AXI] [get_bd_intf_pins $csi/csirxss_s_axi]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins $dm/s_axi_CTRL]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M12_AXI] [get_bd_intf_pins $fb/s_axi_CTRL]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M13_AXI] [get_bd_intf_pins $iic/S_AXI]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M14_AXI] [get_bd_intf_pins $rst_gpio/S_AXI]
# 控制口时钟域：csi/iic/rst_gpio=100MHz；demosaic/frmbuf 与其 ap_clk(300MHz) 同域
foreach {mi clk rst} [list M10 $pl_clk $rst_100m  M11 $pl_clk1 $rst_300m  M12 $pl_clk1 $rst_300m  M13 $pl_clk $rst_100m  M14 $pl_clk $rst_100m] {
  connect_bd_net $clk [get_bd_pins ps8_0_axi_periph/${mi}_ACLK]
  connect_bd_net $rst [get_bd_pins ps8_0_axi_periph/${mi}_ARESETN]
}

# ----------------------------------------------------------------------------------
# 8. Interrupts: xlconcat_1 -> pl_ps_irq1 (SPI 167/168/169)
# ----------------------------------------------------------------------------------
set irqc [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1]
set_property CONFIG.NUM_PORTS {3} $irqc
connect_bd_net [get_bd_pins $csi/csirxss_csi_irq] [get_bd_pins $irqc/In0]
connect_bd_net [get_bd_pins $fb/interrupt]        [get_bd_pins $irqc/In1]
connect_bd_net [get_bd_pins $iic/iic2intc_irpt]   [get_bd_pins $irqc/In2]
connect_bd_net [get_bd_pins $irqc/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq1]

# ----------------------------------------------------------------------------------
# 9. Address assignment (keep 0x8013_0000..0x8017_xxxx inside the LPD 26-bit window)
# ----------------------------------------------------------------------------------
assign_bd_address
assign_bd_address -offset 0x80130000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mipi_csi2rx/csirxss_s_axi/Reg] -force
assign_bd_address -offset 0x80140000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mipi_demosaic/s_axi_CTRL/Reg] -force
assign_bd_address -offset 0x80150000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mipi_frmbuf_wr/s_axi_CTRL/Reg] -force
assign_bd_address -offset 0x80160000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_iic_cam/S_AXI/Reg] -force
assign_bd_address -offset 0x80170000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_gpio_mipi_rst/S_AXI/Reg] -force

validate_bd_design
puts "==== MIPI CSI-2 (OV5647) SUBSYSTEM INJECTION DONE ===="
