#import <Cocoa/Cocoa.h>

@interface CSCommandLineParser:NSObject
{
	NSMutableDictionary *options;
	NSMutableArray *optionordering;

	NSString *programname,*usageheader,*usagefooter;
}

-(id)init;
-(void)dealloc;

-(void)setProgramName:(NSString *)name;
-(void)setUsageHeader:(NSString *)header;
-(void)setUsageFooter:(NSString *)footer;

-(void)addStringOption:(NSString *)option description:(NSString *)description;
-(void)addStringOption:(NSString *)option defaultValue:(NSString *)defaultvalue description:(NSString *)description;
-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues description:(NSString *)description;
-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues defaultValue:(NSString *)defaultvalue description:(NSString *)description;
-(void)addIntOption:(NSString *)option description:(NSString *)description;
-(void)addIntOption:(NSString *)option defaultValue:(int)defaultvalue description:(NSString *)description;
-(void)addFloatOption:(NSString *)option description:(NSString *)description;
-(void)addFloatOption:(NSString *)option defaultValue:(float)defaultvalue description:(NSString *)description;
-(void)addDoubleOption:(NSString *)option description:(NSString *)description;
-(void)addDoubleOption:(NSString *)option defaultValue:(double)defaultvalue description:(NSString *)description;
-(void)addSwitchOption:(NSString *)option description:(NSString *)description;
-(void)addHelpOption;
-(void)addHelpOptionNamed:(NSString *)helpoption;

-(void)addAlias:(NSString *)alias forOption:(NSString *)option;

-(void)addRequiredOption:(NSString *)requiredoption;
-(void)addRequiredOptionsArray:(NSArray *)requiredoptions;
-(void)addRequiredOption:(NSString *)requiredoption forOption:(NSString *)option;
-(void)addRequiredOptionsArray:(NSArray *)requiredoptions forOption:(NSString *)option;

-(BOOL)parseCommandLineWithArgc:(int)argc argv:(const char **)argv;
-(BOOL)parseArgumentArray:(NSArray *)arguments;

-(void)_parseArguments:(NSArray *)arguments remainingArguments:(NSMutableArray *)remainingarguments
errors:(NSMutableArray *)errors;
-(void)_parseOptionWithDictionary:(NSMutableDictionary *)dict type:(NSString *)type
name:(NSString *)option value:(NSString *)value errors:(NSMutableArray *)errors;
-(void)_setDefaultValues;
-(void)_parseRemainingArguments:(NSArray *)remainingarguments errors:(NSMutableArray *)errors;
-(void)_enforceRequirementsWithErrors:(NSMutableArray *)errors;
-(BOOL)_isOptionDefined:(NSString *)option;
-(void)_reportErrors:(NSArray *)errors;

-(void)printUsage;

-(NSString *)stringValueForOption:(NSString *)option;
-(NSArray *)stringArrayValueForOption:(NSString *)option;
-(int)intValueForOption:(NSString *)option;
-(float)floatValueForOption:(NSString *)option;
-(double)doubleValueForOption:(NSString *)option;
-(BOOL)boolValueForOption:(NSString *)option;

-(void)_assertOptionNameIsUnique:(NSString *)option;
-(void)_raiseUnknownOption:(NSString *)option;

@end
