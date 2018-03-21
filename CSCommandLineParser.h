/*
 * CSCommandLineParser.h
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#import <Foundation/Foundation.h>

@interface CSCommandLineParser:NSObject
{
	NSMutableDictionary *options;
	NSMutableArray *optionordering;
	NSMutableArray *alwaysrequiredoptions;

	NSArray *remainingargumentarray;

	NSString *programname,*usageheader,*usagefooter,*programversion;
}

-(id)init;
-(void)dealloc;

-(void)setProgramName:(NSString *)name;
-(void)setUsageHeader:(NSString *)header;
-(void)setUsageFooter:(NSString *)footer;
-(void)setProgramVersion:(NSString *)version;

-(void)addStringOption:(NSString *)option
description:(NSString *)description;
-(void)addStringOption:(NSString *)option defaultValue:(NSString *)defaultvalue
description:(NSString *)description;
-(void)addStringOption:(NSString *)option
description:(NSString *)description argumentDescription:(NSString *)argdescription;
-(void)addStringOption:(NSString *)option defaultValue:(NSString *)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription;
-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues
description:(NSString *)description;
-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues defaultValue:(NSString *)defaultvalue
description:(NSString *)description;
-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues
description:(NSString *)description argumentDescription:(NSString *)argdescription;
-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues defaultValue:(NSString *)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription;

-(void)addIntegerOption:(NSString *)option
description:(NSString *)description;
-(void)addIntegerOption:(NSString *)option
description:(NSString *)description argumentDescription:(NSString *)argdescription;
-(void)addIntegerOption:(NSString *)option defaultValue:(int)defaultvalue
description:(NSString *)description;
-(void)addIntegerOption:(NSString *)option defaultValue:(int)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription;

-(void)addFloatingPointOption:(NSString *)option
description:(NSString *)description;
-(void)addFloatingPointOption:(NSString *)option
description:(NSString *)description argumentDescription:(NSString *)argdescription;
-(void)addFloatingPointOption:(NSString *)option defaultValue:(double)defaultvalue
description:(NSString *)description;
-(void)addFloatingPointOption:(NSString *)option defaultValue:(double)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription;

-(void)addSwitchOption:(NSString *)option description:(NSString *)description;

-(void)addHelpOption;
-(void)addHelpOptionNamed:(NSString *)helpoption description:(NSString *)description;

-(void)addVersionOption;
-(void)addVersionOptionNamed:(NSString *)versionoption description:(NSString *)description;

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
-(void)_requireOptionsInArray:(NSArray *)requiredoptions when:(NSString *)when errors:(NSMutableArray *)errors;
-(BOOL)_isOptionDefined:(NSString *)option;
-(NSString *)_describeOption:(NSString *)name;
-(NSString *)_describeOptionAndArgument:(NSString *)name;
-(void)_reportErrors:(NSArray *)errors;

-(void)printUsage;

-(NSString *)stringValueForOption:(NSString *)option;
-(NSArray *)stringArrayValueForOption:(NSString *)option;
-(int)intValueForOption:(NSString *)option;
-(float)floatValueForOption:(NSString *)option;
-(double)doubleValueForOption:(NSString *)option;
-(BOOL)boolValueForOption:(NSString *)option;

-(NSArray *)remainingArguments; // TODO: figure out something better than this.

-(void)_assertOptionNameIsUnique:(NSString *)option;
-(void)_raiseUnknownOption:(NSString *)option;

@end
