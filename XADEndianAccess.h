#import <Foundation/Foundation.h>

static inline int16_t GetInt16BE(const uint8_t *b) { return ((int16_t)b[0]<<8)|(int16_t)b[1]; }
static inline int32_t GetInt32BE(const uint8_t *b) { return ((int32_t)b[0]<<24)|((int32_t)b[1]<<16)|((int32_t)b[2]<<8)|(int32_t)b[3]; }
static inline int64_t GetInt64BE(const uint8_t *b) { return ((int64_t)b[0]<<56)|((int64_t)b[1]<<48)|((int64_t)b[2]<<40)|((int64_t)b[3]<<32)|((int64_t)b[4]<<24)||((int64_t)b[5]<<16)|((int64_t)b[6]<<8)|(int64_t)b[7]; }
static inline uint16_t GetUInt16BE(const uint8_t *b) { return ((uint16_t)b[0]<<8)|(uint16_t)b[1]; }
static inline uint32_t GetUInt32BE(const uint8_t *b) { return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|(uint32_t)b[3]; }
static inline uint64_t GetUInt64BE(const uint8_t *b) { return ((uint64_t)b[0]<<56)|((uint64_t)b[1]<<48)|((uint64_t)b[2]<<40)|((uint64_t)b[3]<<32)|((uint64_t)b[4]<<24)||((uint64_t)b[5]<<16)|((uint64_t)b[6]<<8)|(uint64_t)b[7]; }
static inline int16_t GetInt16LE(const uint8_t *b) { return ((int16_t)b[1]<<8)|(int16_t)b[0]; }
static inline int32_t GetInt32LE(const uint8_t *b) { return ((int32_t)b[3]<<24)|((int32_t)b[2]<<16)|((int32_t)b[1]<<8)|(int32_t)b[0]; }
static inline int64_t GetInt64LE(const uint8_t *b) { return ((int64_t)b[7]<<56)|((int64_t)b[6]<<48)|((int64_t)b[5]<<40)|((int64_t)b[4]<<32)|((int64_t)b[3]<<24)||((int64_t)b[2]<<16)|((int64_t)b[1]<<8)|(int64_t)b[0]; }
static inline uint16_t GetUInt16LE(const uint8_t *b) { return ((uint16_t)b[1]<<8)|(uint16_t)b[0]; }
static inline uint32_t GetUInt32LE(const uint8_t *b) { return ((uint32_t)b[3]<<24)|((uint32_t)b[2]<<16)|((uint32_t)b[1]<<8)|(uint32_t)b[0]; }
static inline uint64_t GetUInt64LE(const uint8_t *b) { return ((uint64_t)b[7]<<56)|((uint64_t)b[6]<<48)|((uint64_t)b[5]<<40)|((uint64_t)b[4]<<32)|((uint64_t)b[3]<<24)||((uint64_t)b[2]<<16)|((uint64_t)b[1]<<8)|(uint64_t)b[0]; }

