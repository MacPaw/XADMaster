#import "XADPath.h"
#import "XADPlatform.h"

static BOOL HasDotPaths(NSArray *array);
static void StripDotPaths(NSMutableArray *components);

@implementation XADPath

-(id)init
{
	if((self=[super init]))
	{
		components=[[NSArray array] retain];
		source=nil;
	}
	return self;
}

-(id)initWithComponents:(NSArray *)pathcomponents
{
	if((self=[super init]))
	{
		if(HasDotPaths(pathcomponents))
		{
			NSMutableArray *tmp=[NSMutableArray arrayWithArray:pathcomponents];
			StripDotPaths(tmp);
			components=[tmp copy];
		}
		else
		{
			components=[pathcomponents retain];
		}

		source=nil;

		NSEnumerator *enumerator=[components objectEnumerator];
		XADString *string;
		while((string=[enumerator nextObject]))
		{
			XADStringSource *othersource=[string source];
			if(othersource)
			{
				if(source)
				{
					if(othersource!=source)
					[NSException raise:NSInvalidArgumentException format:@"Attempted to use XADStrings with different string sources in XADPath"];
				}
				else source=[othersource retain];
			}
		}

	}
	return self;
}

-(id)initWithString:(NSString *)pathstring
{
	if((self=[super init]))
	{
		NSArray *stringcomps=[pathstring pathComponents];
		int count=[stringcomps count];
		if(count>1&&[[stringcomps lastObject] isEqual:@"/"]) count--; // ignore ending slashes, just like NSString does

		NSMutableArray *array=[NSMutableArray arrayWithCapacity:count];
		for(int i=0;i<count;i++)
		{
			[array addObject:[XADString XADStringWithString:[stringcomps objectAtIndex:i]]];
		}

		StripDotPaths(array);
		components=[array copy];

		source=nil;
	}
	return self;
}

static inline BOOL IsSeparator(char c,const char *separators)
{
	while(*separators)
	{
		if(c==*separators) return YES;
		separators++;
	}
	return NO;
}

-(id)initWithBytes:(const char *)bytes length:(int)length
encodingName:(NSString *)encoding separators:(const char *)separators
{
	return [self initWithBytes:bytes length:length encodingName:encoding separators:separators source:nil];
}

-(id)initWithBytes:(const char *)bytes length:(int)length
separators:(const char *)separators source:(XADStringSource *)stringsource
{
	return [self initWithBytes:bytes length:length encodingName:nil separators:separators source:stringsource];
}

-(id)initWithBytes:(const char *)bytes length:(int)length encodingName:(NSString *)encoding
separators:(const char *)separators source:(XADStringSource *)stringsource
{
	if((self=[super init]))
	{
		NSMutableArray *array=[NSMutableArray array];

		source=nil;

		if(length>0)
		{
			// Check for an absolute path, and add a / as the first entry for these.
			if(IsSeparator(bytes[0],separators)) [array addObject:[XADString XADStringWithString:@"/"]];

			// Iterate through the string.
			int i=0;
			while(i<length)
			{
				// Skip separator characters.
				while(i<length&&IsSeparator(bytes[i],separators)) i++;
				if(i>=length) break;

				// Remember the start of the next component, and find the end.
				int start=i;
				while(i<length)
				{
					// If we encounter a separator, first check if it looks like
					// the current component string can be decoded. This is to avoid
					// spurious splits in encodings like Shift_JIS.
					if(IsSeparator(bytes[i],separators))
					{
						NSString *currencoding;
						if(encoding) currencoding=encoding;
						else currencoding=[stringsource encodingName];

						if([XADString canDecodeBytes:&bytes[start] length:i-start
						encodingName:currencoding]) break;
					}
					i++;
				}

				NSData *data=[NSData dataWithBytes:&bytes[start] length:i-start];

				if(encoding)
				{
					XADString *string=[[[XADString alloc] initWithData:data encodingName:encoding] autorelease];
					[array addObject:string];
				}
				else
				{
					XADString *string=[[[XADString alloc] initWithData:data source:stringsource] autorelease];
					[array addObject:string];

					if(!source)
					{
						if([string source]) source=[stringsource retain];
					}
				}
			}
		}

		StripDotPaths(array);
		components=[array copy];
	}
	return self;
}

-(void)dealloc
{
	[components release];
	[source release];
	[super dealloc];
}




-(XADString *)lastPathComponent
{
	if([components count]) return [components lastObject];
	else return [XADString XADStringWithString:@""];
}

-(XADString *)firstPathComponent
{
	if([components count]) return [components objectAtIndex:0];
	else return [XADString XADStringWithString:@""];
}

-(XADPath *)pathByDeletingLastPathComponent
{
	int count=[components count];
	if(count) return [[[XADPath alloc] initWithComponents:[components subarrayWithRange:NSMakeRange(0,count-1)]] autorelease];
	else return [[XADPath new] autorelease];
}

-(XADPath *)pathByDeletingFirstPathComponent
{
	int count=[components count];
	if(count) return [[[XADPath alloc] initWithComponents:[components subarrayWithRange:NSMakeRange(1,count-1)]] autorelease];
	else return [[XADPath new] autorelease];
}

-(XADPath *)pathByAppendingPathComponent:(XADString *)component
{
	return [[[XADPath alloc] initWithComponents:[components arrayByAddingObject:component]] autorelease];
}

-(XADPath *)pathByAppendingPath:(XADPath *)path
{
	return [[[XADPath alloc] initWithComponents:[components arrayByAddingObjectsFromArray:path->components]] autorelease];
}

-(XADPath *)safePath
{
	int count=[components count];
	int first=0;

	// Drop "/" and ".." components at the start of the path.
	// "." and ".." components have already been stripped earlier.
	while(first<count)
	{
		NSString *component=[components objectAtIndex:first];
		if(![component isEqual:@".."]&&![component isEqual:@"/"]) break;
		first++;
	}

	if(first==0) return self;
	else return [[[XADPath alloc] initWithComponents:[components subarrayWithRange:NSMakeRange(first,count-first)]] autorelease];
}



-(BOOL)isAbsolute
{
	return [components count]>0&&[[components objectAtIndex:0] isEqual:@"/"];
}

-(BOOL)isEmpty
{
	return [components count]==0;
}

-(BOOL)hasPrefix:(XADPath *)other
{
	int count=[components count];
	int othercount=[other->components count];

	if(othercount>count) return NO;

	for(int i=0;i<othercount;i++)
	{
		if(![[components objectAtIndex:i] isEqual:[other->components objectAtIndex:i]]) return NO;
	}

	return YES;
}



-(NSString *)string
{
	return [self stringWithEncodingName:[source encodingName]];
}

-(NSString *)stringWithEncodingName:(NSString *)encoding
{
	NSMutableString *string=[NSMutableString string];

	int count=[components count];
	if(count==0) return @".";

	int i=0;
	if(count>1&&[[components objectAtIndex:0] isEqual:@"/"]) i++;

	for(;i<count;i++)
	{
		if(i!=0) [string appendString:@"/"];

		NSString *compstring=[[components objectAtIndex:i] stringWithEncodingName:encoding];

		// TODO: Should this method really map / to :?
		if([compstring rangeOfString:@"/"].location==NSNotFound) [string appendString:compstring];
		else
		{
			NSMutableString *newstring=[NSMutableString stringWithString:compstring];
			[newstring replaceOccurrencesOfString:@"/" withString:@":" options:0 range:NSMakeRange(0,[newstring length])];

			[string appendString:newstring];
		}
	}

	return string;
}

-(NSData *)data
{
	NSMutableData *data=[NSMutableData data];

	int count=[components count];
	int i=0;

	if(count>1&&[[components objectAtIndex:0] isEqual:@"/"]) i++;

	for(;i<count;i++)
	{
		if(i!=0) [data appendBytes:"/" length:1];
		// NOTE: Doesn't map '/' to ':'.
		[data appendData:[[components objectAtIndex:i] data]];
	}

	return data;
}

-(NSString *)sanitizedPathString
{
	return [self sanitizedPathStringWithEncodingName:[source encodingName]];
}

-(NSString *)sanitizedPathStringWithEncodingName:(NSString *)encoding
{
	int count=[components count];
	int first=0;

	// Drop "/" at the start of the path.
	if(count && [[components objectAtIndex:0] isEqual:@"/"]) first++;

	if(first==count) return @".";

	NSMutableString *string=[NSMutableString string];
	for(int i=first;i<count;i++)
	{
		if(i!=first) [string appendString:@"/"];

		XADString *component=[components objectAtIndex:i];

		// Replace ".." components with "__Parent__". ".." components in the middle
		// of the path have already been collapsed.
		if([component isEqual:@".."])
		{
			[string appendString:@"__Parent__"];
		}
		else
		{
			NSString *compstring=[component stringWithEncodingName:encoding];
			NSString *sanitized=[XADPlatform sanitizedPathComponent:compstring];
			[string appendString:sanitized];
		}
	}

	return string;
}




-(int)depth
{
	return [components count];
}

-(NSArray *)pathComponents
{
	return components;
}



-(BOOL)encodingIsKnown
{
	if(!source) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(NSString *)encodingName
{
	if(!source) return XADUTF8StringEncodingName; // TODO: what should this really return?
	return [source encodingName];
}

-(float)confidence
{
	if(!source) return 1;
	return [source confidence];
}



-(XADStringSource *)source { return source; }



-(NSString *)description
{
	// TODO: more info?
	return [self string];
}

-(BOOL)isEqual:(id)other
{
	if(![other isKindOfClass:[XADPath class]]) return NO;
	return [components isEqual:((XADPath *)other)->components];
}

-(NSUInteger)hash
{
	int count=[components count];
	if(!count) return 0;
	return [[components lastObject] hash]^count;
}

-(id)copyWithZone:(NSZone *)zone { return [self retain]; } // class is immutable, so just return self




#ifdef __APPLE__
-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	return [self stringWithEncodingName:(NSString *)CFStringConvertEncodingToIANACharSetName(
	CFStringConvertNSStringEncodingToEncoding(encoding))];
}

-(NSString *)sanitizedPathStringWithEncoding:(NSStringEncoding)encoding;
{
	return [self sanitizedPathStringWithEncodingName:(NSString *)CFStringConvertEncodingToIANACharSetName(
	CFStringConvertNSStringEncodingToEncoding(encoding))];
}

-(NSStringEncoding)encoding
{
	if(!source) return NSUTF8StringEncoding; // TODO: what should this really return?
	return [source encoding];
}
#endif

@end



static BOOL HasDotPaths(NSArray *array)
{
	if([array indexOfObject:@"."]!=NSNotFound) return YES;
	if([array indexOfObject:@".."]!=NSNotFound) return YES;
	return NO;
}

static void StripDotPaths(NSMutableArray *components)
{
	// Drop . anywhere in the path
	for(int i=0;i<[components count];)
	{
		XADString *comp=[components objectAtIndex:i];
		if([comp isEqual:@"."]) [components removeObjectAtIndex:i];
		else i++;
	}

	// Drop all .. that can be dropped
	for(int i=1;i<[components count];)
	{
		XADString *comp1=[components objectAtIndex:i-1];
		XADString *comp2=[components objectAtIndex:i];
		if(![comp1 isEqual:@".."]&&[comp2 isEqual:@".."])
		{
			[components removeObjectAtIndex:i];
			[components removeObjectAtIndex:i-1];
			if(i>1) i--;
		}
		else i++;
	}
}
