#import <Foundation/Foundation.h>


@interface CSJSONPrinter:NSObject
{
	int indentlevel;
	NSString *indentstring;
	BOOL asciimode;

	BOOL needseparator;
}

-(id)init;
-(void)dealloc;

-(void)setIndentString:(NSString *)string;
-(void)setASCIIMode:(BOOL)ascii;

-(void)printObject:(id)object;

-(void)printNull;
-(void)printNumber:(NSNumber *)number;
-(void)printString:(NSString *)string;
-(void)printData:(NSData *)data;
-(void)printValue:(NSValue *)value;
-(void)printArray:(NSArray *)array;
-(void)printDictionary:(NSDictionary *)dictionary;

-(void)startPrintingArray;
-(void)startPrintingArrayObject;
-(void)printArrayObject:(id)object;
-(void)endPrintingArray;
-(void)printArrayObjects:(NSArray *)array;

-(void)startPrintingDictionary;
-(void)startPrintingDictionaryObjectForKey:(id)key;
-(void)printDictionaryObject:(id)object forKey:(id)key;
-(void)endPrintingDictionary;
-(void)printDictionaryKeysAndObjects:(NSDictionary *)dictionary;

-(void)startNewLine;
-(void)printSeparatorIfNeeded;

-(NSString *)stringByEscapingString:(NSString *)string;
-(NSString *)stringByEncodingBytes:(const uint8_t *)bytes length:(int)length;

@end
