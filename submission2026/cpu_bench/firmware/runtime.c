#include <stddef.h>
// Compiler-generated structure initialization needs memset even with -nostdlib.
__attribute__((used,externally_visible)) void *memset(void *destination,int value,size_t length) {
 volatile unsigned char *p=(volatile unsigned char *)destination;
 while(length--) *p++=(unsigned char)value;
 return destination;
}
__attribute__((used,externally_visible)) void *memcpy(void *destination,const void *source,size_t length) {
 volatile unsigned char *d=(volatile unsigned char *)destination;
 const volatile unsigned char *s=(const volatile unsigned char *)source;
 while(length--) *d++=*s++;
 return destination;
}
