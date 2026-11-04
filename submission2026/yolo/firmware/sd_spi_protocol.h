#ifndef FINAL_SD_SPI_PROTOCOL_H
#define FINAL_SD_SPI_PROTOCOL_H
#include <stdint.h>
// SPI R7: [31:28] command version, [27:12] reserved/extension fields,
// [11:8] voltage accepted, [7:0] check-pattern echo (SDA v6.00, 7.3.2.6).
// Match both negotiated fields, without assuming the upper 20 bits are zero.
static inline int sd_cmd8_echo_valid(uint32_t response) {
 return (response & 0xfffu) == 0x1aau;
}
#endif
