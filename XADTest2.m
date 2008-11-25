#import <XADMaster/XADArchiveParser.h>

@interface TestDelegate:NSObject
@end

@implementation TestDelegate

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	NSLog(@"%@",dict);

	CSHandle *fh=[parser handleForEntryWithDictionary:dict wantChecksum:YES];

	NSData *data=[fh remainingFileContents];

//	if(~crc!=[[dict objectForKey:@"ZipCRC32"] unsignedIntValue])
/*	if(![dict objectForKey:XADIsResourceForkKey])
	{
		NSMutableString *name=[NSMutableString stringWithString:[[dict objectForKey:XADFileNameKey] string]];
		[name replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0,[name length])];
		[data writeToFile:name atomically:YES];
	}*/

	NSLog(@"Checksum: %@, Length: %d",[fh hasChecksum]?[fh isChecksumCorrect]?@"Correct":@"Incorrect":@"Unknown",[data length]);

	NSLog(@"%@",[data subdataWithRange:NSMakeRange(0,[data length]<256?[data length]:256)]);

	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];
	NSString *subname=[[dict objectForKey:XADFileNameKey] string];
	NSString *ext=[[subname pathExtension] lowercaseString];
	if(([ext isEqual:@"sit"]||[ext isEqual:@"cpt"])&&!(rsrc&&[rsrc boolValue]))
	{
		NSMutableString *name=[NSMutableString stringWithString:[[dict objectForKey:XADFileNameKey] string]];
		[name replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0,[name length])];
		[data writeToFile:name atomically:YES];

		[fh seekToFileOffset:0];

//@try {
		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:fh name:subname];

		NSLog(@"----------- Parsing sub-archive %@ -----------",subname);

		[parser setDelegate:[[TestDelegate new] autorelease]];
		[parser parse];

		NSLog(@"----------- Finished sub-archive %@ -----------",subname);
//} @catch(id e) {
//	NSLog(@"Failed to parse sub archive %@ due to exception: %@",subname,e);
//}
	}
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

		[parser setDelegate:[[TestDelegate new] autorelease]];
		[parser setPassword:@"test"];
//		[parser setPassword:@"www.joomla.com.tr"];

		[parser parse];

		[pool release];
	}
	return 0;
}
