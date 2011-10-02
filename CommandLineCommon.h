#import <Foundation/Foundation.h>

#import "XADArchiveParser.h"

BOOL IsListRequest(NSString *encoding);
void PrintEncodingList();

NSString *DisplayNameForEntryWithDictionary(NSDictionary *dict);
NSString *LongInfoLineForEntryWithDictionary(XADArchiveParser *parser,NSDictionary *dict);
NSString *CompressionNameExplanationForLongInfo();

BOOL IsInteractive();
int GetPromptCharacter();
NSString *AskForPassword(NSString *prompt);
