#import "XADSimpleUnarchiver.h"
#import "XADException.h"

@implementation XADSimpleUnarchiver

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path
{
	return nil;
}

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path error:(XADError *)errorptr;
{
	return nil;
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser
{
	if((self=[super init]))
	{
		parser=[archiveparser retain];
		unarchiver=[[XADUnarchiver alloc] initWithArchiveParser:archiveparser];
		subunarchiver=nil;

		delegate=nil;
		shouldstop=NO;

		entries=[NSMutableArray new];
		reasonsforinterest=[NSMutableArray new];
	}

	return self;
}

-(void)dealloc
{
	[parser release];
	[unarchiver release];
	[subunarchiver release];

	[entries release];
	[reasonsforinterest release];

	[super dealloc];
}

-(XADArchiveParser *)archiveParser
{
	if(subunarchiver) return [subunarchiver archiveParser];
	else return parser;
}

-(NSArray *)reasonsForInterest { return reasonsforinterest; }

-(id)delegate { return delegate; }
-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(NSString *)password { return [parser password]; }
-(void)setPassword:(NSString *)password
{
	[parser setPassword:password];
	[[subunarchiver archiveParser] setPassword:password];
}

-(NSString *)destination { return [unarchiver destination]; }
-(void)setDestination:(NSString *)destpath
{
	[unarchiver setDestination:destpath];
	[subunarchiver setDestination:destpath];
}

-(int)createsEnclosingDirectory { return 0; }
-(void)setCreatesEnclosingDirectory:(int)createmode
{
	// TODO: implement
}

-(int)macResourceForkStyle { return [unarchiver macResourceForkStyle]; }
-(void)setMacResourceForkStyle:(int)style
{
	[unarchiver setMacResourceForkStyle:style];
	[subunarchiver setMacResourceForkStyle:style];
}

-(BOOL)preservesPermissions { return [unarchiver preservesPermissions]; }
-(void)setPreserevesPermissions:(BOOL)preserveflag
{
	[unarchiver setPreserevesPermissions:preserveflag];
	[subunarchiver setPreserevesPermissions:preserveflag];
}

-(double)updateInterval { return [unarchiver updateInterval]; }
-(void)setUpdateInterval:(double)interval
{
	[unarchiver setUpdateInterval:interval];
	[subunarchiver setUpdateInterval:interval];
}

-(XADError)parseAndUnarchive
{
	if([entries count]) [NSException raise:NSInternalInconsistencyException format:@"You can not call parseAndUnarchive twice"];

	// Run parser to find archive entries.
	[parser setDelegate:self];
	XADError error=[parser parseWithoutExceptions];
	if(error) return error;

	// Check if we have a single entry, which is an archive.
	if([entries count]==1)
	{
		NSDictionary *entry=[entries objectAtIndex:0];
		NSNumber *archnum=[entry objectForKey:XADIsArchiveKey];
		if(archnum&&[archnum boolValue]) return [self _handleSubArchiveWithEntry:entry];
	}

	// Check if we have two entries, which are data and resource forks
	// of the same archive.
	if([entries count]==2)
	{
		NSDictionary *first=[entries objectAtIndex:0];
		NSDictionary *second=[entries objectAtIndex:1];
		XADPath *name1=[first objectForKey:XADFileNameKey];
		XADPath *name2=[second objectForKey:XADFileNameKey];

		if([name1 isEqual:name2])
		{
			NSNumber *resnum=[first objectForKey:XADIsResourceForkKey];
			NSDictionary *datafork,*resourcefork;
			if(resnum&&[resnum boolValue])
			{
				datafork=second;
				resourcefork=first;
			}
			else
			{
				datafork=second;
				resourcefork=first;
			}

			// TODO: Handle resource forks for archives that require them.
			NSNumber *archnum=[datafork objectForKey:XADIsArchiveKey];
			if(archnum&&[archnum boolValue]) return [self _handleSubArchiveWithEntry:datafork];
		}
	}

	return [self _handleRegularArchive];
}

-(XADError)_handleRegularArchive
{
	NSEnumerator *enumerator;
	NSDictionary *entry;

	// Calculate total size.
	totalsize=0;
	totalprogress=0;
	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		NSNumber *size=[entry objectForKey:XADFileSizeKey];

		// Disable accurate progress calculation if any sizes are unknown.
		if(!size)
		{
			totalsize=-1;
			break;
		}

		totalsize+=[size longLongValue];
	}

	// Run unarchiver on all entries.
	[unarchiver setDelegate:self];
	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		if(totalsize>=0) currsize=[[entry objectForKey:XADFileSizeKey] longLongValue];

		[unarchiver extractEntryWithDictionary:entry];

		if(totalsize>=0) totalprogress+=currsize;
	}

	return XADNoError;
}

-(XADError)_handleSubArchiveWithEntry:(NSDictionary *)entry
{
	XADError error;

	// Create handle for entry.
	CSHandle *handle=[parser handleForEntryWithDictionary:entry
	wantChecksum:YES error:&error];
	if(!handle) return error;

	// Create unarchiver.
	subunarchiver=[unarchiver unarchiverForEntryWithDictionary:entry
	wantChecksum:YES error:&error];
	if(!subunarchiver)
	{
		if(error) return error;
		else return XADSubArchiveError;
	}

	// Disable accurate progress calculation.
	totalsize=-1;

	// Parse sub-archive and automatically unarchive its contents.
	[subunarchiver setDelegate:self];
	error=[subunarchiver parseAndUnarchive];

	return XADNoError;
}

-(BOOL)_shouldStop
{
	if(!delegate) return NO;
	if(shouldstop) return YES;

	return shouldstop=[delegate extractionShouldStopForSimpleUnarchiver:self];
}




-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	[entries addObject:dict];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return [self _shouldStop];
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	[delegate simpleUnarchiverNeedsPassword:self];
}

-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason;
{
	[reasonsforinterest addObject:reason];
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
	[delegate simpleUnarchiverNeedsPassword:self];
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict
{
	if(!delegate) return nil;

	XADString *filename=[dict objectForKey:XADFileNameKey];
	NSString *encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:filename];
	if(!encodingname) return nil;

	// TODO: handle destination!

	return [filename stringWithEncodingName:encodingname];
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	// TODO: handle file collisions
	if(!delegate) return YES;

	return [delegate simpleUnarchiver:self shouldExtractEntryWithDictionary:dict to:path];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[delegate simpleUnarchiver:self willExtractEntryWithDictionary:dict to:path];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	[delegate simpleUnarchiver:self didExtractEntryWithDictionary:dict to:path error:error];
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	if(!delegate) return nil;

	NSString *encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:link];
	if(!encodingname) return nil;

	return [link stringWithEncodingName:encodingname];
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return [self _shouldStop];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileratio estimatedTotalFraction:(double)totalratio
{
	if(!delegate) return;

	if(totalsize>=0)
	{
		off_t fileprogress=fileratio*currsize;
		[delegate simpleUnarchiver:self extractionProgressForEntryWithDictionary:dict
		fileProgress:fileprogress of:currsize
		totalProgress:totalprogress+fileprogress of:totalsize];
	}
	else
	{
		[delegate simpleUnarchiver:self estimatedExtractionProgressForEntryWithDictionary:dict
		fileProgress:fileratio totalProgress:totalratio];
	}
}

-(void)unarchiver:(XADUnarchiver *)unarchiver findsFileInterestingForReason:(NSString *)reason
{
	[reasonsforinterest addObject:reason];
}

@end
