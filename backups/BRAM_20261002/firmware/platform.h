#ifndef FINAL_PLATFORM_H
#define FINAL_PLATFORM_H
#include <stdint.h>
#define REG(a) (*(volatile uint32_t *)(a))
#define UART_DATA REG(0x80000000u)
#define UART_STATUS REG(0x80000004u)
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
static inline void putchar_uart(char c) { while(UART_STATUS&1u) {} UART_DATA=(unsigned char)c; }
static inline void puts_uart(const char *s) { while(*s) putchar_uart(*s++); }
static inline void fence_memory(void) { __asm__ volatile("fence iorw,iorw":::"memory"); }
static inline void timer_set(uint64_t v) {
 MTIMECMP_LO=0xffffffffu; MTIMECMP_HI=(uint32_t)(v>>32); MTIMECMP_LO=(uint32_t)v;
}
#endif
