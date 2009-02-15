#import "Paths.h"

NSData *XADBuildMacPathWithData(NSData *parent,NSData *data)
{
	return XADBuildMacPathWithBuffer(parent,[data bytes],[data length]);
}

NSData *XADBuildMacPathWithBuffer(NSData *parent,const uint8_t *bytes,int length)
{
	NSMutableData *data=[NSMutableData data];

	if(parent)
	{
		[data appendData:parent];
		[data appendBytes:"/" length:1];
	}

	[data appendBytes:bytes length:length];

	// Convert slashes in name to :
	uint8_t *ptr=[data mutableBytes];
	if(parent) ptr+=[parent length]+1;
	for(int i=0;i<length;i++) if(ptr[i]=='/') ptr[i]=':';

	return data;
}
