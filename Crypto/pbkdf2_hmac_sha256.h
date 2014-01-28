#ifndef __PBKDF2_HMAC_SHA256_H__
#define __PBKDF2_HMAC_SHA256_H__

#include <stdlib.h>
#include <stdint.h>

void PBKDF2(const void *password,size_t passwordlength,
const void *salt,size_t saltlength,
uint8_t *DK,size_t DKlength,int count);

void PBKDF2_3(const void *password,size_t passwordlength,
const void *salt,size_t saltlength,
uint8_t *DK1,uint8_t *DK2,uint8_t *DK3,size_t DKlength,
int count1,int count2,int count3);

#endif
