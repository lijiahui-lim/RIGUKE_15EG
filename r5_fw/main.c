/*
 * R5 LED 控制固件 (bare-metal, psu_cortexr5_0 / psu_cortexr5_1 通用)
 *
 * 控制 PL LED：PL_LED1 = bit0 (D16)，PL_LED2 = bit1 (C16)
 * AXI GPIO (axi_gpio_led) 挂在 M_AXI_HPM0_LPD，R5 经 LPD 互联直接访问。
 * 地址见 BD：tcl/02_create_bd.tcl 第 12b 节，固定为 0x80060000。
 *
 * Linux 侧该 GPIO 已在 system-user.dtsi 中置 status="disabled"，由 R5 独占。
 * 启动：
 *   echo r5_led.elf > /sys/class/remoteproc/remoteproc0/firmware
 *   echo start      > /sys/class/remoteproc/remoteproc0/state
 */

#define LED_GPIO_BASE   0x80060000UL
#define GPIO_DATA_REG   (*(volatile unsigned int *)(LED_GPIO_BASE + 0x00))
#define GPIO_TRI_REG    (*(volatile unsigned int *)(LED_GPIO_BASE + 0x04))

#define LED1            (1u << 0)   /* PL_LED1, D16 */
#define LED2            (1u << 1)   /* PL_LED2, C16 */

/* R5 主频 533MHz，粗略标定 ~1ms；仅用于呼吸灯级别的慢闪，不追求精确 */
static void delay_ms(unsigned int ms)
{
    volatile unsigned int i;
    while (ms--)
        for (i = 0; i < 130000; i++)
            ;
}

int main(void)
{
    GPIO_TRI_REG = 0;   /* 2bit 全部为输出 */

    for (;;) {
        GPIO_DATA_REG = LED1;            /* 仅 LED1 */
        delay_ms(250);
        GPIO_DATA_REG = LED1 | LED2;     /* 双亮 */
        delay_ms(250);
        GPIO_DATA_REG = LED2;            /* 仅 LED2 */
        delay_ms(250);
        GPIO_DATA_REG = 0;               /* 全灭 */
        delay_ms(250);
    }

    return 0;
}
