# xsct 构建脚本：用当前 XSA 生成 R5 standalone 平台并编译 LED 固件
# 用法：在仓库根目录运行 xsct r5_fw/build_r5_fw.tcl
# 两个核可复用同一 ELF（TCM 按核别名映射，代码无核相关逻辑）

set script_dir [file dirname [info script]]
set repo_dir  [file normalize ${script_dir}/..]
set xsa       ${repo_dir}/IMAGE_15EG_wrapper.xsa
set ws        ${script_dir}/ws

if {![file exists $xsa]} {
    error "XSA 不存在：$xsa（先运行 ./build.sh）"
}

# 保证可重复执行：清掉旧工作区
file delete -force $ws
setws $ws

platform create -name r5_plat -hw $xsa
domain create -name r5_dom -proc psu_cortexr5_0 -os standalone
platform generate -quick

app create -name r5_led -platform r5_plat -domain r5_dom -template "Empty Application"
file copy -force ${script_dir}/main.c ${ws}/r5_led/src/main.c
# 固件必须链接到 ATCM（R5 视角 0x0）：remoteproc 驱动将 TCM
# 映射为 da=0x0/0x20000，模板默认链接到 DDR(0x100000) 会加载失败
exec sed -i s/psu_r5_ddr_0_MEM_0/psu_r5_0_atcm_MEM_0/g ${ws}/r5_led/src/lscript.ld
exec sed -i {/psu_r5_0_atcm_MEM_0 : ORIGIN = 0x100000/d} ${ws}/r5_led/src/lscript.ld
app build -name r5_led

set elf ${ws}/r5_led/Debug/r5_led.elf
if {![file exists $elf]} {
    set elf ${ws}/r5_led/Release/r5_led.elf
}
file copy -force $elf ${script_dir}/r5_led.elf
puts "固件已生成：${script_dir}/r5_led.elf"
