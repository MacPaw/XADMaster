#import "XADStuffItDESHandle.h"
#import "XADException.h"

static void StuffItDESSetKey(const_DES_cblock key,DES_key_schedule *ks);
static void StuffItDESCrypt(DES_cblock data,DES_key_schedule *ks,BOOL enc);

#define ROTATE(a,n) (((a)>>(n))+((a)<<(32-(n))))
#define READ_32BE(p) ((((p)[0]&0xFF)<<24)|(((p)[1]&0xFF)<<16)|(((p)[2]&0xFF)<<8)|((p)[3]&0xFF))
#define READ_64BE(p, l, r) { l=READ_32BE(p); r=READ_32BE((p)+4); }
#define WRITE_32BE(p, n) (p)[0]=(n)>>24,(p)[1]=(n)>>16,(p)[2]=(n)>>8,(p)[3]=(n)
#define WRITE_64BE(p, l, r) { WRITE_32BE(p, l); WRITE_32BE((p)+4, r); }

@implementation XADStuffItDESHandle

+(NSData *)keyForPasswordData:(NSData *)passworddata entryKey:(NSData *)entrykey MKey:(NSData *)mkey
{
	DES_key_schedule ks;

	if(!mkey||[mkey length]!=8) [XADException raiseIllegalDataException];

	DES_cblock passblock={0,0,0,0,0,0,0,0};
	int length=[passworddata length];
	if(length>8) length=8;
	memcpy(passblock,[passworddata bytes],length);

	// Calculate archive key and IV from password and mkey
	DES_cblock archivekey;
	DES_cblock archiveiv;

	const_DES_cblock initialkey={0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef};
	for(int i=0;i<8;i++) archivekey[i]=initialkey[i]^(passblock[i]&0x7f);
	StuffItDESSetKey(initialkey,&ks);
	StuffItDESCrypt(archivekey,&ks,YES);
	
	memcpy(archiveiv,[mkey bytes],8);
	StuffItDESSetKey(archivekey,&ks);
	StuffItDESCrypt(archiveiv,&ks,NO);

	// Verify the password.
	DES_cblock verifyblock={0,0,0,0,0,0,0,4};
	memcpy(verifyblock,archiveiv,4);
	StuffItDESSetKey(archivekey,&ks);
	StuffItDESCrypt(verifyblock,&ks,YES);
	if(memcmp(verifyblock+4,archiveiv+4,4)!=0) return nil;

	// Calculate file key and IV from entrykey, archive key and IV.
	DES_cblock filekey;
	DES_cblock fileiv;
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
		READ_64BE(keybytes, A, B);
		READ_64BE(keybytes+sizeof(DES_cblock), C, D);
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
	
	DES_LONG left, right, l, r;
	READ_64BE(block, left, right);
	l=left ^A^C;
	r=right^B^D;
	WRITE_64BE(block, l, r);

	//DES_LONG oldC=C;
	C=D;
	//if (enc) D=ROTATE(left^right^oldC, 1); else
	D=ROTATE(left^right^A^B^D, 1);

	return sizeof(block);
}

@end


/*
 StuffItDES is a modified DES that ROLs the input, does the DES rounds
 without IP, then RORs result.  It also uses its own key schedule.
 It is only used for key management.
 */

DES_LONG _reverseBits(DES_LONG in)
{
	DES_LONG out=0;
	int i;
	for(i=0; i<32; i++)
	{
		out<<=1;
		out|=in&1;
		in>>=1;
	}
	return out;
}

static void StuffItDESSetKey(const_DES_cblock key, DES_key_schedule* ks)
{
	int i;
	DES_LONG subkey0, subkey1;
	
#define NIBBLE(i) ((key[((i)&0x0F)>>1]>>((((i)^1)&1)<<2))&0x0F)
	for(i=0; i<16; i++)
	{
		subkey1 =((NIBBLE(i)>>2)|(NIBBLE(i+13)<<2));
		subkey1|=((NIBBLE(i+11)>>2)|(NIBBLE(i+6)<<2))<<8;
		subkey1|=((NIBBLE(i+3)>>2)|(NIBBLE(i+10)<<2))<<16;
		subkey1|=((NIBBLE(i+8)>>2)|(NIBBLE(i+1)<<2))<<24;		
		subkey0 =((NIBBLE(i+9)|(NIBBLE(i)<<4))&0x3F);
		subkey0|=((NIBBLE(i+2)|(NIBBLE(i+11)<<4))&0x3F)<<8;
		subkey0|=((NIBBLE(i+14)|(NIBBLE(i+3)<<4))&0x3F)<<16;
		subkey0|=((NIBBLE(i+5)|(NIBBLE(i+8)<<4))&0x3F)<<24;
		ks->ks[i].deslong[1]=subkey1;
		ks->ks[i].deslong[0]=subkey0;
	}
#undef NIBBLE
	
	/* OpenSSL's DES implementation treats its input as little-endian
	 (most don't), so in order to build the internal key schedule
	 the way OpenSSL expects, we need to bit-reverse the key schedule
	 and swap the even/odd subkeys.  Also, because of an internal rotation
	 optimization, we need to rotate the second subkeys left 4.  None
	 of this is necessary for a standard DES implementation.
	 */
	for(i=0; i<16; i++)
	{
		/* Swap subkey pair */
		subkey0=ks->ks[i].deslong[1];
		subkey1=ks->ks[i].deslong[0];
		/* Reverse bits */
		subkey0=_reverseBits(subkey0);
		subkey1=_reverseBits(subkey1);
		/* Rotate second subkey left 4 */
		subkey1=ROTATE(subkey1,28);
		/* Write back OpenSSL-tweaked subkeys */
		ks->ks[i].deslong[0]=subkey0;
		ks->ks[i].deslong[1]=subkey1;
	}
}

#define PERMUTATION(a,b,t,n,m) \
(t)=((((a)>>(n))^(b))&(m)); \
(b)^=(t); \
(a)^=((t)<<(n))

void _initialPermutation(DES_LONG *ioLeft, DES_LONG *ioRight)
{
	DES_LONG temp;
	DES_LONG left=*ioLeft;
	DES_LONG right=*ioRight;
	PERMUTATION(left, right, temp, 4, 0x0f0f0f0fL);
	PERMUTATION(left, right, temp,16, 0x0000ffffL);
	PERMUTATION(right, left, temp, 2, 0x33333333L);
	PERMUTATION(right, left, temp, 8, 0x00ff00ffL);
	PERMUTATION(left, right, temp, 1, 0x55555555L);
	left=ROTATE(left, 31);
	right=ROTATE(right, 31);
	*ioLeft=left;
	*ioRight=right;
}

void _finalPermutation(DES_LONG *ioLeft, DES_LONG *ioRight)
{
	DES_LONG temp;
	DES_LONG left=*ioLeft;
	DES_LONG right=*ioRight;
	left=ROTATE(left, 1);
	right=ROTATE(right, 1);
	PERMUTATION(left, right, temp, 1, 0x55555555L);
	PERMUTATION(right, left, temp, 8, 0x00ff00ffL);
	PERMUTATION(right, left, temp, 2, 0x33333333L);
	PERMUTATION(left, right, temp,16, 0x0000ffffL);
	PERMUTATION(left, right, temp, 4, 0x0f0f0f0fL);
	*ioLeft=left;
	*ioRight=right;
}


static void StuffItDESCrypt(DES_cblock data,DES_key_schedule* ks,BOOL enc)
{
	DES_LONG left, right;
	DES_cblock input, output;
	
	READ_64BE(data, left, right);
	
	/* This DES variant ROLs the input and RORs the output */
	left=ROTATE(left, 31);
	right=ROTATE(right, 31);
	
	/* This DES variant skips the initial permutation (and subsequent inverse).
	 Since we want to use a standard DES library (which includes them), we
	 wrap the encryption with the inverse permutations.
	 */
	_finalPermutation(&left, &right);
	
	WRITE_64BE(input, left, right);
	
	DES_ecb_encrypt(&input, &output, ks, enc);
	
	READ_64BE(output, left, right);
	
	_initialPermutation(&left, &right);
	
	left=ROTATE(left, 1);
	right=ROTATE(right, 1);
	
	WRITE_64BE(data, left, right);
}

