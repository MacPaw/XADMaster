#import "PDFParser.h"

#import "../XADRegex.h"
#import "../CSFileHandle.h"



NSString *PDFWrongMagicException=@"PDFWrongMagicException";
NSString *PDFInvalidFormatException=@"PDFInvalidFormatException";
NSString *PDFParserException=@"PDFParserException";



static int HexDigit(uint8_t c);
static BOOL IsHexDigit(uint8_t c);
static BOOL IsWhiteSpace(uint8_t c);


@implementation PDFParser

+(PDFParser *)parserWithHandle:(CSHandle *)handle
{
	return [[[PDFParser alloc] initWithHandle:handle] autorelease];
}

+(PDFParser *)parserForPath:(NSString *)path
{
	CSFileHandle *handle=[CSFileHandle fileHandleForReadingAtPath:path];
	return [[[PDFParser alloc] initWithHandle:handle] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super init])
	{
		mainhandle=[handle retain];
		fh=[handle retain];

		objdict=[[NSMutableDictionary dictionary] retain];
		unresolved=[[NSMutableArray array] retain];

		encryption=nil;

		@try
		{
			if([fh readUInt8]!='%'||[fh readUInt8]!='P'||[fh readUInt8]!='D'||[fh readUInt8]!='F'||[fh readUInt8]!='-')
			[NSException raise:PDFWrongMagicException format:@"Not a PDF file."];
		}
		@catch(id e) { [self release]; @throw; }
	}
	return self;
}

-(void)dealloc
{
	[mainhandle release];
	[fh release];
	[objdict release];
	[unresolved release];
	[encryption release];
	[super dealloc];
}



-(BOOL)isEncrypted
{
	return encryption?YES:NO;
}

-(BOOL)needsPassword
{
	if(!encryption) return NO;
	return [encryption needsPassword];
}

-(BOOL)setPassword:(NSString *)password
{
	return [encryption setPassword:password];
}



-(NSDictionary *)objectDictionary { return objdict; }

-(NSDictionary *)trailerDictionary { return trailerdict; }

-(NSDictionary *)rootDictionary { return [trailerdict objectForKey:@"Root"]; }

-(NSDictionary *)infoDictionary { return [trailerdict objectForKey:@"Info"]; }

-(NSData *)permanentID
{
	NSArray *ids=[trailerdict objectForKey:@"ID"];
	if(!ids) return nil;
	return [[ids objectAtIndex:0] rawData];
}

-(NSData *)currentID
{
	NSArray *ids=[trailerdict objectForKey:@"ID"];
	if(!ids) return nil;
	return [[ids objectAtIndex:1] rawData];
}

-(NSDictionary *)pagesRoot
{
	return [[self rootDictionary] objectForKey:@"Pages"];
}

-(PDFEncryptionHandler *)encryptionHandler { return encryption; }




-(void)setHandle:(CSHandle *)newhandle
{
	[fh autorelease];
	fh=[newhandle retain];
}

-(void)restoreDefaultHandle
{
	[self setHandle:mainhandle];
}




-(void)parse
{
	[fh seekToEndOfFile];
	[fh skipBytes:-48];
	NSData *enddata=[fh readDataOfLength:48];
	NSString *end=[[[NSString alloc] initWithData:enddata encoding:NSISOLatin1StringEncoding] autorelease];

	NSString *startxref=[[end substringsCapturedByPattern:@"startxref[\n\r ]+([0-9]+)[\n\r ]+%%EOF"] objectAtIndex:1];
	if(!startxref) [NSException raise:PDFInvalidFormatException format:@"Missing PDF trailer."];
	[fh seekToFileOffset:[startxref intValue]];

	// Read newest xrefs and trailer
	trailerdict=[[self parsePDFXref] retain];

	// Read older xrefs, ignore their trailers
	NSNumber *prev=[trailerdict objectForKey:@"Prev"];
	while(prev)
	{
		[fh seekToFileOffset:[prev intValue]];
		NSDictionary *oldtrailer=[self parsePDFXref];
		prev=[oldtrailer objectForKey:@"Prev"];
	}

	[self resolveIndirectObjects];

	if([trailerdict objectForKey:@"Encrypt"])
	{
		[encryption release];
		encryption=[[PDFEncryptionHandler alloc] initWithParser:self];
	}
}

-(NSDictionary *)parsePDFXref
{
	int c=[fh readUInt8];
	[fh skipBytes:-1];

	if(c=='x') return [self parsePDFXrefTable];
	else return [self parsePDFXrefStream];
}

-(NSDictionary *)parsePDFXrefTable
{
	int c;

	if([fh readUInt8]!='x'||[fh readUInt8]!='r'||[fh readUInt8]!='e'||[fh readUInt8]!='f')
	[self _raiseParserException:@"Error parsing xref"];

	do { c=[fh readUInt8]; } while(IsWhiteSpace(c));
	[fh skipBytes:-1];

	for(;;)
	{
		c=[fh readUInt8];
		if(c=='t')
		{
			if([fh readUInt8]!='r'||[fh readUInt8]!='a'||[fh readUInt8]!='i'
			||[fh readUInt8]!='l'||[fh readUInt8]!='e'||[fh readUInt8]!='r')  [self _raiseParserException:@"Error parsing xref trailer"];

			id trailer=[self parsePDFTypeWithParent:nil];
			if([trailer isKindOfClass:[NSDictionary class]]) return trailer;
			else [self _raiseParserException:@"Error parsing xref trailer"];
		}
		else if(c<'0'||c>'9') [self _raiseParserException:@"Error parsing xref table"];
		else [fh skipBytes:-1];

		int first=[self parseSimpleInteger];
		int num=[self parseSimpleInteger];

		do { c=[fh readUInt8]; } while(IsWhiteSpace(c));
		[fh skipBytes:-1];

		for(int n=first;n<first+num;n++)
		{
			char entry[21];
			[fh readBytes:20 toBuffer:entry];

			if(entry[17]!='n') continue;

			off_t objoffs=atoll(entry);
			int objgen=atol(entry+11);

			if(!objoffs) continue; // Kludge to handle broken Apple PDF files.

			off_t curroffs=[fh offsetInFile];
			[fh seekToFileOffset:objoffs];
			id obj=[self parsePDFObject];
			[fh seekToFileOffset:curroffs];

			PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:n generation:objgen];
			if(obj && ![objdict objectForKey:ref]) [objdict setObject:obj forKey:ref];
		}
	}
	return nil;
}

-(NSDictionary *)parsePDFXrefStream
{
	PDFStream *stream=[self parsePDFObject];

	if(![stream isKindOfClass:[PDFStream class]]) [self _raiseParserException:@"Error parsing xref stream"];

	NSDictionary *dict=[stream dictionary];
	if(![[dict objectForKey:@"Type"] isEqual:@"XRef"]) [self _raiseParserException:@"Error parsing xref stream"];

	NSArray *w=[dict objectForKey:@"W"];
	if(!w) [self _raiseParserException:@"Error parsing xref stream"];
	if(![w isKindOfClass:[NSArray class]]) [self _raiseParserException:@"Error parsing xref stream"];
	if([w count]!=3) [self _raiseParserException:@"Error parsing xref stream"];

	int typesize=[[w objectAtIndex:0] intValue];
	int value1size=[[w objectAtIndex:1] intValue];
	int value2size=[[w objectAtIndex:2] intValue];

	NSArray *index=[dict objectForKey:@"Index"];
	if(index)
	{
		if(![index isKindOfClass:[NSArray class]]) [self _raiseParserException:@"Error parsing xref stream"];
	}
	else
	{
		NSNumber *size=[dict objectForKey:@"Size"];
		if(!size) [self _raiseParserException:@"Error parsing xref stream"];
		if(![size isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error parsing xref stream"];

		index=[NSArray arrayWithObjects:[NSNumber numberWithInt:0],size,nil];
	}

	CSHandle *handle=[stream handle];
	if(!handle) [self _raiseParserException:@"Error decoding xref stream"];

	for(int i=0;i<[index count];i+=2)
	{
		NSNumber *firstnum=[index objectAtIndex:i];
		NSNumber *numnum=[index objectAtIndex:i+1];

		if(![firstnum isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding xref stream"];
		if(![numnum isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding xref stream"];

		int first=[firstnum intValue];
		int num=[numnum intValue];

		for(int n=first;n<first+num;n++)
		{
			int type=[self parseIntegerOfSize:typesize fromHandle:handle default:1];
			uint64_t value1=[self parseIntegerOfSize:value1size fromHandle:handle default:0];
			uint64_t value2=[self parseIntegerOfSize:value2size fromHandle:handle default:0];

			if(type!=1) continue;
			if(!value1) continue; // Kludge to handle broken Apple PDF files. TODO: Is this actually needed here?

			off_t curroffs=[fh offsetInFile];
			[fh seekToFileOffset:value1];
			id obj=[self parsePDFObject];
			[fh seekToFileOffset:curroffs];

			PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:n generation:value2];
			if(obj && ![objdict objectForKey:ref]) [objdict setObject:obj forKey:ref];

			if([obj isKindOfClass:[PDFStream class]])
			{
				if([[[obj dictionary] objectForKey:@"Type"] isEqual:@"ObjStm"])
				{
					[self parsePDFCompressedObjectStream:obj];
				}
			}
		}

	}

	return dict;
}

-(uint64_t)parseIntegerOfSize:(int)size fromHandle:(CSHandle *)handle default:(uint64_t)def
{
	if(!size) return def;

	uint64_t res=0;
	for(int i=0;i<size;i++) res=(res<<8)|[handle readUInt8];

	return res;
}

-(void)parsePDFCompressedObjectStream:(PDFStream *)stream
{
	NSDictionary *dict=[stream dictionary];

	NSNumber *n=[dict objectForKey:@"N"];
	if(!n) [self _raiseParserException:@"Error decoding compressed object stream"];
	if(![n isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding compressed object stream"];

	NSNumber *first=[dict objectForKey:@"First"];
	if(!first) [self _raiseParserException:@"Error decoding compressed object stream"];
	if(![first isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding compressed object stream"];

	CSHandle *handle=[stream handle];
	if(!handle) [self _raiseParserException:@"Error decoding compressed object stream"];

	[self setHandle:handle];

	int num=[n intValue];
	off_t startoffset=[first longLongValue];

	int objnums[num];
	off_t offsets[num];

	for(int i=0;i<num;i++)
	{
		objnums[i]=[self parseSimpleInteger];
		offsets[i]=[self parseSimpleInteger];
	}

	for(int i=0;i<num;i++)
	{
		[fh seekToFileOffset:offsets[i]+startoffset];

		PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:objnums[i] generation:0];
		id value=[self parsePDFTypeWithParent:ref];

		if(value && ![objdict objectForKey:ref]) [objdict setObject:value forKey:ref];
	}

	[self restoreDefaultHandle];
}




-(id)parsePDFObject
{
	int c;

	int objnum=[self parseSimpleInteger];
	int objgen=[self parseSimpleInteger];
	PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:objnum generation:objgen];

	do { c=[fh readUInt8]; } while(IsWhiteSpace(c));

	if(c!='o'||[fh readUInt8]!='b'||[fh readUInt8]!='j')
	[self _raiseParserException:@"Error parsing object"];

	id value=[self parsePDFTypeWithParent:ref];

	do { c=[fh readUInt8]; } while(IsWhiteSpace(c));

	switch(c)
	{
		case 's':
			if([fh readUInt8]!='t'||[fh readUInt8]!='r'||[fh readUInt8]!='e'
			||[fh readUInt8]!='a'||[fh readUInt8]!='m') [self _raiseParserException:@"Error parsing stream object"];

			c=[fh readUInt8];
			if(c=='\r') c=[fh readUInt8];
			if(c!='\n') [self _raiseParserException:@"Error parsing stream object"];

			return [[[PDFStream alloc] initWithDictionary:value fileHandle:fh
			reference:ref parser:self] autorelease];
		break;

		case 'e':
			if([fh readUInt8]!='n'||[fh readUInt8]!='d'||[fh readUInt8]!='o'
			||[fh readUInt8]!='b'||[fh readUInt8]!='j') [self _raiseParserException:@"Error parsing object"];
			return value;
		break;

		default: [self _raiseParserException:@"Error parsing obj"];
	}
	return nil; // shut up, gcc
}

-(uint64_t)parseSimpleInteger
{
	uint64_t val=0;
	int c;

	do { c=[fh readUInt8]; } while(IsWhiteSpace(c));

	for(;;)
	{
		if(!isdigit(c))
		{
			[fh skipBytes:-1];
			return val;
		}
		val=val*10+(c-'0');
		c=[fh readUInt8];
	}
 }




-(id)parsePDFTypeWithParent:(PDFObjectReference *)parent
{
	int c;
	do { c=[fh readUInt8]; } while(IsWhiteSpace(c));

	switch(c)
	{
		case 'n': return [self parsePDFNull];

		case 't': case 'f': return [self parsePDFBoolStartingWith:c];

		case '0': case '1': case '2': case '3': case '4': case '5':
		case '6': case '7': case '8': case '9': case '-': case '.':
			return [self parsePDFNumberStartingWith:c];

		case '/': return [self parsePDFWord];

		case '(': return [self parsePDFStringWithParent:parent];

		case '[': return [self parsePDFArrayWithParent:parent];

		case '<':
			c=[fh readUInt8];
			switch(c)
			{
				case '0': case '1': case '2': case '3': case '4':
				case '5': case '6': case '7': case '8': case '9':
				case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
				case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
					return [self parsePDFHexStringStartingWith:c parent:parent];

				case '<': return [self parsePDFDictionaryWithParent:parent];
				default: return nil;
			}

		default: [fh skipBytes:-1]; return nil;
	}
}

-(NSNull *)parsePDFNull
{
	char rest[3];
	[fh readBytes:3 toBuffer:rest];
	if(rest[0]=='u'&&rest[1]=='l'&&rest[2]=='l') return [NSNull null];
	else [self _raiseParserException:@"Error parsing null value"];
	return nil; // shut up, gcc
}

-(NSNumber *)parsePDFBoolStartingWith:(int)c
{
	if(c=='t')
	{
		char rest[3];
		[fh readBytes:3 toBuffer:rest];
		if(rest[0]=='r'&&rest[1]=='u'&&rest[2]=='e') return [NSNumber numberWithBool:YES];
		else [self _raiseParserException:@"Error parsing boolean true value"];
	}
	else
	{
		char rest[4];
		[fh readBytes:4 toBuffer:rest];
		if(rest[0]=='a'&&rest[1]=='l'&&rest[2]=='s'&&rest[3]=='e') return [NSNumber numberWithBool:NO];
		else [self _raiseParserException:@"Error parsing boolean false value"];
	}
	return nil; // shut up, gcc
}

-(NSNumber *)parsePDFNumberStartingWith:(int)c
{
	char str[32]={c};
	int i;

	for(i=1;i<sizeof(str);i++)
	{
		int c=[fh readUInt8];
		if(!isdigit(c)&&c!='.')
		{
			[fh skipBytes:-1];
			break;
		}
		str[i]=c;
	}

	if(i==sizeof(str)) [self _raiseParserException:@"Error parsing numeric value"];
	str[i]=0;

	if(strchr(str,'.')) return [NSNumber numberWithDouble:atof(str)];
	else return [NSNumber numberWithLongLong:atoll(str)];
 }

-(NSString *)parsePDFWord
{
	NSMutableString *str=[NSMutableString string];

	for(;;)
	{
		int c=[fh readUInt8];
		if(c=='#')
		{
			int c1=[fh readUInt8];
			int c2=[fh readUInt8];
			if(!IsHexDigit(c1)||!IsHexDigit(c2)) [self _raiseParserException:@"Error parsing hex escape in name"];

			[str appendFormat:@"%c",HexDigit(c1)*16+HexDigit(c2)];
		}
		else if(c<0x21||c>0x7e||c=='%'||c=='('||c==')'||c=='<'||c=='>'||c=='['||c==']'
		||c=='{'||c=='}'||c=='/')
		{
			[fh skipBytes:-1];
			return str;
		}
		else [str appendFormat:@"%c",c];
	}
}

-(PDFString *)parsePDFStringWithParent:(PDFObjectReference *)parent
{
	NSMutableData *data=[NSMutableData data];
	int nesting=1;

	for(;;)
	{
		int c=[fh readUInt8];
		uint8_t b=0;

		switch(c)
		{
			default: b=c; break;
			case '(': nesting++; b='('; break;
			case ')':
				if(--nesting==0) return [[[PDFString alloc] initWithData:data parent:parent parser:self] autorelease];
				else b=')';
			break;
			case '\\':
				c=[fh readUInt8];
				switch(c)
				{
					default: b=c; break;
					case '\n': continue; // ignore newlines
					case '\r': // ignore carriage return
						c=[fh readUInt8];
						if(c=='\n') continue; // ignore CRLF
						else b=c;
					break;
					case 'n': b='\n'; break;
					case 'r': b='\r'; break;
					case 't': b='\t'; break;
					case 'b': b='\b'; break;
					case 'f': b='\f'; break;
					case '0': case '1': case '2': case '3':
					case '4': case '5': case '6': case '7':
						b=c-'0';
						c=[fh readUInt8];
						if(c>='0'&&c<='7')
						{
							b=b*8+c-'0';
							c=[fh readUInt8];
							if(c>='0'&&c<='7')
							{
								b=b*8+c-'0';
							}
							else [fh skipBytes:-1];
						}
						else [fh skipBytes:-1];
					break;
				}
			break;
		}
		[data appendBytes:&b length:1];
	}
}

-(PDFString *)parsePDFHexStringStartingWith:(int)c parent:(PDFObjectReference *)parent
{
	NSMutableData *data=[NSMutableData data];

	[fh skipBytes:-1];

	for(;;)
	{
		int c1;
		do { c1=[fh readUInt8]; }
		while(IsWhiteSpace(c1));
		if(c1=='>') return [[[PDFString alloc] initWithData:data parent:parent parser:self] autorelease];
		if(!IsHexDigit(c1)) [self _raiseParserException:@"Error parsing hex data value"];

		int c2;
		do { c2=[fh readUInt8]; }
		while(IsWhiteSpace(c2));
		if(!IsHexDigit(c2)&&c2!='>') [self _raiseParserException:@"Error parsing hex data value"];

		uint8_t byte=HexDigit(c1)*16+HexDigit(c2);
		[data appendBytes:&byte length:1];

		if(c2=='>') return [[[PDFString alloc] initWithData:data parent:parent parser:self] autorelease];
	}
}

-(NSArray *)parsePDFArrayWithParent:(PDFObjectReference *)parent
{
	NSMutableArray *array=[NSMutableArray array];

	for(;;)
	{
		id value=[self parsePDFTypeWithParent:parent];
		if(!value)
		{
			int c=[fh readUInt8];
			if(c==']')
			{
				[unresolved addObject:array];
				return array;
			}
			else if(c=='R')
			{
				id num=[array objectAtIndex:[array count]-2];
				id gen=[array objectAtIndex:[array count]-1];
				if([num isKindOfClass:[NSNumber class]]&&[gen isKindOfClass:[NSNumber class]])
				{
					PDFObjectReference *obj=[PDFObjectReference referenceWithNumberObject:num generationObject:gen];
					[array removeLastObject];
					[array removeLastObject];
					[array addObject:obj];
				}
				else [self _raiseParserException:@"Error parsing indirect object in array"];
			}
			else [self _raiseParserException:@"Error parsing array"];
		}
		else [array addObject:value];
	}
}

-(NSDictionary *)parsePDFDictionaryWithParent:(PDFObjectReference *)parent
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	id prev_key=nil,prev_value=nil;

	for(;;)
	{
		id key=[self parsePDFTypeWithParent:nil];
		if(!key)
		{
			if([fh readUInt8]=='>'&&[fh readUInt8]=='>')
			{
				[unresolved addObject:dict];
				return dict;
			}
			else [self _raiseParserException:@"Error parsing dictionary"];
		}
		else if([key isKindOfClass:[NSString class]])
		{
			id value=[self parsePDFTypeWithParent:parent];
			if(!value) [self _raiseParserException:@"Error parsing dictionary value"];
			[dict setObject:value forKey:key];
			prev_key=key;
			prev_value=value;
		}
		else if([key isKindOfClass:[NSNumber class]])
		{
			int c;
			do { c=[fh readUInt8]; } while(IsWhiteSpace(c));
			if(c=='R')
			{
				[dict setObject:[PDFObjectReference referenceWithNumberObject:prev_value generationObject:key] forKey:prev_key];
				prev_key=nil;
				prev_value=nil;
			}
			else [self _raiseParserException:@"Error parsing indirect object in dictionary"];
		}
		else [self _raiseParserException:@"Error parsing dictionary key"];
	}
}

-(void)resolveIndirectObjects
{
	NSEnumerator *enumerator=[unresolved objectEnumerator];
	id obj;
	while(obj=[enumerator nextObject])
	{
		if([obj isKindOfClass:[NSDictionary class]])
		{
			NSMutableDictionary *dict=obj;
			NSEnumerator *keyenum=[[dict allKeys] objectEnumerator];
			NSString *key;
			while(key=[keyenum nextObject])
			{
				id value=[dict objectForKey:key];
				if([value isKindOfClass:[PDFObjectReference class]])
				{
					id realobj=[objdict objectForKey:value];
					if(realobj) [dict setObject:realobj forKey:key];
				}
			}
		}
		else if([obj isKindOfClass:[NSArray class]])
		{
			NSMutableArray *array=obj;
			int count=[array count];
			for(int i=0;i<count;i++)
			{
				id value=[array objectAtIndex:i];
				if([value isKindOfClass:[PDFObjectReference class]])
				{
					id realobj=[objdict objectForKey:value];
					if(realobj) [array replaceObjectAtIndex:i withObject:realobj];
				}
			}
		}
	}
}

-(void)_raiseParserException:(NSString *)error
{
	NSData *start;

	off_t offs=[fh offsetInFile];
	if(offs<100)
	{
		[fh seekToFileOffset:0];
		start=[fh readDataOfLength:offs];
	}
	else
	{
		[fh skipBytes:-100];
		start=[fh readDataOfLength:100];
	}

	int length=[start length];
	const uint8_t *bytes=[start bytes];
	int skip=0;
	for(int i=0;i<length;i++) if(bytes[i]=='\n'||bytes[i]=='\r') skip=i+1;
	NSString *startstr=[[[NSString alloc] initWithBytes:bytes+skip length:length-skip encoding:NSISOLatin1StringEncoding] autorelease];

	NSData *end=[fh readDataOfLengthAtMost:100];
	length=[end length];
	bytes=[end bytes];
	for(int i=0;i<length;i++) if(bytes[i]=='\n'||bytes[i]=='\r') { length=i; break; }
	NSString *endstr=[[[NSString alloc] initWithBytes:bytes length:length encoding:NSISOLatin1StringEncoding] autorelease];

	[NSException raise:PDFParserException format:@"%@: \"%@%C%@\"",error,startstr,0x25bc,endstr];
}

@end



@implementation PDFString

-(id)initWithData:(NSData *)bytes parent:(PDFObjectReference *)parent parser:(PDFParser *)owner
{
	if(self=[super init])
	{
		data=[bytes retain];
		ref=[parent retain];
		parser=owner;
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[ref release];
	[super dealloc];
}

-(NSData *)rawData { return data; }

-(PDFObjectReference *)reference { return ref; }

-(NSData *)data
{
	PDFEncryptionHandler *encryption=[parser encryptionHandler];
	if(encryption) return [encryption decryptString:self];
	else return data;
}

-(NSString *)string
{
	NSData *characters=[self data];
	int length=[characters length];
	const unsigned char *bytes=[characters bytes];

	if(length>=2&&bytes[0]==0xfe&&bytes[1]==0xff)
	{
		NSMutableString *string=[NSMutableString stringWithCapacity:length/2-1];

		for(int offset=2;offset<length;offset+=2)
		{
			[string appendFormat:@"%C",CSUInt16BE(&bytes[offset])];
		}

		return string;
	}
	else
	{
		return [[[NSString alloc] initWithData:characters encoding:NSISOLatin1StringEncoding] autorelease];
	}
}

-(BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[PDFString class]]&&[data isEqual:((PDFString *)other)->data];
}

-(unsigned)hash { return [data hash]; }

-(id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] initWithData:data];
}

-(NSString *)description
{
	return [self string];
}

@end




@implementation PDFObjectReference

+(PDFObjectReference *)referenceWithNumber:(int)objnum generation:(int)objgen
{
	return [[[[self class] alloc] initWithNumber:objnum generation:objgen] autorelease];
}

+(PDFObjectReference *)referenceWithNumberObject:(NSNumber *)objnum generationObject:(NSNumber *)objgen
{
	return [[[[self class] alloc] initWithNumber:[objnum intValue] generation:[objgen intValue]] autorelease];
}

-(id)initWithNumber:(int)objnum generation:(int)objgen
{
	if(self=[super init])
	{
		num=objnum;
		gen=objgen;
	}
	return self;
}

-(int)number { return num; }

-(int)generation { return gen; }

-(BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[PDFObjectReference class]]&&((PDFObjectReference *)other)->num==num&&((PDFObjectReference *)other)->gen==gen;
}

-(unsigned)hash { return num^(gen*69069); }

-(id)copyWithZone:(NSZone *)zone { return [[[self class] allocWithZone:zone] initWithNumber:num generation:gen]; }

-(NSString *)description { return [NSString stringWithFormat:@"<Reference to object %d, generation %d>",num,gen]; }

@end



static BOOL IsHexDigit(uint8_t c)
{
	return (c>='0'&&c<='9')||(c>='A'&&c<='F')||(c>='a'&&c<='f');
}

static BOOL IsWhiteSpace(uint8_t c)
{
	return c==' '||c=='\t'||c=='\r'||c=='\n'||c=='\f';
}

static int HexDigit(uint8_t c)
{
	if(c>='0'&&c<='9') return c-'0'; 
	else if(c>='a'&&c<='f') return c-'a'+10; 
	else if(c>='A'&&c<='F') return c-'A'+10;
	else return 0; 
}

