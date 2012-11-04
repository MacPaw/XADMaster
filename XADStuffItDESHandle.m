#import "XADStuffItDESHandle.h"
#import "XADException.h"

typedef struct StuffItDESKeySchedule
{
	uint32_t subkeys[16][2];
} StuffItDESKeySchedule;

static void StuffItDESSetKey(const uint8_t key[8],StuffItDESKeySchedule *ks);
static void StuffItDESCrypt(uint8_t data[8],StuffItDESKeySchedule *ks,BOOL enc);

static inline uint32_t RotateRight(uint32_t val,int n) { return (val>>n)+(val<<(32-n)); }

@implementation XADStuffItDESHandle

+(NSData *)keyForPasswordData:(NSData *)passworddata entryKey:(NSData *)entrykey MKey:(NSData *)mkey
{
	StuffItDESKeySchedule ks;

	if(!mkey||[mkey length]!=8) [XADException raiseIllegalDataException];

	uint8_t passblock[8]={0,0,0,0,0,0,0,0};
	int length=[passworddata length];
	if(length>8) length=8;
	memcpy(passblock,[passworddata bytes],length);

	// Calculate archive key and IV from password and mkey
	uint8_t archivekey[8],archiveiv[8];

	const uint8_t initialkey[8]={0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef};
	for(int i=0;i<8;i++) archivekey[i]=initialkey[i]^(passblock[i]&0x7f);
	StuffItDESSetKey(initialkey,&ks);
	StuffItDESCrypt(archivekey,&ks,YES);
	
	memcpy(archiveiv,[mkey bytes],8);
	StuffItDESSetKey(archivekey,&ks);
	StuffItDESCrypt(archiveiv,&ks,NO);

	// Verify the password.
	uint8_t verifyblock[8]={0,0,0,0,0,0,0,4};
	memcpy(verifyblock,archiveiv,4);
	StuffItDESSetKey(archivekey,&ks);
	StuffItDESCrypt(verifyblock,&ks,YES);
	if(memcmp(verifyblock+4,archiveiv+4,4)!=0) return nil;

	// Calculate file key and IV from entrykey, archive key and IV.
	uint8_t filekey[8],fileiv[8];
	memcpy(filekey,[entrykey bytes],8);
	memcpy(fileiv,[entrykey bytes]+8,8);

	StuffItDESSetKey(archivekey,&ks);
	StuffItDESCrypt(filekey,&ks,NO);
	for(int i=0;i<8;i++) filekey[i]^=archiveiv[i];
	StuffItDESSetKey(filekey,&ks);
	StuffItDESCrypt(fileiv,&ks,NO);
	
	NSMutableData *key=[NSMutableData dataWithBytes:filekey length:8];
	[key appendBytes:fileiv length:8];

	return key;
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength key:keydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata
{
	if([keydata length]!=16) [XADException raiseUnknownException];
	if((self=[super initWithHandle:handle length:length]))
	{
		const uint8_t *keybytes=[keydata bytes];
		A=CSUInt32BE(&keybytes[0]);
		B=CSUInt32BE(&keybytes[4]);
		C=CSUInt32BE(&keybytes[8]);
		D=CSUInt32BE(&keybytes[12]);

		[self setBlockPointer:block];
	}
	return self;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	for(int i=0;i<sizeof(block);i++)
	{
		if(CSInputAtEOF(input)) [XADException raiseIllegalDataException];
		block[i]=CSInputNextByte(input);
	}
	
	uint32_t left=CSUInt32BE(&block[0]);
	uint32_t right=CSUInt32BE(&block[4]);
	uint32_t l=left^A^C;
	uint32_t r=right^B^D;
	CSSetUInt32BE(&block[0],l);
	CSSetUInt32BE(&block[4],r);

	C=D;
	D=RotateRight(left^right^A^B^D,1);

	return 8;
}

@end



// StuffItDES is a modified DES that ROLs the input, does the DES rounds
// without IP, then RORs result.  It also uses its own key schedule.
// It is only used for key management.

static uint32_t ReverseBits(uint32_t val)
{
	uint32_t res=0;
	for(int i=0;i<32;i++)
	{
		res<<=1;
		res|=val&1;
		val>>=1;
	}
	return res;
}

static inline uint32_t Nibble(const uint8_t key[8],int n)
{
	return (key[(n&0x0f)>>1]>>(((n^1)&1)<<2))&0x0f;
}

static void StuffItDESSetKey(const uint8_t key[8],StuffItDESKeySchedule *ks)
{
	for(int i=0;i<16;i++)
	{
		uint32_t subkey1=((Nibble(key,i)>>2)|(Nibble(key,i+13)<<2));
		subkey1|=((Nibble(key,i+11)>>2)|(Nibble(key,i+6)<<2))<<8;
		subkey1|=((Nibble(key,i+3)>>2)|(Nibble(key,i+10)<<2))<<16;
		subkey1|=((Nibble(key,i+8)>>2)|(Nibble(key,i+1)<<2))<<24;		
		uint32_t subkey0=((Nibble(key,i+9)|(Nibble(key,i)<<4))&0x3f);
		subkey0|=((Nibble(key,i+2)|(Nibble(key,i+11)<<4))&0x3f)<<8;
		subkey0|=((Nibble(key,i+14)|(Nibble(key,i+3)<<4))&0x3f)<<16;
		subkey0|=((Nibble(key,i+5)|(Nibble(key,i+8)<<4))&0x3f)<<24;

		// This is a little-endian DES implementation, so in order to get the
		// key schedule right, we need to bit-reverse and swap the even/odd
		// subkeys. This is not needed for a regular DES implementation.
		subkey0=ReverseBits(subkey0);
		subkey1=ReverseBits(subkey1);
		ks->subkeys[i][0]=subkey1;
		ks->subkeys[i][1]=subkey0;
	}
}



static const uint32_t DES_SPtrans[8][64];

static inline void Encrypt(uint32_t *left,uint32_t right,uint32_t *subkey)
{
	uint32_t u=right^subkey[0];
	uint32_t t=RotateRight(right,4)^subkey[1];
	*left^=
	DES_SPtrans[0][(u>>2)&0x3f]^
	DES_SPtrans[2][(u>>10)&0x3f]^
	DES_SPtrans[4][(u>>18)&0x3f]^
	DES_SPtrans[6][(u>>26)&0x3f]^
	DES_SPtrans[1][(t>>2)&0x3f]^
	DES_SPtrans[3][(t>>10)&0x3f]^
	DES_SPtrans[5][(t>>18)&0x3f]^
	DES_SPtrans[7][(t>>26)&0x3f];
}

static void StuffItDESCrypt(uint8_t data[8],StuffItDESKeySchedule *ks,BOOL enc)
{
	uint32_t left=ReverseBits(CSUInt32BE(&data[0]));
	uint32_t right=ReverseBits(CSUInt32BE(&data[4]));

	right=RotateRight(right,29);
	left=RotateRight(left,29);

	if(enc)
	{
		for(int i=0;i<16;i+=2)
		{
			Encrypt(&left,right,ks->subkeys[i]);
			Encrypt(&right,left,ks->subkeys[i+1]);
		}
	}
	else
	{
		for(int i=15;i>0;i-=2)
		{
			Encrypt(&left,right,ks->subkeys[i]);
			Encrypt(&right,left,ks->subkeys[i-1]);
		}
	}

	left=RotateRight(left,3);
	right=RotateRight(right,3);

	CSSetUInt32BE(&data[0],ReverseBits(right));
	CSSetUInt32BE(&data[4],ReverseBits(left));
}

static const uint32_t DES_SPtrans[8][64]=
{
	{
		0x02080800,0x00080000,0x02000002,0x02080802,
		0x02000000,0x00080802,0x00080002,0x02000002,
		0x00080802,0x02080800,0x02080000,0x00000802,
		0x02000802,0x02000000,0x00000000,0x00080002,
		0x00080000,0x00000002,0x02000800,0x00080800,
		0x02080802,0x02080000,0x00000802,0x02000800,
		0x00000002,0x00000800,0x00080800,0x02080002,
		0x00000800,0x02000802,0x02080002,0x00000000,
		0x00000000,0x02080802,0x02000800,0x00080002,
		0x02080800,0x00080000,0x00000802,0x02000800,
		0x02080002,0x00000800,0x00080800,0x02000002,
		0x00080802,0x00000002,0x02000002,0x02080000,
		0x02080802,0x00080800,0x02080000,0x02000802,
		0x02000000,0x00000802,0x00080002,0x00000000,
		0x00080000,0x02000000,0x02000802,0x02080800,
		0x00000002,0x02080002,0x00000800,0x00080802,
	},
	{
		0x40108010,0x00000000,0x00108000,0x40100000,
		0x40000010,0x00008010,0x40008000,0x00108000,
		0x00008000,0x40100010,0x00000010,0x40008000,
		0x00100010,0x40108000,0x40100000,0x00000010,
		0x00100000,0x40008010,0x40100010,0x00008000,
		0x00108010,0x40000000,0x00000000,0x00100010,
		0x40008010,0x00108010,0x40108000,0x40000010,
		0x40000000,0x00100000,0x00008010,0x40108010,
		0x00100010,0x40108000,0x40008000,0x00108010,
		0x40108010,0x00100010,0x40000010,0x00000000,
		0x40000000,0x00008010,0x00100000,0x40100010,
		0x00008000,0x40000000,0x00108010,0x40008010,
		0x40108000,0x00008000,0x00000000,0x40000010,
		0x00000010,0x40108010,0x00108000,0x40100000,
		0x40100010,0x00100000,0x00008010,0x40008000,
		0x40008010,0x00000010,0x40100000,0x00108000,
	},
	{
		0x04000001,0x04040100,0x00000100,0x04000101,
		0x00040001,0x04000000,0x04000101,0x00040100,
		0x04000100,0x00040000,0x04040000,0x00000001,
		0x04040101,0x00000101,0x00000001,0x04040001,
		0x00000000,0x00040001,0x04040100,0x00000100,
		0x00000101,0x04040101,0x00040000,0x04000001,
		0x04040001,0x04000100,0x00040101,0x04040000,
		0x00040100,0x00000000,0x04000000,0x00040101,
		0x04040100,0x00000100,0x00000001,0x00040000,
		0x00000101,0x00040001,0x04040000,0x04000101,
		0x00000000,0x04040100,0x00040100,0x04040001,
		0x00040001,0x04000000,0x04040101,0x00000001,
		0x00040101,0x04000001,0x04000000,0x04040101,
		0x00040000,0x04000100,0x04000101,0x00040100,
		0x04000100,0x00000000,0x04040001,0x00000101,
		0x04000001,0x00040101,0x00000100,0x04040000,
	},
	{
		0x00401008,0x10001000,0x00000008,0x10401008,
		0x00000000,0x10400000,0x10001008,0x00400008,
		0x10401000,0x10000008,0x10000000,0x00001008,
		0x10000008,0x00401008,0x00400000,0x10000000,
		0x10400008,0x00401000,0x00001000,0x00000008,
		0x00401000,0x10001008,0x10400000,0x00001000,
		0x00001008,0x00000000,0x00400008,0x10401000,
		0x10001000,0x10400008,0x10401008,0x00400000,
		0x10400008,0x00001008,0x00400000,0x10000008,
		0x00401000,0x10001000,0x00000008,0x10400000,
		0x10001008,0x00000000,0x00001000,0x00400008,
		0x00000000,0x10400008,0x10401000,0x00001000,
		0x10000000,0x10401008,0x00401008,0x00400000,
		0x10401008,0x00000008,0x10001000,0x00401008,
		0x00400008,0x00401000,0x10400000,0x10001008,
		0x00001008,0x10000000,0x10000008,0x10401000,
	},
	{
		0x08000000,0x00010000,0x00000400,0x08010420,
		0x08010020,0x08000400,0x00010420,0x08010000,
		0x00010000,0x00000020,0x08000020,0x00010400,
		0x08000420,0x08010020,0x08010400,0x00000000,
		0x00010400,0x08000000,0x00010020,0x00000420,
		0x08000400,0x00010420,0x00000000,0x08000020,
		0x00000020,0x08000420,0x08010420,0x00010020,
		0x08010000,0x00000400,0x00000420,0x08010400,
		0x08010400,0x08000420,0x00010020,0x08010000,
		0x00010000,0x00000020,0x08000020,0x08000400,
		0x08000000,0x00010400,0x08010420,0x00000000,
		0x00010420,0x08000000,0x00000400,0x00010020,
		0x08000420,0x00000400,0x00000000,0x08010420,
		0x08010020,0x08010400,0x00000420,0x00010000,
		0x00010400,0x08010020,0x08000400,0x00000420,
		0x00000020,0x00010420,0x08010000,0x08000020,
	},
	{
		0x80000040,0x00200040,0x00000000,0x80202000,
		0x00200040,0x00002000,0x80002040,0x00200000,
		0x00002040,0x80202040,0x00202000,0x80000000,
		0x80002000,0x80000040,0x80200000,0x00202040,
		0x00200000,0x80002040,0x80200040,0x00000000,
		0x00002000,0x00000040,0x80202000,0x80200040,
		0x80202040,0x80200000,0x80000000,0x00002040,
		0x00000040,0x00202000,0x00202040,0x80002000,
		0x00002040,0x80000000,0x80002000,0x00202040,
		0x80202000,0x00200040,0x00000000,0x80002000,
		0x80000000,0x00002000,0x80200040,0x00200000,
		0x00200040,0x80202040,0x00202000,0x00000040,
		0x80202040,0x00202000,0x00200000,0x80002040,
		0x80000040,0x80200000,0x00202040,0x00000000,
		0x00002000,0x80000040,0x80002040,0x80202000,
		0x80200000,0x00002040,0x00000040,0x80200040,
	},
	{
		0x00004000,0x00000200,0x01000200,0x01000004L,
		0x01004204,0x00004004,0x00004200,0x00000000,
		0x01000000,0x01000204,0x00000204,0x01004000,
		0x00000004,0x01004200,0x01004000,0x00000204L,
		0x01000204,0x00004000,0x00004004,0x01004204L,
		0x00000000,0x01000200,0x01000004,0x00004200,
		0x01004004,0x00004204,0x01004200,0x00000004L,
		0x00004204,0x01004004,0x00000200,0x01000000,
		0x00004204,0x01004000,0x01004004,0x00000204L,
		0x00004000,0x00000200,0x01000000,0x01004004L,
		0x01000204,0x00004204,0x00004200,0x00000000,
		0x00000200,0x01000004,0x00000004,0x01000200,
		0x00000000,0x01000204,0x01000200,0x00004200,
		0x00000204,0x00004000,0x01004204,0x01000000,
		0x01004200,0x00000004,0x00004004,0x01004204L,
		0x01000004,0x01004200,0x01004000,0x00004004L,
	},
	{
		0x20800080,0x20820000,0x00020080,0x00000000,
		0x20020000,0x00800080,0x20800000,0x20820080,
		0x00000080,0x20000000,0x00820000,0x00020080,
		0x00820080,0x20020080,0x20000080,0x20800000,
		0x00020000,0x00820080,0x00800080,0x20020000,
		0x20820080,0x20000080,0x00000000,0x00820000,
		0x20000000,0x00800000,0x20020080,0x20800080,
		0x00800000,0x00020000,0x20820000,0x00000080,
		0x00800000,0x00020000,0x20000080,0x20820080,
		0x00020080,0x20000000,0x00000000,0x00820000,
		0x20800080,0x20020080,0x20020000,0x00800080,
		0x20820000,0x00000080,0x00800080,0x20020000,
		0x20820080,0x00800000,0x20800000,0x20000080,
		0x00820000,0x00020080,0x20020080,0x20800000,
		0x00000080,0x20820000,0x00820080,0x00000000,
		0x20000000,0x20800080,0x00020000,0x00820080,
	}
};
