#import "CSCommandLineParser.h"
#import "NSStringPrinting.h"

#ifdef __MINGW32__
#import <windows.h>
#endif



static NSString *NamesKey=@"NamesKey";
static NSString *AllowedValuesKey=@"AllowedValuesKey";
static NSString *DefaultValueKey=@"DefaultValueKey";
static NSString *OptionTypeKey=@"OptionType";
static NSString *DescriptionKey=@"DescriptionKey";
static NSString *AliasTargetKey=@"AliasTargetKey";
static NSString *IsRequiredKey=@"IsRequiredKey";
static NSString *RequiredOptionsKey=@"RequiredOptionsKey";

static NSString *NumberValueKey=@"NumberValue";
static NSString *StringValueKey=@"StringValue";
static NSString *ArrayValueKey=@"ArrayValue";

static NSString *StringOptionType=@"StringOptionType";
static NSString *MultipleChoiceOptionType=@"MultipleChoiceOptionType";
static NSString *IntegerOptionType=@"IntegerOptionType";
static NSString *FloatingPointOptionType=@"FloatingPointOptionType";
static NSString *SwitchOptionType=@"SwitchOptionType";
static NSString *HelpOptionType=@"HelpOptionType";
static NSString *AliasOptionType=@"AliasOptionType";



@implementation CSCommandLineParser

-(id)init
{
	if(self=[super init])
	{
		options=[NSMutableDictionary new];
		optionordering=[NSMutableArray new];

		programname=nil;
		usageheader=nil;
		usagefooter=nil;
	}
	return self;
}

-(void)dealloc
{
	[programname release];
	[usageheader release];
	[usagefooter release];
	[super dealloc];
}




-(void)setProgramName:(NSString *)name
{
	[programname autorelease];
	programname=[name retain];
}

-(void)setUsageHeader:(NSString *)header
{
	[usageheader autorelease];
	usageheader=[header retain];
}

-(void)setUsageFooter:(NSString *)footer
{
	[usagefooter autorelease];
	usagefooter=[footer retain];
}




-(void)addStringOption:(NSString *)option description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		StringOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addStringOption:(NSString *)option defaultValue:(NSString *)defaultvalue description:(NSString *)description
{
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		defaultvalue,DefaultValueKey,
		StringOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		allowedvalues,AllowedValuesKey,
		MultipleChoiceOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues defaultValue:(NSString *)defaultvalue description:(NSString *)description
{
	NSUInteger index=[allowedvalues indexOfObject:[defaultvalue lowercaseString]];
	if(index==NSNotFound) [NSException raise:NSInvalidArgumentException format:
	@"Default value \"%@\" is not in the array of allowed values.",defaultvalue];

	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		allowedvalues,AllowedValuesKey,
		[NSNumber numberWithUnsignedInteger:index],DefaultValueKey,
		MultipleChoiceOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addIntOption:(NSString *)option description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		IntegerOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addIntOption:(NSString *)option defaultValue:(int)defaultvalue description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		[NSNumber numberWithInt:defaultvalue],DefaultValueKey,
		IntegerOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

// Int options with range?

-(void)addFloatOption:(NSString *)option description:(NSString *)description
{
	[self addDoubleOption:option description:description];
}

-(void)addFloatOption:(NSString *)option defaultValue:(float)defaultvalue description:(NSString *)description
{
	[self addDoubleOption:option defaultValue:defaultvalue description:description];
}

-(void)addDoubleOption:(NSString *)option description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		FloatingPointOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addDoubleOption:(NSString *)option defaultValue:(double)defaultvalue description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		[NSNumber numberWithDouble:defaultvalue],DefaultValueKey,
		FloatingPointOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addSwitchOption:(NSString *)option description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		SwitchOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}

-(void)addHelpOption
{
	[self addHelpOptionNamed:@"help"];
	[self addAlias:@"h" forOption:@"help"];
}

-(void)addHelpOptionNamed:(NSString *)helpoption
{
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:helpoption],NamesKey,
		HelpOptionType,OptionTypeKey,
	nil] forKey:helpoption];
}




-(void)addAlias:(NSString *)alias forOption:(NSString *)option
{
	[self _assertOptionNameIsUnique:alias];

	NSMutableDictionary *dict=[options objectForKey:option];
	if(!dict) [self _raiseUnknownOption:option];

	[[dict objectForKey:NamesKey] addObject:alias];

	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		option,AliasTargetKey,
		AliasOptionType,OptionTypeKey,
	nil] forKey:alias];
}




-(void)addRequiredOption:(NSString *)requiredoption
{
	NSMutableDictionary *dict=[options objectForKey:requiredoption];
	if(!dict) [self _raiseUnknownOption:requiredoption];

	[dict setObject:[NSNumber numberWithBool:YES] forKey:IsRequiredKey];
}

-(void)addRequiredOptionsArray:(NSArray *)requiredoptions
{
	NSEnumerator *enumerator=[requiredoptions objectEnumerator];
	NSString *requiredoption;
	while(requiredoption=[enumerator nextObject]) [self addRequiredOption:requiredoption];
}

-(void)addRequiredOption:(NSString *)requiredoption forOption:(NSString *)option
{
	NSMutableDictionary *dict=[options objectForKey:option];
	if(!dict) [self _raiseUnknownOption:option];

	NSMutableArray *requiredoptions=[dict objectForKey:RequiredOptionsKey];
	if(requiredoptions) [requiredoptions addObject:requiredoption];
	else
	{
		requiredoptions=[NSMutableArray arrayWithObject:requiredoption];
		[dict setObject:requiredoptions forKey:RequiredOptionsKey];
	}
}

-(void)addRequiredOptionsArray:(NSArray *)requiredoptions forOption:(NSString *)option
{
	NSEnumerator *enumerator=[requiredoptions objectEnumerator];
	NSString *requiredoption;
	while(requiredoption=[enumerator nextObject]) [self addRequiredOption:requiredoption forOption:option];
}




-(BOOL)parseCommandLineWithArgc:(int)argc argv:(const char **)argv
{
	NSMutableArray *arguments=[NSMutableArray array];

	#ifdef __MINGW32__
	int wargc;
	wchar_t **wargv=CommandLineToArgvW(GetCommandLineW(),&wargc);
	for(int i=0;i<wargc;i++) [arguments addObject:[NSString stringWithCharacters:wargv[i] length:wcslen(wargv[i])]];
	if(!programname) [self setProgramName:[NSString stringWithCharacters:wargv[0] length:wcslen(wargv[0])]];
	#else
	for(int i=1;i<argc;i++) [arguments addObject:[NSString stringWithUTF8String:argv[i]]];
	if(!programname) [self setProgramName:[NSString stringWithUTF8String:argv[0]]];
	#endif

	return [self parseArgumentArray:arguments];
}

-(BOOL)parseArgumentArray:(NSArray *)arguments
{
	NSMutableArray *remainingarguments=[NSMutableArray array];
	NSMutableArray *errors=[NSMutableArray array];

	[self _parseArguments:arguments remainingArguments:remainingarguments errors:errors];
	[self _setDefaultValues];
	[self _parseRemainingArguments:remainingarguments errors:errors];
	[self _enforceRequirementsWithErrors:errors];

[[options description] print];
[@"\n" print];

	if([errors count])
	{
		[self _reportErrors:errors];
		return NO;
	}
	else return YES;
}

-(void)_parseArguments:(NSArray *)arguments remainingArguments:(NSMutableArray *)remainingarguments
errors:(NSMutableArray *)errors
{
	NSEnumerator *enumerator=[arguments objectEnumerator];
	NSString *argument;
	BOOL stillparsing=YES;
	while(argument=[enumerator nextObject])
	{
		// Check for options, unless we have seen a stop marker.
		if(stillparsing && [argument characterAtIndex:0]=='-')
		{
			// Check for a stop marker.
			if([argument isEqual:@"--"])
			{
				stillparsing=NO;
				continue;
			}

			// See if option starts with one or two dashes (treated the same for now).
			int firstchar=1;
			if([argument characterAtIndex:1]=='-') firstchar=2;

			// See if the option is of the form -option=value, and extract the name and value.
			// Otherwise, just extract the name.
			NSString *option,*value;
			NSRange equalsign=[argument rangeOfString:@"="];
			if(equalsign.location!=NSNotFound)
			{
				option=[argument substringWithRange:NSMakeRange(firstchar,equalsign.location-firstchar)];
				value=[argument substringFromIndex:equalsign.location+1];
			}
			else
			{
				option=[argument substringFromIndex:firstchar];
				value=nil; // Find the value later.
			}

			// Find option dictionary, or produce an error if the option is not known.
			NSMutableDictionary *dict=[options objectForKey:option];
			if(!dict)
			{
				[errors addObject:[NSString stringWithFormat:@"Unknown option \"%@\".",argument]];
				continue;
			}

			NSString *type=[dict objectForKey:OptionTypeKey];

			// Resolve aliases.
			while(type==AliasOptionType)
			{
				dict=[options objectForKey:[dict objectForKey:AliasTargetKey]];
				type=[dict objectForKey:OptionTypeKey];
			}

			// Handle help options.
			if(type==HelpOptionType)
			{
				[self printUsage];
				exit(0);
			}

			// Find value for options of the form -option value, if needed.
			if(!value)
			if(type==StringOptionType||type==MultipleChoiceOptionType||
			type==IntegerOptionType||type==FloatingPointOptionType)
			{
				value=[enumerator nextObject];
				if(!value)
				{
					[errors addObject:[NSString stringWithFormat:@"The option \"%@\" requires a value.",option]];
					continue;
				}
			}

			// Actually parse value and type
			[self _parseOptionWithDictionary:dict type:type name:option value:value errors:errors];
		}
		else
		{
			[remainingarguments addObject:argument];
		}
	}
}

-(void)_parseOptionWithDictionary:(NSMutableDictionary *)dict type:(NSString *)type
name:(NSString *)option value:(NSString *)value errors:(NSMutableArray *)errors
{
	if(type==StringOptionType)
	{
		[dict setObject:value forKey:StringValueKey];
	}
	else if(type==MultipleChoiceOptionType)
	{
		NSArray *allowedvalues=[dict objectForKey:AllowedValuesKey];
		NSUInteger index=[allowedvalues indexOfObject:[value lowercaseString]];
		if(index==NSNotFound)
		{
			[errors addObject:[NSString stringWithFormat:@"\"%@\" is not a valid "
			@"value for option \"%@\". (Valid values are: %@)",value,option,
			[allowedvalues componentsJoinedByString:@", "]]];
			return;
		}

		[dict setObject:[allowedvalues objectAtIndex:index] forKey:StringValueKey];
		[dict setObject:[NSNumber numberWithUnsignedInteger:index] forKey:NumberValueKey];
	}
	else if(type==IntegerOptionType)
	{
		NSScanner *scanner=[NSScanner scannerWithString:value];
		BOOL success;
		if([value hasPrefix:@"0x"]||[value hasPrefix:@"0X"])
		{
			unsigned long long intval;
			success=[scanner scanHexLongLong:&intval];
			if(success) [dict setObject:[NSNumber numberWithUnsignedLongLong:intval] forKey:NumberValueKey];
		}
		else
		{
			long long intval;
			success=[scanner scanLongLong:&intval];
			if(success) [dict setObject:[NSNumber numberWithLongLong:intval] forKey:NumberValueKey];
		}

		if(!success)
		{
			[errors addObject:[NSString stringWithFormat:@"The option \"%@\" requires an "
			@"integer number value.",option]];
			return;
		}
	}
	else if(type==FloatingPointOptionType)
	{
		NSScanner *scanner=[NSScanner scannerWithString:value];
		double floatval;
		BOOL success;
		if([value hasPrefix:@"0x"]||[value hasPrefix:@"0X"]) success=[scanner scanHexDouble:&floatval];
		else success=[scanner scanDouble:&floatval];

		if(!success)
		{
			[errors addObject:[NSString stringWithFormat:@"The option \"%@\" requires a "
			@"floating-point number value.",option]];
			return;
		}

		[dict setObject:[NSNumber numberWithDouble:floatval] forKey:NumberValueKey];
	}
	else if(type==SwitchOptionType)
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:NumberValueKey];
	}
}

-(void)_setDefaultValues
{
	NSEnumerator *enumerator=[options objectEnumerator];
	NSMutableDictionary *dict;
	while(dict=[enumerator nextObject])
	{
		id defaultvalue=[dict objectForKey:DefaultValueKey];
		if(!defaultvalue) continue;

		NSString *type=[dict objectForKey:OptionTypeKey];

		if(type==StringOptionType)
		{
			if(![dict objectForKey:StringValueKey]) [dict setObject:defaultvalue forKey:StringValueKey];
		}
		else if(type==MultipleChoiceOptionType)
		{
			if(![dict objectForKey:NumberValueKey])
			{
				NSUInteger index=[defaultvalue unsignedIntegerValue];
				NSArray *allowedvalues=[dict objectForKey:AllowedValuesKey];
				[dict setObject:[allowedvalues objectAtIndex:index] forKey:StringValueKey];
				[dict setObject:defaultvalue forKey:NumberValueKey];
			}
		}
		else if(type==IntegerOptionType||type==FloatingPointOptionType)
		{
			if(![dict objectForKey:NumberValueKey]) [dict setObject:defaultvalue forKey:NumberValueKey];
		}
	}
}

-(void)_parseRemainingArguments:(NSArray *)remainingarguments errors:(NSMutableArray *)errors
{
}

-(void)_enforceRequirementsWithErrors:(NSMutableArray *)errors
{
}

-(BOOL)_isOptionDefined:(NSString *)option
{
	NSDictionary *dict=[options objectForKey:option];
	return [dict objectForKey:StringValueKey]||[dict objectForKey:NumberValueKey]||[dict objectForKey:ArrayValueKey];
}

-(void)_reportErrors:(NSArray *)errors
{
	NSEnumerator *enumerator=[errors objectEnumerator];
	NSString *error;
	while(error=[enumerator nextObject])
	{
		[error print];
		[@"\n" print];
	}
}




-(void)printUsage
{
	[usageheader print];

	NSEnumerator *enumerator=[optionordering objectEnumerator];
	NSString *option;
	while(option=[enumerator nextObject])
	{
		NSDictionary *dict=[options objectForKey:option];

		[@"-" print];
		[option print];
		[@"   " print];
		[[dict objectForKey:DescriptionKey] print];
		[@"\n" print];
	}

	[usagefooter print];
}



-(NSString *)stringValueForOption:(NSString *)option
{
	return [[options objectForKey:option] objectForKey:StringValueKey];
}

-(NSArray *)stringArrayValueForOption:(NSString *)option
{
	return [[options objectForKey:option] objectForKey:ArrayValueKey];
}

-(int)intValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] intValue];
}

-(float)floatValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] floatValue];
}

-(double)doubleValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] doubleValue];
}

-(BOOL)boolValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] boolValue];
}




-(void)_assertOptionNameIsUnique:(NSString *)option
{
	if([options objectForKey:option])
	[NSException raise:NSInvalidArgumentException format:@"Attempted to add duplicate option \"%@\".",option];
}

-(void)_raiseUnknownOption:(NSString *)option
{
	[NSException raise:NSInvalidArgumentException format:@"Unknown option \"%@\".",option];
}

@end
