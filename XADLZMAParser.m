#import "XADLZMAParser.h"
#import "XADLZMAHandle.h"

@implementation XADLZMAParser

+(int)requiredHeaderSize { return 0; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	// Geez, put some magic bytes in your file formats, people!
	if([name rangeOfString:@".lzma" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound) return YES;
	if([name rangeOfString:@".tlz" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound) return YES;
	return NO;
}

-(void)parse
{
	CSHandle *handle=[self handle];

	NSString *name=[self name];
	NSString *extension=[[name pathExtension] lowercaseString];
	NSString *contentname;
	if([extension isEqual:@"tlz"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"tar"];
	else contentname=[name stringByDeletingPathExtension];

	NSData *props=[handle readDataOfLength:5];

	// TODO: set no filename flag
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADStringWithString:contentname],XADFileNameKey,
		[self XADStringWithString:@"LZMA"],XADCompressionNameKey,
		props,@"LZMAProperties",
	nil];

	uint64_t size=[handle readUInt64LE];
	if(size!=0xffffffffffffffff)
	[dict setObject:[NSNumber numberWithUnsignedLongLong:size] forKey:XADFileSizeKey];

	@try {
		off_t filesize=[[self handle] fileSize];
		[dict setObject:[NSNumber numberWithUnsignedLongLong:filesize-13] forKey:XADCompressedSizeKey];
	} @catch(id e) { }

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	NSNumber *size=[dictionary objectForKey:XADFileSizeKey];
	[handle seekToFileOffset:13];

	if(size) return [[[XADLZMAHandle alloc] initWithHandle:handle length:[size unsignedLongLongValue]
	propertyData:[dictionary objectForKey:@"LZMAProperties"]] autorelease];
	else return [[[XADLZMAHandle alloc] initWithHandle:handle
	propertyData:[dictionary objectForKey:@"LZMAProperties"]] autorelease];

}

-(NSString *)formatName { return @"LZMA"; }

@end
