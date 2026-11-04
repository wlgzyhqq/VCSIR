#ifndef YOLO_STORAGE_H
#define YOLO_STORAGE_H
#include <stdint.h>
int storage_init(void);uint64_t storage_capacity(void);uint32_t storage_error(void);
int storage_sector(uint32_t lba,uint8_t out[512]);
int storage_crc(uint32_t address,uint32_t bytes,uint32_t expected);
int storage_load_fast(uint32_t lba,uint32_t bytes,uint32_t address,uint32_t expected);
int storage_load(uint32_t lba,uint32_t bytes,uint32_t address,uint32_t expected);
#endif
