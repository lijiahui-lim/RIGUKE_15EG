# openwifi 移植说明（ZU15EG + rk-fmc-ad9361）

把 openwifi（开源 802.11 SDR WiFi）移植到本工程：FPGA 走 openwifi 数据通路，
驱动/工具进入 PetaLinux rootfs，与已有 AD9361 IIO 设计（build.sh）并存，
通过构建开关二选一。

## 硬件方案
- 参考 openwifi-hw `zcu102_fmcs2`（64 位 ZynqMP + FMCOMMS AD9361 LVDS 2R2T）fork 出新板级
  `openwifi-hw/boards/rk15eg_fmcsdc`：
  - part 改为 `xczu15eg-ffvb1156-2-i`；`ip/parse_board_name.tcl` 已注册。
  - `system.bd` 复用 zcu102 连接关系（axi_ad9361 LVDS、divclk、wfifo/cpack、
    upack/rfifo、openwifi_ip 六核、axi_dma SG、clk_wiz 由采样时钟倍频出数据通路时钟）；
    PS 在综合前由 `bd_post_config.tcl` 重配置（MIO/DDR/外设来自本工程
    `tcl/create_bd.tcl` 的已验证配置 + openwifi 所需 HPM0_FPD/HP0/HP3/IRQ1/EMIO93/SPI0）。
  - AD9361 参考时钟：子板板载 40MHz 晶振直连（FPGA 不参与，与 zcu102 相同）。
  - 引脚：`src/system.xdc`，与 `src/constrs/ad9361_fmc.xdc` 一致；
    RESETB/SYNC/EN_AGC/CTL/STATUS 走 PS EMIO（openwifi 编号：
    EMIO44=en_agc 45=sync 46=resetb 47=enable 48=txnrx）。
  - `openwifi.tcl` 增加通用钩子：板目录存在 `bd_post_config.tcl` 时在综合前执行。
  - AD9361 SPI 接 PS EMIO **SPI0**（zcu102 wrapper 同样如此）。
- openwifi-hw/adi-hdl 使用 `2022_R2`（Vivado 2022.2）。

## 软件适配要点（与上游脚本的兼容处理）
- openwifi sdr 驱动按 DT 根节点 `model` 字符串识别硬件，必须含 "ZCU102" 才走
  ZYNQMP_AD9361/LARGE_FPGA 路径 —— `dts/system-user-openwifi.dtsi` 已覆写
  `model = "RIGUKE ZU15EG openwifi (ZCU102)"`。
- 上游 `load_fpga_img.sh` 在 ZynqMP 上硬编码 `spi1.0`，而本板 AD9361 在 spi0：
  `build_petalinux.sh` 对打包副本打补丁（存在则用，不存在回退 `spi0.0`），
  不改 openwifi 源码。
- `wgd.sh` 从当前目录 `insmod` 各子模块 .ko：openwifi-driver recipe 除了
  `/lib/modules/<ver>/extra` 外，同时把 .ko 复制到 `/usr/share/openwifi/`，
  因此在该目录下执行 `./wgd.sh` 即可。
- 时序（已收敛，WNS=+0.248ns / WHS=+0.011ns）：
  - 现象：rx/tx 采样交接寄存器（divclk 采样域 ↔ clk_wiz 100MHz 处理域）
    违例。最差约 -0.7ns 中，时钟插入延迟差贡献约 60%、数据路径
    （约 0.9ns）约 40%。5 种实现策略扫描最优仅 -0.670 —— 策略只能动
    数据路径，动不了时钟树，反向印证诊断。
  - 根因（物理事实，不是 STA 悲观）：divclk 侧走 `IBUF→BUFG→BUFGCE_DIV`
    两级全局缓冲级联（插延 ~6.6ns）；clk_out1 侧 MMCM 锁相把前向延迟
    在时钟图里"吸收"，只剩输出 BUFG（~4.9ns）。分叉后两棵树 ~1.6ns
    插延差是真实硅片偏斜（CPR 只抵公共前缀 0.08ns），PVT 下稳定但确实
    存在。zcu102(zu9eg) 小 die 插延差小，同设计收敛；zu15eg 走线拉长
    后差值放大到窗口之外。
  - 相位说明的准确边界：MMCM 锁相保证的是**时钟根处**的边沿配对关系
    （哪个捕获沿配哪个发射沿是确定的）；**叶子处偏斜仍随布线/芯片尺寸
    变化**。移相无效：静态相移会同步移动 requirement，且 φ=0 已是
    8ns/10ns（LCM 40ns）边沿格局下双向窗口的最优平衡点。
  - **waiver 的正当性建立在协议上，而非"STA 算错"**：这是速率转换握手，
    不是单拍同步捕获——61.44Msps 运行模式下数据在目的域稳定 ~16.3ns，
    100MHz 捕获网格每字约 16 个沿，功能只需要**有界的数据延迟**；STA
    按 125/100MHz 静态边沿模式推出的 2ns 单拍 requirement 对该协议是
    人为的。故用 `src/coherent_clocks.xdc` 的
    `set_max_delay -datapath_only 2.0`（文件必须 `processing_order late`；
    XDC 内不能用 if 等控制语句）。
  - 分方向 check 类型：RX（divclk→clk_out1）捕获网格相对早到，是
    **setup** 受限方向，由上述 max_delay 覆盖；TX（clk_out1→divclk）
    捕获网格晚到，setup 结构性受益，真实风险是 **hold** ——
    set_max_delay 不豁免 hold，hold 仍全量检查（含偏斜），phys_opt
    已布通（WHS=+0.011ns）。若 hold 退化应另行处理（phys_opt
    directive / 定向修 hold），不在该约束范围。
  - 残余风险（如实说明）：`-datapath_only` 同时豁免了这对时钟的时钟
    不确定度；叶子偏斜是真实变动量。上板若出现 RX 偶发误码/EVM 恶化，
    此约束是第一排查点（收紧预算或改用下面的备选）。
  - 备选方案及取舍：
    1. `CLOCK_DELAY_GROUP`（Xilinx 对相关时钟网络做插延匹配的官方手段）：
       已实测（`src/coherent_clocks_cdg.xdc` + `timing_cdg_experiment.tcl`，
       独立约束集/独立实现运行）：**WNS=-0.696，未收敛**。原因：插延差
       主要在缓冲级本身（BUFGCE_DIV vs MMCM+BUFG 的原级延迟），
       delay group 只能匹配布线段，匹配不掉器件固有延迟差。
    2. 重构时钟拓扑（把分频挪进 MMCM、两时钟同出一棵树，插延天然对称）：
       需改 ADI IP、牺牲分频灵活性且偏离上游，未采用。
- Viterbi：已用正式许可证（~/.Xilinx/License.lic 的 `viterbi` feature）
  全量重建，评估版 2 小时时间炸弹不再存在。

## 构建步骤
```
# 1) FPGA（输出 IMAGE_15EG_openwifi_wrapper.xsa，综合实现约 1-3 小时）
./build_openwifi.sh

# 2) 系统镜像（openwifi 变体：openwifi DT + 无线内核配置 + 驱动模块 + sdrctl）
ENABLE_OPENWIFI=1 ./build_petalinux.sh
```
默认 `./build.sh` + `./build_petalinux.sh` 仍是原 AD9361 IIO 通路，不受影响。

## 软件侧
- DT：`dts/system-user-openwifi.dtsi`（openwifi_64_ad9361.dtso 改为静态 dtsi，
  ad9361-phy RF/时钟参数沿用板上已验证配置；GPIO 用 openwifi EMIO 编号）。
- 内核：按模式二分（`build_petalinux.sh` 自动切换 bbappend/tarball）：
  - IIO 模式：ADI 5.15（kernel/linux-adi-5.15-plutosdr-fw.tar.gz）；
  - openwifi 模式：**ADI 2026_R1（Linux 6.12）**——openwifi master 的驱动用
    6.x mac80211 API（deflink/txq/chanctx emulation），5.15 编不过。
    源码 = analogdevicesinc/linux 2026_R1 + `openwifi/kernel_boot/` 四个补丁
    （axi_hdmi_crtc/ad9361_v6_12/ad9361_private/ad9361_conv），
    由 `prep_kernel_adi612.sh` 下载打包成 `kernel/linux-adi-6.12-openwifi.tar.gz`，
    recipe 变体 `kernel/linux-xlnx-openwifi.bbappend`。
  - 追加 `kernel/bsp-openwifi.cfg`（CFG80211/MAC80211/RFKILL 等；
    5.15 时代的 CONFIG_XILINX_AXIDMA 在 6.12 无此符号，由 CONFIG_XILINX_DMA 覆盖）。
- 驱动：`openwifi/driver` 以 out-of-tree module recipe 打包（openwifi-driver.bb）。
  注意 sdr.c 用相对路径 `../user_space/sdrctl_src/nl80211_testmode_def.h`，
  recipe 同时打包该头文件保持目录布局；生成的 `pre_def.h`/`git_rev.h` 与
  上游 make_all.sh 一致（USE_NEW_RX_INTERRUPT=1）。
- 用户空间：`sdrctl` + user_space 脚本（含 .ftr FIR 文件）打包为
  openwifi-tools.bb（RDEPENDS bash）。

## 待板级验证项
1. AD9361 数字接口 tune（lvds delay）在新板能否锁住（`adi,rx-data-delay` 等沿用旧配置）。
2. sdrctl 无线收发：`sdrctl dev sdr0 set init` 等（见 user_space 脚本）。
3. Viterbi 已用正式许可证构建（无评估版 2 小时限制）；若换环境重建需
   保证 `viterbi` license 可见（~/.Xilinx/License.lic），否则 openofdm_rx
   IP 打包会退回评估网表。

## 上板操作（镜像烧入 SD 卡启动后）
```
# 1) 确认驱动与 FPGA 就绪
dmesg | grep -iE "sdr|ad9361"
ls /sys/bus/spi/drivers/ad9361/          # 应出现 spi0.0
# 2) 起 openwifi 网卡（脚本在 /usr/share/openwifi/）
#    比特流已由 BOOT.BIN 在启动时加载，可跳过 wgd.sh 的 FPGA 重载
cd /usr/share/openwifi && OPENWIFI_RELOAD_FPGA=0 ./wgd.sh   # 加载驱动并初始化
ip link set sdr0 up
# 3) AP 模式
hostapd /usr/share/openwifi/hostapd-openwifi.conf &
# 或 STA 模式（先改 wpa-connect.conf）
wpa_supplicant -i sdr0 -c /usr/share/openwifi/wpa-connect.conf &
udhcpc -i sdr0
```
注意：本工程已用正式 Viterbi 许可证构建，评估版"约 2 小时后停摆"的
问题不存在；若沿用他人评估版比特流则重载 FPGA/重启可临时恢复。
