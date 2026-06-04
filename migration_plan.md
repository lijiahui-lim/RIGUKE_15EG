# IMAGE_15EG Vivado TCL 自动化构建迁移计划

## 1. 目标
将现有的 Vivado 图形化项目 `IMAGE_15EG.xpr` 转换为基于 TCL 脚本的完全可复现流程，能够通过命令行自动创建工程、配置底层并一键编译出硬件平台文件（.xsa）。

## 2. 步骤

### 2.1 纯净脱离原工程 (完全代码化硬件构建)
为了彻底避免对原工程 `.bd` 文件的强依赖，我们不复制其图形化源文件，而是将其转化为纯脚本：
1. **独立约束文件**：新建或分离出一个干净的 `./src/constrs/IMAGE_15EG.xdc`，包含所需的管脚及时序控制逻辑。
2. **纯代码重建 Block Design**：使用 `write_bd_tcl` 从原工程将 Block Design 导出为 Tcl 命令（包括 `create_bd_cell`、`connect_bd_net` 等指令），并独立保存为 `tcl/create_bd.tcl` 供后续主流程代码调用。

### 2.2 编写模块化的生成与编译脚本
为了保证代码结构的清晰与可维护性，将整个构建过程拆分为多个独立的 TCL 脚本模块，并归档统一放置在 `./tcl/` 文件夹下。然后由主控脚本调度：
1. **tcl/01_create_project.tcl**：使用 `create_project` 初始化工程（设定名字和芯片型号 `xczu15eg-ffvb1156-2-i`），并使用 `add_files` 引入独立的约束文件。
2. **tcl/02_create_bd.tcl**：导入提取的 `create_bd.tcl`，执行原生函数 `create_root_design` 使得图形化 BD 被纯代码在内存中完全重构。
3. **tcl/03_make_wrapper.tcl**：调用 `make_wrapper` 命令为 BD 自动生成顶层 HDL（如 `.v` 包装文件），并更新编译顺序。
4. **tcl/04_build_and_export.tcl**：执行 `launch_runs impl_1 -to_step write_bitstream` 启动一键综合与实现。完成之后执行 `write_hw_platform` 直接打包输出供 Vitis/Petalinux 单用的 `IMAGE_15EG_wrapper.xsa` 文件。
5. **tcl/build_master.tcl**：总控脚本，按顺序 `source` 导入并执行以上 4 个模块化子脚本。

### 2.3 编写统一执行 Shell 脚本 (`build.sh`)
创建一个运行入口来加载 Vivado 运行环境并静默执行上述 TCL 脚本：
```bash
#!/bin/bash
#加载 Vivado 2022.2 环境
source /opt/Xilinx/Vivado/2022.2/settings64.sh

#在批处理模式下自动运行工程生成和编译
vivado -mode batch -source tcl/build_master.tcl
```

## 3. 关联的核心文件
- `IMAGE_15EG/IMAGE_15EG.xpr` 等原项目文件 — **仅用于导出配置脚本及提供基准内容参考**。
- `./src/constrs/IMAGE_15EG.xdc` — 独立存放的物理约束文件。
- `tcl/build_master.tcl` 及 `tcl/01~04_*.tcl` — 存放在独立文件夹中的模块化工程生成与编译主控脚本集。
- `tcl/create_bd.tcl` — 原工程中导出的全部 Block Design 原理图节点的纯代码化实例与连线配置。
- `build.sh` — 一键执行启动脚本。

## 4. 相关配置决策
- **Vivado 环境固定为**: `/opt/Xilinx/Vivado/2022.2`
- **目标器件固定为**: `xczu15eg-ffvb1156-2-i`

## 5. 验证标准
1. 为 `build.sh` 赋予执行权限并运行：`chmod +x build.sh && ./build.sh`。
2. 在无图形界面的状态下正常跑完流程不中断。
3. 目录下成功出现 `IMAGE_15EG_wrapper.xsa`，且无严重时序违例信息（Timing violation）。
