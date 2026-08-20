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

# AD9361 SPI (PS SPI0 via EMIO)
set_property -dict {PACKAGE_PIN V2   IOSTANDARD LVCMOS18} [get_ports spi0_ss]
set_property -dict {PACKAGE_PIN V1   IOSTANDARD LVCMOS18} [get_ports spi0_sclk]
set_property -dict {PACKAGE_PIN AA11 IOSTANDARD LVCMOS18} [get_ports spi0_mosi]
set_property -dict {PACKAGE_PIN AA10 IOSTANDARD LVCMOS18} [get_ports spi0_miso]

# RX interface clock from AD9361 (250 MHz @ 61.44 MSPS 2R2T LVDS)
create_clock -name rx_clk_in -period 4.000 [get_ports rx_clk_in_p]

