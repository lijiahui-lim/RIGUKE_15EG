# ==================================================================================
# AD9361 (AD-FMCOMMS3, 2R2T LVDS) subsystem injection
# Dataflow cloned from ADI projects/fmcomms2/common/fmcomms2_bd.tcl and the board
# vendor reference BD (rk-fmc-ad9361). Registers on M_AXI_HPM0_LPD periph,
# ADC DMA -> S_AXI_HP1, DAC DMA -> S_AXI_HP2.
# EMIO GPIO control lines (resetb/sync/en_agc/ctl/status) stay on PS GPIO
# (see IMAGE_15EG.xdc comments and dts/system-user.dtsi).
# ==================================================================================
puts "==== AD9361 (AD-FMCOMMS3) SUBSYSTEM INJECTION ===="

set ps [get_bd_cells zynq_ultra_ps_e_0]
set pl_clk  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]  ;# 100MHz register domain
set pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/pl_clk1]  ;# 300MHz HP DMA domain
set rst_100m [get_bd_pins rst_ps8_0_96M/peripheral_aresetn]
set rst_300m [get_bd_pins rst_ps8_1_300M/peripheral_aresetn]

# ----------------------------------------------------------------------------------
# 1. PS configuration: SPI0 on EMIO, PL2 500MHz (delay_clk, 与厂商一致), HP1/HP2 slaves
# ----------------------------------------------------------------------------------
set_property -dict [list \
  CONFIG.PSU__GPIO_EMIO_WIDTH {35} \
  CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {35} \
  CONFIG.PSU__SPI0__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__SPI0__PERIPHERAL__IO {EMIO} \
  CONFIG.PSU__SPI0__GRP_SS0__ENABLE {1} \
  CONFIG.PSU__SPI0__GRP_SS0__IO {EMIO} \
  CONFIG.PSU__SPI0__GRP_SS1__ENABLE {0} \
  CONFIG.PSU__SPI0__GRP_SS2__ENABLE {0} \
  CONFIG.PSU__FPGA_PL2_ENABLE {1} \
  CONFIG.PSU__PL_CLK2_BUF {TRUE} \
  CONFIG.PSU__CRL_APB__PL2_REF_CTRL__SRCSEL {IOPLL} \
  CONFIG.PSU__CRL_APB__PL2_REF_CTRL__FREQMHZ {500} \
  CONFIG.PSU__USE__S_AXI_GP3 {1} \
  CONFIG.PSU__USE__S_AXI_GP4 {1} \
  CONFIG.PSU__SAXIGP3__DATA_WIDTH {64} \
  CONFIG.PSU__SAXIGP4__DATA_WIDTH {64} \
  CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;1|S_AXI_HP1_FPD:NA;1|S_AXI_HP0_FPD:NA;1|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;1|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;1|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
] $ps

# ----------------------------------------------------------------------------------
# 2. External ports
# ----------------------------------------------------------------------------------
create_bd_port -dir I rx_clk_in_p
create_bd_port -dir I rx_clk_in_n
create_bd_port -dir I rx_frame_in_p
create_bd_port -dir I rx_frame_in_n
create_bd_port -dir I -from 5 -to 0 rx_data_in_p
create_bd_port -dir I -from 5 -to 0 rx_data_in_n
create_bd_port -dir O tx_clk_out_p
create_bd_port -dir O tx_clk_out_n
create_bd_port -dir O tx_frame_out_p
create_bd_port -dir O tx_frame_out_n
create_bd_port -dir O -from 5 -to 0 tx_data_out_p
create_bd_port -dir O -from 5 -to 0 tx_data_out_n
create_bd_port -dir O enable
create_bd_port -dir O txnrx
# PS SPI0 EMIO breakout to AD9361 SPI
create_bd_port -dir O spi0_ss
create_bd_port -dir O spi0_sclk
create_bd_port -dir O spi0_mosi
create_bd_port -dir I spi0_miso
# FMC F12 (PWRGD)：厂商参考设计恒驱动为高，此处用 PL 常量端口实现（约束见 XDC）
create_bd_port -dir O pwrgd
connect_bd_net [get_bd_pins VCC/dout] [get_bd_ports pwrgd]

# ----------------------------------------------------------------------------------
# 3. axi_ad9361 core (LVDS, 2R2T)
# ----------------------------------------------------------------------------------
set ad9361 [create_bd_cell -type ip -vlnv analog.com:user:axi_ad9361:1.0 axi_ad9361]
set_property -dict [list \
  CONFIG.ID {0} \
  CONFIG.CMOS_OR_LVDS_N {0} \
  CONFIG.MODE_1R1T {0} \
  CONFIG.DELAY_REFCLK_FREQUENCY {200} \
  CONFIG.DAC_DDS_TYPE {1} \
  CONFIG.DAC_DDS_CORDIC_DW {14} \
] $ad9361

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk2] [get_bd_pins axi_ad9361/delay_clk]
connect_bd_net $pl_clk [get_bd_pins axi_ad9361/s_axi_aclk]
connect_bd_net $rst_100m [get_bd_pins axi_ad9361/s_axi_aresetn]
connect_bd_net [get_bd_pins axi_ad9361/l_clk] [get_bd_pins axi_ad9361/clk]

connect_bd_net [get_bd_ports rx_clk_in_p]    [get_bd_pins axi_ad9361/rx_clk_in_p]
connect_bd_net [get_bd_ports rx_clk_in_n]    [get_bd_pins axi_ad9361/rx_clk_in_n]
connect_bd_net [get_bd_ports rx_frame_in_p]  [get_bd_pins axi_ad9361/rx_frame_in_p]
connect_bd_net [get_bd_ports rx_frame_in_n]  [get_bd_pins axi_ad9361/rx_frame_in_n]
connect_bd_net [get_bd_ports rx_data_in_p]   [get_bd_pins axi_ad9361/rx_data_in_p]
connect_bd_net [get_bd_ports rx_data_in_n]   [get_bd_pins axi_ad9361/rx_data_in_n]
connect_bd_net [get_bd_pins axi_ad9361/tx_clk_out_p]   [get_bd_ports tx_clk_out_p]
connect_bd_net [get_bd_pins axi_ad9361/tx_clk_out_n]   [get_bd_ports tx_clk_out_n]
connect_bd_net [get_bd_pins axi_ad9361/tx_frame_out_p] [get_bd_ports tx_frame_out_p]
connect_bd_net [get_bd_pins axi_ad9361/tx_frame_out_n] [get_bd_ports tx_frame_out_n]
connect_bd_net [get_bd_pins axi_ad9361/tx_data_out_p]  [get_bd_ports tx_data_out_p]
connect_bd_net [get_bd_pins axi_ad9361/tx_data_out_n]  [get_bd_ports tx_data_out_n]
connect_bd_net [get_bd_pins axi_ad9361/enable] [get_bd_ports enable]
connect_bd_net [get_bd_pins axi_ad9361/txnrx]  [get_bd_ports txnrx]

# up_enable/up_txnrx: uP override 输入。接 VCC 使 ENABLE 引脚恒高（FDD RX/TX 常开）。
# 注意：核内 enable_int_p 由 l_clk 驱动，若芯片需 ENABLE=1 才输出 RX_CLK，
# 接 GND 会构成死锁导致 l_clk 永不起振。
connect_bd_net [get_bd_pins VCC/dout] [get_bd_pins axi_ad9361/up_enable]
connect_bd_net [get_bd_pins GND/dout] [get_bd_pins axi_ad9361/up_txnrx]

# ----------------------------------------------------------------------------------
# 4. TDD sync (internal generator), interface clock divider
# ----------------------------------------------------------------------------------
set tdd_sync [create_bd_cell -type ip -vlnv analog.com:user:util_tdd_sync:1.0 util_ad9361_tdd_sync]
set_property CONFIG.TDD_SYNC_PERIOD {10000000} $tdd_sync
connect_bd_net $pl_clk [get_bd_pins util_ad9361_tdd_sync/clk]
connect_bd_net $rst_100m [get_bd_pins util_ad9361_tdd_sync/rstn]
connect_bd_net [get_bd_pins util_ad9361_tdd_sync/sync_out] [get_bd_pins axi_ad9361/tdd_sync]
# tdd_sync_cntr 为核心输出（sync 方向指示），与官方参考一致悬空

# divclk select = adc_r1_mode | dac_r1_mode
set r1_or [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 ad9361_r1_or]
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {or}] $r1_or
connect_bd_net [get_bd_pins axi_ad9361/adc_r1_mode] [get_bd_pins ad9361_r1_or/Op1]
connect_bd_net [get_bd_pins axi_ad9361/dac_r1_mode] [get_bd_pins ad9361_r1_or/Op2]

set divclk [create_bd_cell -type ip -vlnv analog.com:user:util_clkdiv:1.0 util_ad9361_divclk]
connect_bd_net [get_bd_pins ad9361_r1_or/Res] [get_bd_pins util_ad9361_divclk/clk_sel]
connect_bd_net [get_bd_pins axi_ad9361/l_clk] [get_bd_pins util_ad9361_divclk/clk]
set div_clk [get_bd_pins util_ad9361_divclk/clk_out]

set divclk_rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 util_ad9361_divclk_reset]
connect_bd_net $rst_100m [get_bd_pins util_ad9361_divclk_reset/ext_reset_in]
connect_bd_net $div_clk [get_bd_pins util_ad9361_divclk_reset/slowest_sync_clk]

# ----------------------------------------------------------------------------------
# 5. RX path: wfifo -> cpack2 -> ADC DMA
# ----------------------------------------------------------------------------------
set adc_fifo [create_bd_cell -type ip -vlnv analog.com:user:util_wfifo:1.0 util_ad9361_adc_fifo]
set_property -dict [list CONFIG.NUM_OF_CHANNELS {4} CONFIG.DIN_ADDRESS_WIDTH {4} \
  CONFIG.DIN_DATA_WIDTH {16} CONFIG.DOUT_DATA_WIDTH {16}] $adc_fifo
connect_bd_net [get_bd_pins axi_ad9361/l_clk] [get_bd_pins util_ad9361_adc_fifo/din_clk]
connect_bd_net [get_bd_pins axi_ad9361/rst] [get_bd_pins util_ad9361_adc_fifo/din_rst]
connect_bd_net $div_clk [get_bd_pins util_ad9361_adc_fifo/dout_clk]
connect_bd_net [get_bd_pins util_ad9361_divclk_reset/peripheral_aresetn] [get_bd_pins util_ad9361_adc_fifo/dout_rstn]

set adc_pack [create_bd_cell -type ip -vlnv analog.com:user:util_cpack2:1.0 util_ad9361_adc_pack]
set_property -dict [list CONFIG.NUM_OF_CHANNELS {4} CONFIG.SAMPLE_DATA_WIDTH {16}] $adc_pack
connect_bd_net $div_clk [get_bd_pins util_ad9361_adc_pack/clk]
connect_bd_net [get_bd_pins util_ad9361_divclk_reset/peripheral_reset] [get_bd_pins util_ad9361_adc_pack/reset]
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_valid_0] [get_bd_pins util_ad9361_adc_pack/fifo_wr_en]
connect_bd_net [get_bd_pins util_ad9361_adc_pack/fifo_wr_overflow] [get_bd_pins util_ad9361_adc_fifo/dout_ovf]

foreach ch {i0 q0 i1 q1} idx {0 1 2 3} {
  connect_bd_net [get_bd_pins axi_ad9361/adc_enable_$ch] [get_bd_pins util_ad9361_adc_fifo/din_enable_$idx]
  connect_bd_net [get_bd_pins axi_ad9361/adc_valid_$ch]  [get_bd_pins util_ad9361_adc_fifo/din_valid_$idx]
  connect_bd_net [get_bd_pins axi_ad9361/adc_data_$ch]   [get_bd_pins util_ad9361_adc_fifo/din_data_$idx]
  connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_enable_$idx] [get_bd_pins util_ad9361_adc_pack/enable_$idx]
  connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_data_$idx]   [get_bd_pins util_ad9361_adc_pack/fifo_wr_data_$idx]
}
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/din_ovf] [get_bd_pins axi_ad9361/adc_dovf]

set adc_dma [create_bd_cell -type ip -vlnv analog.com:user:axi_dmac:1.0 axi_ad9361_adc_dma]
set_property -dict [list \
  CONFIG.DMA_TYPE_SRC {2} \
  CONFIG.DMA_TYPE_DEST {0} \
  CONFIG.CYCLIC {0} \
  CONFIG.SYNC_TRANSFER_START {0} \
  CONFIG.DMA_2D_TRANSFER {0} \
  CONFIG.DMA_DATA_WIDTH_SRC {64} \
  CONFIG.AXI_SLICE_SRC {0} \
  CONFIG.AXI_SLICE_DEST {0} \
] $adc_dma
connect_bd_net $div_clk [get_bd_pins axi_ad9361_adc_dma/fifo_wr_clk]
connect_bd_intf_net [get_bd_intf_pins util_ad9361_adc_pack/packed_fifo_wr] [get_bd_intf_pins axi_ad9361_adc_dma/fifo_wr]
# plutosdr-fw 版 util_cpack2 无 packed_sync 输出（hdl-main 才有），
# 故 SYNC_TRANSFER_START 保持 0，无 sync 连接；不影响非 SG DMA 正常采集
connect_bd_net $pl_clk1 [get_bd_pins axi_ad9361_adc_dma/m_dest_axi_aclk]
connect_bd_net $pl_clk  [get_bd_pins axi_ad9361_adc_dma/s_axi_aclk]
connect_bd_net $rst_100m [get_bd_pins axi_ad9361_adc_dma/s_axi_aresetn]
connect_bd_net $rst_300m [get_bd_pins axi_ad9361_adc_dma/m_dest_axi_aresetn]

# ----------------------------------------------------------------------------------
# 6. TX path: DAC DMA -> upack2 -> rfifo
# ----------------------------------------------------------------------------------
set dac_dma [create_bd_cell -type ip -vlnv analog.com:user:axi_dmac:1.0 axi_ad9361_dac_dma]
set_property -dict [list \
  CONFIG.DMA_TYPE_SRC {0} \
  CONFIG.DMA_TYPE_DEST {1} \
  CONFIG.CYCLIC {1} \
  CONFIG.DMA_2D_TRANSFER {0} \
  CONFIG.DMA_DATA_WIDTH_DEST {64} \
  CONFIG.AXI_SLICE_SRC {0} \
  CONFIG.AXI_SLICE_DEST {0} \
] $dac_dma
connect_bd_net $div_clk [get_bd_pins axi_ad9361_dac_dma/m_axis_aclk]
connect_bd_net $pl_clk1 [get_bd_pins axi_ad9361_dac_dma/m_src_axi_aclk]
connect_bd_net $pl_clk  [get_bd_pins axi_ad9361_dac_dma/s_axi_aclk]
connect_bd_net $rst_100m [get_bd_pins axi_ad9361_dac_dma/s_axi_aresetn]
connect_bd_net $rst_300m [get_bd_pins axi_ad9361_dac_dma/m_src_axi_aresetn]

set dac_upack [create_bd_cell -type ip -vlnv analog.com:user:util_upack2:1.0 util_ad9361_dac_upack]
set_property -dict [list CONFIG.NUM_OF_CHANNELS {4} CONFIG.SAMPLE_DATA_WIDTH {16}] $dac_upack
connect_bd_net $div_clk [get_bd_pins util_ad9361_dac_upack/clk]
connect_bd_net [get_bd_pins util_ad9361_divclk_reset/peripheral_reset] [get_bd_pins util_ad9361_dac_upack/reset]
connect_bd_intf_net [get_bd_intf_pins axi_ad9361_dac_dma/m_axis] [get_bd_intf_pins util_ad9361_dac_upack/s_axis]

set dac_fifo [create_bd_cell -type ip -vlnv analog.com:user:util_rfifo:1.0 axi_ad9361_dac_fifo]
set_property -dict [list CONFIG.DIN_DATA_WIDTH {16} CONFIG.DOUT_DATA_WIDTH {16} \
  CONFIG.DIN_ADDRESS_WIDTH {4}] $dac_fifo
connect_bd_net [get_bd_pins axi_ad9361/l_clk] [get_bd_pins axi_ad9361_dac_fifo/dout_clk]
connect_bd_net [get_bd_pins axi_ad9361/rst] [get_bd_pins axi_ad9361_dac_fifo/dout_rst]
connect_bd_net $div_clk [get_bd_pins axi_ad9361_dac_fifo/din_clk]
connect_bd_net [get_bd_pins util_ad9361_divclk_reset/peripheral_aresetn] [get_bd_pins axi_ad9361_dac_fifo/din_rstn]
connect_bd_net [get_bd_pins util_ad9361_dac_upack/fifo_rd_en] [get_bd_pins axi_ad9361_dac_fifo/din_valid_0]
connect_bd_net [get_bd_pins util_ad9361_dac_upack/fifo_rd_underflow] [get_bd_pins axi_ad9361_dac_fifo/din_unf]
foreach ch {i0 q0 i1 q1} idx {0 1 2 3} {
  connect_bd_net [get_bd_pins axi_ad9361_dac_fifo/dout_enable_$idx] [get_bd_pins axi_ad9361/dac_enable_$ch]
  connect_bd_net [get_bd_pins axi_ad9361_dac_fifo/dout_valid_$idx]  [get_bd_pins axi_ad9361/dac_valid_$ch]
  connect_bd_net [get_bd_pins axi_ad9361_dac_fifo/dout_data_$idx]   [get_bd_pins axi_ad9361/dac_data_$ch]
  connect_bd_net [get_bd_pins util_ad9361_dac_upack/enable_$idx] [get_bd_pins axi_ad9361_dac_fifo/din_enable_$idx]
  connect_bd_net [get_bd_pins util_ad9361_dac_upack/fifo_rd_valid] [get_bd_pins axi_ad9361_dac_fifo/din_valid_in_$idx]
  connect_bd_net [get_bd_pins util_ad9361_dac_upack/fifo_rd_data_$idx] [get_bd_pins axi_ad9361_dac_fifo/din_data_$idx]
}
connect_bd_net [get_bd_pins axi_ad9361_dac_fifo/dout_unf] [get_bd_pins axi_ad9361/dac_dunf]

# ----------------------------------------------------------------------------------
# 7. Register interconnect: 复用现有 ps8_0_axi_periph (PS M_AXI_HPM0_LPD)
#    教训：M_AXI_HPM1_FPD 无论经 axi_interconnect 还是 SmartConnect，都会把地址
#    低位 [3:2] 强制为 0（只有 8 字节对齐的寄存器可读，RATE@0x54 恒 0，导致
#    cf_axi_adc dig_tune 失败）。厂商参考设计寄存器总线走 M_AXI_HPM0_LPD
#    （原生 32 位，已验证可用），故把 3 个从设备挂到现有 LPD periph 上。
#    ps8_0_axi_periph 已用 M00-M06（gpio x2/uart x2/axi_dma/xxv/gpio_led），扩到 10 个。
# ----------------------------------------------------------------------------------
set_property CONFIG.NUM_MI {10} [get_bd_cells ps8_0_axi_periph]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M07_AXI] [get_bd_intf_pins axi_ad9361/s_axi]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M08_AXI] [get_bd_intf_pins axi_ad9361_adc_dma/s_axi]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M09_AXI] [get_bd_intf_pins axi_ad9361_dac_dma/s_axi]
# 手动扩出的 M07-M09 端口时钟/复位（与现有 M00-M06 同一 100MHz 域）
foreach mi {M07 M08 M09} {
  connect_bd_net $pl_clk   [get_bd_pins ps8_0_axi_periph/${mi}_ACLK]
  connect_bd_net $rst_100m [get_bd_pins ps8_0_axi_periph/${mi}_ARESETN]
}

# ----------------------------------------------------------------------------------
# 8. DMA -> DDR: HP1 (ADC), HP2 (DAC) via smartconnect
# ----------------------------------------------------------------------------------
set sc_hp1 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_hp1]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $sc_hp1
connect_bd_intf_net [get_bd_intf_pins axi_ad9361_adc_dma/m_dest_axi] [get_bd_intf_pins smartconnect_hp1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_hp1/M00_AXI]      [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]
connect_bd_net $pl_clk1 [get_bd_pins smartconnect_hp1/aclk]
connect_bd_net $rst_300m [get_bd_pins smartconnect_hp1/aresetn]
connect_bd_net $pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk]

set sc_hp2 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_hp2]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $sc_hp2
connect_bd_intf_net [get_bd_intf_pins axi_ad9361_dac_dma/m_src_axi] [get_bd_intf_pins smartconnect_hp2/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_hp2/M00_AXI]     [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP2_FPD]
connect_bd_net $pl_clk1 [get_bd_pins smartconnect_hp2/aclk]
connect_bd_net $rst_300m [get_bd_pins smartconnect_hp2/aresetn]
connect_bd_net $pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/saxihp2_fpd_aclk]

# ----------------------------------------------------------------------------------
# 9. PS SPI0 EMIO -> AD9361 SPI
# ----------------------------------------------------------------------------------
# 注意：ZynqMP PS SPI 主模式收发走 "m" 对（m_o=主机出/m_i=主机入即MISO），
# "s" 对是从机模式数据。MISO 必须接 emio_spi0_m_i（与厂商 BD 及 ADI
# zcu102_system_bd.tcl 一致），接 s_i 会恒读 0x00。
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_ss_o_n]  [get_bd_ports spi0_ss]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_sclk_o]  [get_bd_ports spi0_sclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_m_o]     [get_bd_ports spi0_mosi]
connect_bd_net [get_bd_ports spi0_miso] [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_m_i]
connect_bd_net [get_bd_pins VCC/dout] [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_ss_i_n]
connect_bd_net [get_bd_pins GND/dout] [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_sclk_i]
connect_bd_net [get_bd_pins GND/dout] [get_bd_pins zynq_ultra_ps_e_0/emio_spi0_s_i]

# ----------------------------------------------------------------------------------
# 10. Interrupts: DMA irqs -> xlconcat_0 (In4/In5) -> pl_ps_irq0
# ----------------------------------------------------------------------------------
set_property CONFIG.NUM_PORTS {6} [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins axi_ad9361_adc_dma/irq] [get_bd_pins xlconcat_0/In4]
connect_bd_net [get_bd_pins axi_ad9361_dac_dma/irq] [get_bd_pins xlconcat_0/In5]

# ----------------------------------------------------------------------------------
# 11. Address assignment (avoid existing 0x8000_0000..0x8006_xxxx range)
# ----------------------------------------------------------------------------------
assign_bd_address
# M_AXI_HPM0_LPD 只输出地址低 26 位，可用孔径 0x8000_0000~0x83FF_FFFF，
# 原 0xB000_xxxx 不在窗口内（BD 41-1075），故改用窗口内空闲区 0x801x_xxxx
assign_bd_address -offset 0x80100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_ad9361/s_axi/axi_lite] -force
assign_bd_address -offset 0x80110000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_ad9361_adc_dma/s_axi/axi_lite] -force
assign_bd_address -offset 0x80120000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_ad9361_dac_dma/s_axi/axi_lite] -force

validate_bd_design -force
puts "==== AD9361 SUBSYSTEM INJECTION DONE ===="
