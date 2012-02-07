#import <Foundation/Foundation.h>

#import "XADArchiveParser.h"

BOOL IsListRequest(NSString *encoding);
void PrintEncodingList();

NSString *ShortInfoLineForEntryWithDictionary(NSDictionary *dict);
NSString *MediumInfoLineForEntryWithDictionary(NSDictionary *dict);
NSString *LongInfoLineForEntryWithDictionary(XADArchiveParser *parser,NSDictionary *dict);
NSString *CompressionNameExplanationForLongInfo();

void PrintFullDescriptionOfEntryWithDictionary(XADArchiveParser *parser,NSDictionary *dict);

BOOL IsInteractive();
int GetPromptCharacter();
NSString *AskForPassword(NSString *prompt);
