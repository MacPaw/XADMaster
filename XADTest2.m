#import <XADMaster/XADArchiveParser.h>
#import <XADChecksums.h>

@interface TestDelegate:NSObject
@end

@implementation TestDelegate

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	NSLog(@"%@",dict);

	CSHandle *fh=[parser handleForEntryWithDictionary:dict];
	NSData *data=[fh remainingFileContents];

	uint32_t crc=0xffffffff;
	int length=[data length];
	const uint8_t *bytes=[data bytes];
	for(int i=0;i<length;i++) crc=XADCRC32(crc,bytes[i],XADCRC32Table_edb88320);
	NSLog(@"crc: %d length:%d",~crc,length);

/*	if(~crc!=[[dict objectForKey:@"ZipCRC32"] unsignedIntValue])
	{
		NSMutableString *name=[NSMutableString stringWithString:[[dict objectForKey:XADFileNameKey] string]];
		[name replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0,[name length])];
		[data writeToFile:name atomically:YES];
	}*/

	NSLog(@"%@",[data subdataWithRange:NSMakeRange(0,[data length]<256?[data length]:256)]);
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return NO;
}

@end

int main(int argc,char **argv)
{
	for(int i=1;i<argc;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[NSString stringWithUTF8String:argv[i]];
		XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

		NSLog(@"Parsing %@",filename);

		[parser setDelegate:[TestDelegate new]];
		[parser setPassword:@"test"];
//		[parser setPassword:@"www.joomla.com.tr"];

		[parser parse];

		[pool release];
	}
	return 0;
}
