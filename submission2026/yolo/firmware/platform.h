#ifndef FINAL_PLATFORM_H
#define FINAL_PLATFORM_H
#include <stdint.h>
#ifndef CPU_CLOCK_HZ
#define CPU_CLOCK_HZ 90000000u
#endif
#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define UART_DATA REG(0x80000000u)
#define UART_STATUS REG(0x80000004u)
#define UART_CONTROL REG(0x80000008u)
#define UART_LEVEL REG(0x8000000cu)
#define UART_RX_TOTAL REG(0x80000010u)
#define UART_RX_DROPS REG(0x80000014u)
#define UART_FRAME_ERRORS REG(0x80000018u)
#define UART_HIGHWATER REG(0x8000001cu)
#define UART_IRQ_ENABLE REG(0x80000020u)
#define UART_IRQ_PENDING REG(0x80000024u)
#define UART_ACTUAL_BAUD REG(0x80000028u)
#define UART_CLOCK_HZ REG(0x8000002cu)
#define GPIO_OUT REG(0x80001000u)
#define GPIO_IN REG(0x80001004u)
#define GPIO_DIR REG(0x80001008u)
#define GPIO_IRQ_ENABLE REG(0x8000100cu)
#define GPIO_IRQ_PENDING REG(0x80001010u)
#define MTIME_LO REG(0x80002000u)
#define MTIME_HI REG(0x80002004u)
#define MTIMECMP_LO REG(0x80002008u)
#define MTIMECMP_HI REG(0x8000200cu)
#define MSIP REG(0x80002010u)
#define FORCE_IRQ REG(0x80002014u)
#define RESULT REG(0x80002018u)
#define HDMI_CONTROL REG(0x80003000u)
#define HDMI_STATUS REG(0x80003004u)
#define HDMI_INPUT_H REG(0x80003008u)
#define HDMI_INPUT_V REG(0x8000300cu)
#define TEXT_ID REG(0x80007000u)
#define TEXT_STATUS REG(0x80007004u)
#define TEXT_COMMIT REG(0x80007008u)
#define TEXT_CURSOR REG(0x8000700cu)
#define TEXT_CURSOR_RGB REG(0x80007010u)
#define TEXT_FRAMES REG(0x80007014u)
#define TEXT_GEOMETRY REG(0x80007018u)
#define TEXT_PAGE_CELLS REG(0x8000701cu)
#define TEXT_COMMITS REG(0x80007020u)
#define TEXT_REJECTED REG(0x80007024u)
#define TEXT_FONT_COUNT REG(0x80007028u)
#define TEXT_FONT_CRC REG(0x8000702cu)
static inline void putchar_uart(char c) { while(UART_STATUS&1u) {} UART_DATA=(unsigned char)c; }
static inline void puts_uart(const char *s) { while(*s) putchar_uart(*s++); }
static inline void fence_memory(void) {
#ifdef YOLO_HOST_TEST
 __asm__ volatile("":::"memory");
#else
 __asm__ volatile("fence iorw,iorw":::"memory");
#endif
}
static inline void timer_set(uint64_t v) {
 MTIMECMP_LO=0xffffffffu; MTIMECMP_HI=(uint32_t)(v>>32); MTIMECMP_LO=(uint32_t)v;
}
#endif
