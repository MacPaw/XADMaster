#import <Foundation/Foundation.h>

uint32_t XADCRC32(uint32_t prevcrc,uint8_t byte,uint32_t *table);

extern uint32_t XADCRC32Table_edb88320[256];
