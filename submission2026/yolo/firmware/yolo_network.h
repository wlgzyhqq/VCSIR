#ifndef YOLO_NETWORK_H
#define YOLO_NETWORK_H
#include <stdint.h>
typedef struct {int32_t x1,y1,x2,y2;uint16_t score;uint8_t label,reserved;} YoloBox;
typedef void (*YoloProgress)(uint32_t node,uint32_t total,uint32_t ticks,uint32_t crc);
// Return 0 on success, otherwise (node_id<<16)|error. DDR inputs and all
// intermediate tensors are in the uncached aperture >=0x02000000.
uint32_t yolo_input_bytes(void);
uint32_t yolo_infer(uint32_t input_address,YoloProgress progress,uint32_t verify_layers);
// Input is the actual displayed unannotated RGB565 image. Produces signed8
// CHW at scale1/127, matching the bit-expanded display colours exactly.
uint32_t yolo_prepare_rgb565(uint32_t image_address,uint32_t input_address);
uint32_t yolo_tensor_crc(uint32_t address,uint32_t bytes);
uint32_t yolo_detect(YoloBox *boxes,uint32_t capacity);
const char *yolo_label(uint32_t label);
#endif
