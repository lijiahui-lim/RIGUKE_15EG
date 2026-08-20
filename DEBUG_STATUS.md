# 15EG AD9361 调试背景与进展说明

> 更新日期:2026-08-20
> 状态:二分实验完成——MIG、XXV 均排除;l_clk 问题**挂起**,已恢复标准设计并固化既有修复

---

## 1. 项目背景

### 1.1 硬件平台
- **主控**: Xilinx Zynq UltraScale+ **XCZU15EG-FFVB1156** 自研板卡(项目目录 `/home/li/work/15eg`)
- **射频**: AD9361(FMC 子卡,FMCOMMS3 风格),LVDS 数字接口,2R2T @ 61.44 MSPS
- **板上其它 PL 外设**: PL 侧 DDR4(MIG,映射 0x4_00000000)、XXV 以太网、PL LED(R5 固件控制)
- **双核 R5**: split 模式,remoteproc 加载 LED 固件

### 1.2 软件栈
| 组件 | 版本/来源 |
|---|---|
| FPGA 工具 | Vivado **2022.2**(`/opt/Xilinx/Vivado/2022.2`) |
| 嵌入式 Linux | PetaLinux 2022.2,运行于 podman 容器 `petalinux_2022_run`(镜像 `ubuntu_petalinux_rk3588:v3`,用户 vivado,挂载 `/workspace`) |
| 内核 | ADI 5.15(plutosdr-fw 0.38 快照,`kernel/linux-adi-5.15-plutosdr-fw.tar.gz`) |
| ADI HDL IP | `plutosdr-fw/hdl`(axi_ad9361 **10.03**,axi_dmac 等) |
| 厂商参考工程 | `rk-fmc-ad9361/`(Vivado **2020.2** 编译的官方可用 bit:`design_1_top.bit`) |

### 1.3 核心故障现象

**我们自己的 bitstream(Vivado 2022.2)+ 我们自己的内核**启动后:

```
ad9361 spi1.0: ad9361_probe : AD936x Rev 0 successfully initialized   ← SPI 初始化成功
ad9361_dig_tune_delay: Tuning RX FAILED!                              ← RX 数字调谐失败
cf_axi_adc: probe of b0000000.cf-ad9361-lpc failed with error -5
cf_axi_dds b0004000...: DRP unlocked.
cf_axi_dds: probe of b0004000.cf-ad9361-dds-core-lpc failed with error -110
```

- PL 侧时钟监视寄存器 **RATE(0x54)= 0x00000000** —— AXI 核内的 up_clock_mon 一个时钟沿都没数到
- 即 **AD9361 的 LVDS RX 接口时钟(l_clk / DATA_CLK)在 PL 内完全不存在**

而 **厂商 bit(2020.2)+ 厂商内核** 一切正常,RATE = 0x00013A93(l_clk ≈ 122.88 MHz 正常计数)。

### 1.4 两套设计的地址/中断映射(测试用)

| 模块 | 厂商设计 | 我们设计 |
|---|---|---|
| cf-ad9361 ADC 核 | 0x8000_0000(IRQ 无) | 0xB000_0000 |
| DDS 核 | 0x8000_4000 | 0xB000_4000 |
| RX DMAC | 0x8001_0000(IRQ 90) | 0xB001_0000(IRQ 93) |
| TX DMAC | 0x8002_0000(IRQ 89) | 0xB002_0000(IRQ 94) |
| EMIO GPIO | 88 位宽;reset=124(EMIO46)/sync=123(EMIO45) | 35 位宽;reset=100(EMIO22)/sync=98(EMIO20) |

GPIO 编号规则:`78 + EMIO bit`(bank3=78~109)。

---

## 2. 实验环境与工具链

### 2.1 板上访问通道(用户要求:平时只用 tftp + 串口,JTAG 仅救援)
- **串口**: `/dev/ttyUSB0` 115200(宿主机直连)
- **tftp**: 容器内 in.tftpd,宿主机 IP `192.168.2.155`,服务目录 `/home/li/work/15eg/tftpboot/`
- **JTAG**: Platform Cable USB II + xsdb(`rst -system` 后**必须单独再跑一次 con**,同一脚本内连跑无效)

### 2.2 测试流程(标准动作)
1. JTAG `rst -system` → 后台先启动 CR 空刷脚本 `catch_uboot.py` → 单独执行 `con` → 逮住 `ZynqMP>` 提示符
2. u-boot:`dhcp` → `setenv serverip 192.168.2.155` → `tftpboot 0x8000000 xxx.bit` → `fpga load 0 0x8000000 ${filesize}`
3. **手动修 PL 时钟**(绕过旧 FSBL):`mw 0xff5e00c8 0x01010300`(PL2=500MHz,我们 bit)/ `mw 0xff5e00c4 0x01010300`(PL1=500MHz,厂商 bit)
4. `tftpboot 0x10000000 <FIT>` → `setenv bootargs 'console=ttyPS0,115200 earlycon root=/dev/mmcblk1p2 rw rootwait'` → `bootm`
5. 内核起来后在串口 shell 检查:`devmem 0x?0000054`(RATE)、dmesg、/dev/iio:*

### 2.3 关键脚本(均在 `jtag/` 目录)
| 脚本 | 用途 |
|---|---|
| `shcmd.py` | 串口 shell 命令执行(替代 sercmd,8s 超时) |
| `uboot_cmd.py` | u-boot 命令执行(UB_TIMEOUT 环境变量) |
| `catch_uboot.py` | 后台 CR 空刷,逮 u-boot 提示符(配合 JTAG rst/con) |
| `test_ours.py` | 一键:我们 bit + PL2 修复 + 我们内核 FIT(image_noram.ub)→ 自动抓取结果 |
| `test_vendor2022.py` | 一键:厂商设计 bit + PL1 修复 + xven.ub(我们内核+厂商地址 DTB) |
| `rst.tcl` / `con.tcl` / `state.tcl` | xsdb 系统复位/继续/状态查询 |
| `dcp_*.tcl` | 对 routed DCP 的离线取证(引脚/时钟树/IDELAY/BITSLICE_CONTROL 占用者/bank) |

### 2.4 板上在线诊断手段
- **debugfs 直读 AD9361 寄存器**:`echo 0x17 > /sys/kernel/debug/iio/iio:device1/direct_reg_access; cat .../direct_reg_access`(绕过无 spidev 的限制)
- IIO sysfs:`cat /sys/bus/iio/devices/iio:device*/ensm_mode`

---

## 3. 已完成的实验与结论(按排除项组织)

### ✅ 结论 1:问题在 bitstream,不在内核/设备树
**交叉实验:厂商 bit + 我们的内核**(专用 DTB `tftpboot/xven.dtb`:地址改 0x80 段、GPIO 改 124/123、禁用 9 个不存在的 amba_pl 节点)
→ 全部正常:cf_axi_adc 探测成功 "ADI AIM (10.03) probed"、DDS 探测成功、RATE=0x13A93
**附带发现**:此组合曾挂死 u-boot 的根因是内核去探测厂商 bit 里不存在的 0xb0/0x80 混合地址,修正 DTB 后解决。

### ✅ 结论 2:"Rev 0" 打印是驱动 bug,不是 SPI 异常
`ad9361.c probe`: `rev = ret & REV_MASK` 用了过期变量,永远打印 Rev 0。虚假线索,已排除。

### ✅ 结论 3:芯片侧完全正常,确实处于 FDD 态
板上直读(我们 bit + 我们内核的失败现场):
- **reg 0x17 = 0x1A → ENSM_STATE_FDD(0xA)** —— 芯片真实处于 FDD,DATA_CLK 在芯片管脚上必然在跳
- `ensm_mode` sysfs = fdd
- SPI 初始化完整成功(PLL 全锁定)
→ 故障在**PL 侧接收路径**:时钟从 R10/N10 管脚进 FPGA 后丢失

### ✅ 结论 4:Vivado 2022.2 工具链无罪(今天的关键突破)
把厂商 rk-fmc-ad9361 工程原样拷贝(`rk-fmc-ad9361/vendor2022/`,保证 `../hdl-main` IP 仓库相对路径成立),用 **2022.2** 重编译:
- 仅需升级 4 个锁定 IP(zynq_ultra_ps_e 3.3、smartconnect×3),修复 BD wrapper 生成顺序后编译通过,时序满足
- 烧板实测:**完全正常** —— 无 Tuning FAILED、无 DRP unlocked、**RATE = 0x00013A93 与 2020.2 原始 bit 一致**
→ 排除"2020.2→2022.2 工具链回归"假设

### ✅ 结论 5:IDELAYCTRL 摆放位置不是根因(方案 B 实验)
- 现象:我们设计的 IDELAYCTRL(BITSLICE_CONTROL)默认被 MIG 的 14 个控制单元(X0Y0~Y15)挤到 X0Y16(X3Y2 区域),而 LVDS 引脚在 X3Y3;厂商的控制器在 X0Y0
- 做法:`src/constrs/ad9361_fmc.xdc` 追加 `set_property LOC BITSLICE_CONTROL_X0Y24 [get_cells -hier -filter {NAME =~ *i_rx_frame/i_delay_ctrl}]`,重编译,DCP 验证确实落在 X0Y24,时序满足
- 结果:**仍然失败**(RATE=0,Tuning RX FAILED)
→ 且厂商自身控制器也不在引脚区域(在 X3Y0)却正常,本来证据就偏弱

### ✅ 结论 6:delay_clk 频率错误是真实 bug 但不是根因
- **发现**:SD 卡旧 BOOT.BIN 的 FSBL 把 PL2(delay_clk)配成 ~9MHz;petalinux 工程里的 FSBL(旧 XSA 产物)配成 0x01010800=187.5MHz——**低于 IDELAYCTRL 300MHz 下限,此前所有 delay 实验(改 rx-data-delay 等)全是无效操作**
- 修复:u-boot 手动 `mw 0xff5e00c8 0x01010300`(500MHz,已 `md` 回读验证);新 XSA 的 psu_init 确认就是 0x01010300
- **新 BOOT.BIN 已重新打包**(见 §5),但手动修 500MHz 后 l_clk 依旧不起 → 不是根因

### ✅ 结论 7:网表级"可对比项"全部一致
对两个 routed DCP 穷举对比:封装引脚(rx_clk_in_p=R10 等)、IOSTANDARD/DIFF_TERM、IBUFDS 位置与走线、时钟树结构、axi_ad9361 IP 参数(10.03/CMOS_OR_LVDS_N=0/DELAY_REFCLK_FREQUENCY=200 等)、DT 数字接口属性(LVDS/swap/rx-data-delay=4/tx-fb-clock-delay=7/时钟链/2R2T)——**逐项一致**
→ 排除"参数配错"类原因

### ✅ 结论 8:ENABLE/TXNRX 引脚电平无关
厂商 bit 在 enable 引脚未被驱动(EMIO 默认低)时照样正常;ENSM 由 SPI 控制进入 FDD。我们 BD 里 `VCC→up_enable / GND→up_txnrx` 的接法无害。
(驱动侧 sync-gpio 请求为 GPIOD_OUT_LOW,两边行为相同,也非差异点)

### ✅ 结论 9:PL DDR4 MIG 不是根因(二分实验第一刀,2026-08-20)
- 做法:`NOMIG` 变体(BD 中删除 ddr4_0/axi_interconnect_0/proc_sys_reset_0/HPM0_FPD,XDC 去 DDR4 引脚),时序满足(WNS=+0.199)
- 结果:上板**仍然失败** —— RATE=0、Tuning RX FAILED、DDS DRP unlocked,与全量设计完全一致

### ✅ 结论 10:XXV 以太网/AXI DMA 也不是根因(二分实验第二刀,2026-08-20)
- 做法:`NOMIG+NOXXV` 最小变体(仅 PS + AD9361 子系统 + LED/UART/GPIO),时序满足(WNS=+0.262)
- 配套 FIT:`image_min.ub` = 我们内核 + 我们地址 DTB 但禁用 `ethernet@80050000`/`dma@80040000` 节点
  (不禁用会在 axienet_probe 触发 synchronous external abort 内核 panic——这是 DT 与 bit 不匹配,非硬件问题)
- 结果:上板**仍然失败** —— RATE=0、Tuning RX FAILED、DDS -110
- → "大设计共存内容"假设被推翻:最小设计与厂商设计在 AD9361 路径上的差异只剩极小的范围

### ℹ️ 最小变体 DCP 取证(与厂商 2022 DCP 逐项对比)
- rx_clk 输入路径**完全一致**:IBUFCTRL 同在 IOB_X1Y177(R10),frame 同在 IOB_X1Y179
- l_clk 全局缓冲结构一致:BUFGCE(我们 X0Y85 / 厂商 X0Y87),**CE=VCC 恒使能**,输入来自 IBUFCTRL,路径完整无断点
- delay_clk 均到达 IDELAYCTRL REFCLK:我们 BUFG_PS_X0Y65(PL2),厂商 BUFG_PS_X0Y69(PL1);u-boot 手动 `mw 0xff5e00c8 0x01010300` 已 `md` 回读确认
- 唯一可见差异:IDELAYCTRL 位置(我们 LOC 在 X0Y24/X3Y3,厂商 X0Y0/X3Y0)——但方案 B 已证伪位置非根因,且厂商 X3Y0 同样不在引脚区;该 LOC 实验约束已从 XDC 移除

### ℹ️ 观察项(未定性)
- **Vivado 2022.2 自动插 BUFG**:我们设计 5 处 vs 厂商 1 处;其中一处落在 **AD9361 RX 传输控制信号** `i_up_adc_common/i_xfer_cntrl/d_data_cntrl_int`(1157 负载)。因 RATE=0 是时钟级故障,该数据级差异暂非根因,但 PN 校验质量可能受影响,后续关注

---

## 4. 逻辑收敛:二分实验已推翻"共存性"假设

```
芯片在 FDD(时钟在管脚上)             ✓ 已证(结论3)
同源 IP + 同工具链能编出能用的 bit     ✓ 已证(厂商工程@2022.2,结论4)
去掉 PL DDR4 MIG                      ✗ 仍失败(结论9)
再去掉 XXV + AXI DMA(最小设计)        ✗ 仍失败(结论10)
→ "大设计共存内容"(MIG/XXV/规模)假设【不成立】
  最小设计与厂商设计的 AD9361 接收路径在 DCP 级逐项一致(见 §3 取证)
```

**剩余嫌疑(已大幅收窄,问题挂起)**:
1. **delay_clk(PL2)域是否真实在 fabric 里起振**:u-boot 只 `md` 回读了 CRL_APB 寄存器值,
   并未证明时钟真的到达 PL。RATE 时钟监视器若以 delay_clk 为时基,则 delay_clk 死亡会直接读 0。
   厂商设计用 **PL1** 做 delay_clk 且正常;我们用 **PL2**。
   → **首选验证**:启用 `PSU__FPGA_PL3_ENABLE=1`(PL3=500MHz,与 PL2 配置同参),
     `02b_ad9361.tcl` 里 `axi_ad9361/delay_clk` 改接 `pl_clk3`(pl_clk1=300MHz 已被 HP DMA 占用,不可挪用),
     重编译复测 RATE。若 RATE 复活 → 锁定 PS PL2 时钟通路问题。
2. 确认 RATE 监视器的时基到底是 delay_clk 还是 s_axi_aclk(pl_clk0,已证明工作),以判定 RATE=0 的语义。
3. 用 ILA 直接抓 `rx_clk_in_p`(IBUFDS 后)与 `l_clk`(BUFGCE 后),一次性区分"时钟没进来"还是"进来了没分发"。

**当前决定:l_clk 问题挂起**,已恢复标准全量设计并固化既有修复,见 §5。

---

## 5. 产物状态

| 产物 | 状态 |
|---|---|
| `IMAGE_15EG_TCL/.../impl_1/IMAGE_15EG_wrapper.bit` | **标准全量设计**(实验 LOC 约束已移除),重建后部署 `tftpboot/ours.bit` |
| `rk-fmc-ad9361/vendor2022/.../design_1_top.bit` | 厂商工程@2022.2(**可用!**),已部署 `tftpboot/vendor2022.bit` |
| `petalinux_prj/images/linux/BOOT.BIN` | **新版已打包**(2026-08-20 14:42):新 FSBL(PL2=500MHz)+ bit + u-boot + pmufw。**尚未写入 SD 卡**(板上 root shell 可 tftp 拉取后覆盖 mmcblk1p1) |
| `tftpboot/xven.ub` | 我们内核 + 厂商地址 DTB(交叉实验用 FIT) |
| `tftpboot/image_noram.ub` | 我们内核 + 我们地址 DTB(标准测试 FIT) |
| `tftpboot/ours_nomig.bit` / `ours_min.bit` / `image_min.ub` | 二分实验归档(均失败,结论 9/10),保留备查 |

## 6. 遗留问题清单

1. **【挂起】l_clk 在 PL 内消失**:二分实验已排除 MIG/XXV/共存性(结论 9/10);后续按 §4 三条线索推进(delay_clk→PL3 替换试验优先)
2. **BOOT.BIN 写入 SD**:需在板上 root shell tftp 拉取覆盖(先备份旧件),或取卡写卡
3. **TX DMAC 版本异常**:我们侧 DMAC IP 4.4.a(报 "Source memory-mapped interface not supported"?)vs 厂商 4.5.c —— 待 bitstream 修复后复查
4. **修好后回归项**:RX tune 全通过、BIST/iio 读写、DDS、DMAC 收发、R5 固件共存
5. 板上 stock 系统 root 密码未知、SysRq 被禁用 → 复位只能 JTAG(或先修 BOOT.BIN 让启动链可控)
