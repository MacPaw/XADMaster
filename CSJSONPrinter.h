#import <Foundation/Foundation.h>


@interface CSJSONPrinter:NSObject
{
	int indentlevel;
	NSString *indentstring;
	BOOL asciimode;
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
-(void)printArrayObject:(id)object;
-(void)endPrintingArray;
-(void)startPrintingArrayObject;
-(void)endPrintingArrayObject;

-(void)startPrintingDictionary;
-(void)printDictionaryKey:(id)key;
-(void)printDictionaryObject:(id)object;
-(void)endPrintingDictionary;
-(void)startPrintingDictionaryObject;
-(void)endPrintingDictionaryObject;

-(void)startNewLine;

-(NSString *)stringByEscapingString:(NSString *)string;
-(NSString *)stringByEncodingBytes:(const uint8_t *)bytes length:(int)length;

@end
