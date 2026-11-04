#ifndef FINAL_CORE_PORTME_H
#define FINAL_CORE_PORTME_H
#include <stdint.h>
#include <stddef.h>
#define HAS_FLOAT 1
#define HAS_TIME_H 0
#define USE_CLOCK 0
#define HAS_STDIO 0
#define HAS_PRINTF 0
#ifdef __TINYC__
#define COMPILER_VERSION "TinyCC 0.9.27 (PC functional test only)"
#else
#define COMPILER_VERSION "GCC " __VERSION__
#endif
#ifndef FLAGS_STR
#define FLAGS_STR "unspecified"
#endif
#define COMPILER_FLAGS FLAGS_STR
#define MEM_LOCATION "64KiB on-chip RAM, existing 2-way I/D caches; CPU-only SoC"
typedef int16_t ee_s16;
typedef uint16_t ee_u16;
typedef int32_t ee_s32;
typedef uint32_t ee_u32;
typedef uint8_t ee_u8;
typedef double ee_f32;
typedef uintptr_t ee_ptr_int;
typedef size_t ee_size_t;
#define align_mem(x) (void *)(4+(((ee_ptr_int)(x)-1)&~(ee_ptr_int)3))
typedef uint32_t CORE_TICKS;
#define SEED_METHOD SEED_VOLATILE
#define MEM_METHOD MEM_STATIC
#define MULTITHREAD 1
#define MAIN_HAS_NOARGC 1
#define MAIN_HAS_NORETURN 0
#define PERFORMANCE_RUN 1
extern ee_u32 default_num_contexts;
typedef struct {ee_u8 portable_id;} core_portable;
void portable_init(core_portable *,int *,char *[]);
void portable_fini(core_portable *);
int ee_printf(const char *,...);
#endif
