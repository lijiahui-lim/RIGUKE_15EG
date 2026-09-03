# ----------------------------------------------------------------------------------
# AD9361 / AD-FMCOMMS3 constraints (bank 66/67 HP, VCCO 1.8V)
# Pin mapping identical to board vendor reference design rk-fmc-ad9361.xdc.
# LVDS data/clock pairs + enable/txnrx are PL ports from the axi_ad9361 core;
# AD9361 control (resetb/sync/en_agc/ctl/status) and AD9523 stay on PS EMIO GPIO
# (constrained in IMAGE_15EG.xdc).
# ----------------------------------------------------------------------------------

# RX path (inputs, on-chip 100 ohm termination)
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports rx_clk_in_p]
set_property -dict {PACKAGE_PIN R9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports rx_clk_in_n]
set_property -dict {PACKAGE_PIN T8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports rx_frame_in_p]
set_property -dict {PACKAGE_PIN R8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports rx_frame_in_n]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_p[0]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_n[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_p[1]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_n[1]}]
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_p[2]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_n[2]}]
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_p[3]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_n[3]}]
set_property -dict {PACKAGE_PIN L12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_p[4]}]
set_property -dict {PACKAGE_PIN K12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_n[4]}]
set_property -dict {PACKAGE_PIN M11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_p[5]}]
set_property -dict {PACKAGE_PIN L11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {rx_data_in_n[5]}]

# TX path (outputs)
set_property -dict {PACKAGE_PIN M10 IOSTANDARD LVDS} [get_ports tx_clk_out_p]
set_property -dict {PACKAGE_PIN L10 IOSTANDARD LVDS} [get_ports tx_clk_out_n]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVDS} [get_ports tx_frame_out_p]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVDS} [get_ports tx_frame_out_n]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVDS} [get_ports {tx_data_out_p[0]}]
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVDS} [get_ports {tx_data_out_n[0]}]
set_property -dict {PACKAGE_PIN N9  IOSTANDARD LVDS} [get_ports {tx_data_out_p[1]}]
set_property -dict {PACKAGE_PIN N8  IOSTANDARD LVDS} [get_ports {tx_data_out_n[1]}]
set_property -dict {PACKAGE_PIN T7  IOSTANDARD LVDS} [get_ports {tx_data_out_p[2]}]
set_property -dict {PACKAGE_PIN T6  IOSTANDARD LVDS} [get_ports {tx_data_out_n[2]}]
set_property -dict {PACKAGE_PIN P12 IOSTANDARD LVDS} [get_ports {tx_data_out_p[3]}]
set_property -dict {PACKAGE_PIN N12 IOSTANDARD LVDS} [get_ports {tx_data_out_n[3]}]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVDS} [get_ports {tx_data_out_p[4]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVDS} [get_ports {tx_data_out_n[4]}]
set_property -dict {PACKAGE_PIN V8  IOSTANDARD LVDS} [get_ports {tx_data_out_p[5]}]
set_property -dict {PACKAGE_PIN V7  IOSTANDARD LVDS} [get_ports {tx_data_out_n[5]}]

# AD9361 interface control (PL driven)
set_property -dict {PACKAGE_PIN U9 IOSTANDARD LVCMOS18} [get_ports enable]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS18} [get_ports txnrx]

# FMC F12 (PWRGD)：PL 常量端口恒驱动为高（BD 中 pwrgd = VCC）
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVCMOS33} [get_ports pwrgd]

# AD9361 SPI (PS SPI0 via EMIO)
set_property -dict {PACKAGE_PIN V2   IOSTANDARD LVCMOS18} [get_ports spi0_ss]
set_property -dict {PACKAGE_PIN V1   IOSTANDARD LVCMOS18} [get_ports spi0_sclk]
set_property -dict {PACKAGE_PIN AA11 IOSTANDARD LVCMOS18} [get_ports spi0_mosi]
set_property -dict {PACKAGE_PIN AA10 IOSTANDARD LVCMOS18} [get_ports spi0_miso]

# RX interface clock from AD9361 (250 MHz @ 61.44 MSPS 2R2T LVDS)
create_clock -name rx_clk_in -period 4.000 [get_ports rx_clk_in_p]

# ----------------------------------------------------------------------------------
# FMC (Bank 66/67) EMIO GPIO 控制线（PSU__GPIO_EMIO_WIDTH=35，见 tcl/02b_ad9361.tcl）
# AD9361 控制线映射（Linux gpio 线号 = 78 + EMIO bit，见 dts/system-user.dtsi）：
#   [20]=sync(U6) [21]=en_agc(V6) [22]=resetb(AB6)
#   [23..30]=status[0..7] (V12,V11,U5,U4,W2,W1,Y10,Y9)
#   [31..34]=ctl[0..3] (V4,V3,W7,W6)
# ----------------------------------------------------------------------------------
set_property PACKAGE_PIN P9 [get_ports {EMIO_tri_io[16]}]
set_property PACKAGE_PIN P10 [get_ports {EMIO_tri_io[17]}]
set_property PACKAGE_PIN Y3 [get_ports {EMIO_tri_io[18]}]
set_property PACKAGE_PIN Y4 [get_ports {EMIO_tri_io[19]}]
set_property PACKAGE_PIN U6 [get_ports {EMIO_tri_io[20]}]
set_property PACKAGE_PIN V6 [get_ports {EMIO_tri_io[21]}]
set_property PACKAGE_PIN AB6 [get_ports {EMIO_tri_io[22]}]
set_property PACKAGE_PIN V12 [get_ports {EMIO_tri_io[23]}]
set_property PACKAGE_PIN V11 [get_ports {EMIO_tri_io[24]}]
set_property PACKAGE_PIN U5 [get_ports {EMIO_tri_io[25]}]
set_property PACKAGE_PIN U4 [get_ports {EMIO_tri_io[26]}]
set_property PACKAGE_PIN W2 [get_ports {EMIO_tri_io[27]}]
set_property PACKAGE_PIN W1 [get_ports {EMIO_tri_io[28]}]
set_property PACKAGE_PIN Y10 [get_ports {EMIO_tri_io[29]}]
set_property PACKAGE_PIN Y9 [get_ports {EMIO_tri_io[30]}]
set_property PACKAGE_PIN V4 [get_ports {EMIO_tri_io[31]}]
set_property PACKAGE_PIN V3 [get_ports {EMIO_tri_io[32]}]
set_property PACKAGE_PIN W7 [get_ports {EMIO_tri_io[33]}]
set_property PACKAGE_PIN W6 [get_ports {EMIO_tri_io[34]}]

set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[16]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[17]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[18]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[19]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[20]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[21]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[22]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[23]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[24]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[25]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[26]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[27]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[28]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[29]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[30]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[31]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[32]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[33]}]
set_property IOSTANDARD LVCMOS18 [get_ports {EMIO_tri_io[34]}]

