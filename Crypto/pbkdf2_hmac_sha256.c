#include "pbkdf2_hmac_sha256.h"
#include "hmac_sha256.h"
#include <string.h>

void PBKDF2(const void *password,size_t passwordlength,
const void *salt,size_t saltlength,
uint8_t *DK,size_t DKlength,int count)
{
	int numblocks=(DKlength+HMAC_SHA256_DIGEST_LENGTH-1)/HMAC_SHA256_DIGEST_LENGTH;
	for(int i=0;i<numblocks;i++)
	{
		uint8_t Uj[HMAC_SHA256_DIGEST_LENGTH];

		HMAC_SHA256_CTX ctx;
		HMAC_SHA256_Init(&ctx);
		HMAC_SHA256_UpdateKey(&ctx,password,passwordlength);
		HMAC_SHA256_EndKey(&ctx);
		HMAC_SHA256_StartMessage(&ctx);
		HMAC_SHA256_UpdateMessage(&ctx,salt,saltlength);
		HMAC_SHA256_UpdateMessage(&ctx,(uint8_t[4]) {
			((i+1)>>24)&0xff,
			((i+1)>>16)&0xff,
			((i+1)>>8)&0xff,
			(i+1)&0xff,
		},4);
		HMAC_SHA256_EndMessage(Uj,&ctx);
		HMAC_SHA256_Done(&ctx);

		uint8_t Ti[HMAC_SHA256_DIGEST_LENGTH];
		memcpy(Ti,Uj,HMAC_SHA256_DIGEST_LENGTH);

		for(int j=1;j<count;j++)
		{
			HMAC_SHA256_CTX ctx;
			HMAC_SHA256_Init(&ctx);
			HMAC_SHA256_UpdateKey(&ctx,password,passwordlength);
			HMAC_SHA256_EndKey(&ctx);
			HMAC_SHA256_StartMessage(&ctx);
			HMAC_SHA256_UpdateMessage(&ctx,Uj,HMAC_SHA256_DIGEST_LENGTH);
			HMAC_SHA256_EndMessage(Uj,&ctx);
			HMAC_SHA256_Done(&ctx);

			for(int k=0;k<HMAC_SHA256_DIGEST_LENGTH;k++) Ti[k]^=Uj[k];
		}

		size_t start=i*HMAC_SHA256_DIGEST_LENGTH;
		size_t bytesleft=DKlength-start;
		memcpy(&DK[start],Ti,bytesleft<HMAC_SHA256_DIGEST_LENGTH?bytesleft:HMAC_SHA256_DIGEST_LENGTH);
	}
}

void PBKDF2_3(const void *password,size_t passwordlength,
const void *salt,size_t saltlength,
uint8_t *DK1,uint8_t *DK2,uint8_t *DK3,size_t DKlength,
int count1,int count2,int count3)
{
	int numblocks=(DKlength+HMAC_SHA256_DIGEST_LENGTH-1)/HMAC_SHA256_DIGEST_LENGTH;
	for(int i=0;i<numblocks;i++)
	{
		uint8_t Uj[HMAC_SHA256_DIGEST_LENGTH];

		HMAC_SHA256_CTX ctx;
		HMAC_SHA256_Init(&ctx);
		HMAC_SHA256_UpdateKey(&ctx,password,passwordlength);
		HMAC_SHA256_EndKey(&ctx);
		HMAC_SHA256_StartMessage(&ctx);
		HMAC_SHA256_UpdateMessage(&ctx,salt,saltlength);
		HMAC_SHA256_UpdateMessage(&ctx,(uint8_t[4]) {
			((i+1)>>24)&0xff,
			((i+1)>>16)&0xff,
			((i+1)>>8)&0xff,
			(i+1)&0xff,
		},4);
		HMAC_SHA256_EndMessage(Uj,&ctx);
		HMAC_SHA256_Done(&ctx);

		uint8_t Ti[HMAC_SHA256_DIGEST_LENGTH];
		memcpy(Ti,Uj,HMAC_SHA256_DIGEST_LENGTH);

		for(int j=1;j<count1;j++)
		{
			HMAC_SHA256_CTX ctx;
			HMAC_SHA256_Init(&ctx);
			HMAC_SHA256_UpdateKey(&ctx,password,passwordlength);
			HMAC_SHA256_EndKey(&ctx);
			HMAC_SHA256_StartMessage(&ctx);
			HMAC_SHA256_UpdateMessage(&ctx,Uj,HMAC_SHA256_DIGEST_LENGTH);
			HMAC_SHA256_EndMessage(Uj,&ctx);
			HMAC_SHA256_Done(&ctx);

			for(int k=0;k<HMAC_SHA256_DIGEST_LENGTH;k++) Ti[k]^=Uj[k];
		}

		size_t start=i*HMAC_SHA256_DIGEST_LENGTH;
		size_t bytesleft=DKlength-start;
		memcpy(&DK1[start],Ti,bytesleft<HMAC_SHA256_DIGEST_LENGTH?bytesleft:HMAC_SHA256_DIGEST_LENGTH);

		for(int j=0;j<count2;j++)
		{
			HMAC_SHA256_CTX ctx;
			HMAC_SHA256_Init(&ctx);
			HMAC_SHA256_UpdateKey(&ctx,password,passwordlength);
			HMAC_SHA256_EndKey(&ctx);
			HMAC_SHA256_StartMessage(&ctx);
			HMAC_SHA256_UpdateMessage(&ctx,Uj,HMAC_SHA256_DIGEST_LENGTH);
			HMAC_SHA256_EndMessage(Uj,&ctx);
			HMAC_SHA256_Done(&ctx);

			for(int k=0;k<HMAC_SHA256_DIGEST_LENGTH;k++) Ti[k]^=Uj[k];
		}

		memcpy(&DK2[start],Ti,bytesleft<HMAC_SHA256_DIGEST_LENGTH?bytesleft:HMAC_SHA256_DIGEST_LENGTH);

		for(int j=0;j<count2;j++)
		{
			HMAC_SHA256_CTX ctx;
			HMAC_SHA256_Init(&ctx);
			HMAC_SHA256_UpdateKey(&ctx,password,passwordlength);
			HMAC_SHA256_EndKey(&ctx);
			HMAC_SHA256_StartMessage(&ctx);
			HMAC_SHA256_UpdateMessage(&ctx,Uj,HMAC_SHA256_DIGEST_LENGTH);
			HMAC_SHA256_EndMessage(Uj,&ctx);
			HMAC_SHA256_Done(&ctx);

			for(int k=0;k<HMAC_SHA256_DIGEST_LENGTH;k++) Ti[k]^=Uj[k];
		}

		memcpy(&DK3[start],Ti,bytesleft<HMAC_SHA256_DIGEST_LENGTH?bytesleft:HMAC_SHA256_DIGEST_LENGTH);
	}
}
