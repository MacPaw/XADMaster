#import "XADStuffItXParser.h"
#import "XADStuffItXBlockHandle.h"
#import "XADPPMdHandles.h"
#import "XADStuffItXCyanideHandle.h"
//#import "XADStuffItXDarkhorseHandle.h"
#import "XADCRCHandle.h"
#import "StuffItXUtilities.h"

@implementation XADStuffItXParser

+(int)requiredHeaderSize { return 10; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;

	return bytes[0]=='S'&&bytes[1]=='t'&&bytes[2]=='u'&&bytes[3]=='f'&&bytes[4]=='f'
	&&bytes[5]=='I'&&bytes[6]=='t'&&(bytes[7]=='!'||bytes[7]=='?');
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:10];

	for(;;)
	{
		int something=[fh readBitsLE:1];
		int element=ReadSitxP2(fh);
		NSLog(@"start element: %d %d",something,element);
		uint64_t head[9];

		for(;;)
		{
			int type=ReadSitxP2(fh);
			if(type==0) break;
			uint64_t value=ReadSitxP2(fh);
			if(type<9) head[type]=value;

			NSLog(@"attrib: %d %qu",type,value);
		}

		for(;;)
		{
			int type=ReadSitxP2(fh);
			if(type==0) break;
			if(type==4)
			{
				uint64_t value1=ReadSitxP2(fh);
				uint64_t value2=ReadSitxP2(fh);
				NSLog(@"alglist: %d %qu %qu",type,value1,value2);
			}
			else
			{
				uint64_t value=ReadSitxP2(fh);
				NSLog(@"alglist: %d %qu",type,value);
			}
		}

		switch(element)
		{
			case 0: // end
				NSLog(@"end");
				goto out;
			break;

			case 1: // data
			{
				NSLog(@"data");

				[fh flushReadBits];
				XADStuffItXBlockHandle *bh=[[[XADStuffItXBlockHandle alloc] initWithHandle:fh] autorelease];
				int allocsize=1<<[bh readUInt8];
				int order=[bh readUInt8];
				NSLog(@"%d %d",order,allocsize);
				XADStuffItXBrimstoneHandle *ph=[[[XADStuffItXBrimstoneHandle alloc] initWithHandle:bh
				maxOrder:order subAllocSize:allocsize] autorelease];
				NSData *data=[ph remainingFileContents];
				NSLog(@"%d %@",[data length],[data subdataWithRange:NSMakeRange(0,1383)]);
/*				for(;;)
				{
					uint64_t len=ReadSitxP2(fh);
					if(!len) break;
					[fh skipBytes:len];
				}*/
				[fh flushReadBits];
				for(;;)
				{
					uint64_t len=ReadSitxP2(fh);
					if(!len) break;
					[fh skipBytes:len];
				}
			}
			break;

			case 2: // file
				NSLog(@"file");
			break;

			case 3: // fork
			{
				uint64_t something=ReadSitxP2(fh);
				NSLog(@"fork: %qu",something);
			}
			break;

			case 4: // directory
				NSLog(@"directory");
			break;

			case 5: // catalog
			{
				NSLog(@"catalog");
				[fh flushReadBits];
/*				XADStuffItXBlockHandle *bh=[[[XADStuffItXBlockHandle alloc] initWithHandle:fh] autorelease];
				int allocsize=1<<[bh readUInt8];
				int order=[bh readUInt8];
				NSLog(@"%d %d",order,allocsize);
				XADStuffItXBrimstoneHandle *ph=[[[XADStuffItXBrimstoneHandle alloc] initWithHandle:bh
				maxOrder:order subAllocSize:allocsize] autorelease];
				NSLog(@"%@",[ph remainingFileContents]);*/
				for(;;)
				{
					uint64_t len=ReadSitxP2(fh);
					if(!len) break;
					[fh skipBytes:len];
				}
				[fh flushReadBits];
				for(;;)
				{
					uint64_t len=ReadSitxP2(fh);
					if(!len) break;
					[fh skipBytes:len];
				}
			}
			break;

			case 6: // clue
				[fh skipBytes:head[5]];
			break;

			case 7: // root
			{
				uint64_t something=ReadSitxP2(fh);
				NSLog(@"root: %qu",something);
			}
			break;

			case 8: // boundary
				NSLog(@"boundary");
			break;

			case 9: // ?
				NSLog(@"?");
			break;

			// case 10: // receipt
			// break;

			// case 11: // index
			// break;

			// case 12: // locator
			// break;

			// case 13: // id
			// break;

			// case 14: // link
			// break;

			// case 15: // segment_index
			// break;

			default:
				if(element>10)
				{
					[fh flushReadBits];
					for(;;)
					{
						uint64_t len=ReadSitxP2(fh);
						if(!len) break;
						[fh skipBytes:len];
					}
					[fh flushReadBits];
					for(;;)
					{
						uint64_t len=ReadSitxP2(fh);
						if(!len) break;
						[fh skipBytes:len];
					}
				}
				else 
				{
					NSLog(@"unknown element");
					goto out;
				}
			break;
		}

		[fh flushReadBits];
		NSLog(@"%qu",[fh offsetInFile]);
	}
	out:0;

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADStringWithString:@"Test"],XADFileNameKey,
		[self XADStringWithString:@"Cyanide"],XADCompressionNameKey,
		[NSNumber numberWithUnsignedInt:0xc0288c62],@"StuffItXCRC32",
	nil];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	[handle seekToFileOffset:133];

	handle=[[[XADStuffItXBlockHandle alloc] initWithHandle:handle] autorelease];

	handle=[[[XADStuffItXCyanideHandle alloc] initWithHandle:handle] autorelease];

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:387633
	correctCRC:[[dict objectForKey:@"StuffItXCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName { return @"StuffIt X"; }

@end
