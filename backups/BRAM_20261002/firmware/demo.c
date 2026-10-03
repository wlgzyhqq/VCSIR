#include "platform.h"
static volatile uint32_t values[24];
static uint32_t calculate(uint32_t n) __attribute__((noinline));
static uint32_t calculate(uint32_t n) {
 uint32_t a=1,b=1;
 for(uint32_t i=0;i<n;i++) { uint32_t c=a+b; a=b;b=c;values[i]=c; }
 uint32_t sum=0;for(uint32_t i=0;i<n;i++) sum+=values[i];return sum;
}
int main(void) {
 GPIO_DIR=3;GPIO_OUT=0x0100;
 if(calculate(12)!=984u) { RESULT=0xdead0001;for(;;){} }
 puts_uart("FINAL RV32I: C PASS\r\n");
 RESULT=1;
 // CPU reads active-low board keys through synchronizers and updates LEDs.
 for(;;) {
   uint32_t keys=(GPIO_IN>>8)&3u;
   GPIO_OUT=((keys?0xa5u:0x01u)<<8) | keys;
   if(UART_STATUS&2u) { unsigned c=UART_DATA&255u; putchar_uart((char)c); }
 }
}
