# ----------------------------------------------------------------------------------
# MIPI CSI-2 camera (OV5647) 约束（仅 ENABLE_MIPI=1 构建时加入，见 tcl/01_create_project.tcl）
#
# D-PHY 差分对（bank 67，HP bank）不需要 XDC 约束：
# MIPI CSI-2 Rx Subsystem 的 D-PHY 引脚位置是 IP 参数（见 tcl/02c_mipi_csi.tcl
# 的 CONFIG.CLK_LANE_IO_LOC / DATA_LANE*_IO_LOC），IP 自带 IOSTANDARD 约束：
#   MIPI1_CLK_P/N  = W12/W11 (B67_L1)   MIPI1_LAN0_P/N = T13/R13 (B67_L2)
#   MIPI1_LAN1_P/N = U10/T10 (B67_L3)
#
# 传感器 I2C（bank 50，HD bank，3.3V，板上有上拉）：
#   CAM_SCL = J16 (B50_L12_P), CAM_SDA = J15 (B50_L12_N)
# ----------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports CAM_IIC_scl_io]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports CAM_IIC_sda_io]
