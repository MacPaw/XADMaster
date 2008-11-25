#import "XADPaths.h"

NSData *XADBuildMacPathWithData(NSData *parent,NSData *data)
{
	return XADBuildMacPathWithBuffer(parent,[data bytes],[data length]);
}

NSData *XADBuildMacPathWithBuffer(NSData *parent,const char *bytes,int length)
{
	NSMutableData *data=[NSMutableData data];

	if(parent)
	{
		[data appendData:parent];
		[data appendBytes:"/" length:1];
	}

	for(int i=0;i<length;i++)
	{
		if(bytes[i]=='/') [data appendBytes:":" length:1];
		else [data appendBytes:&bytes[i] length:1];
	}

	return data;
}
