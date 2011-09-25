#import <Foundation/Foundation.h>

BOOL IsListRequest(NSString *encoding);
void PrintEncodingList();

NSString *DisplayNameForEntryWithDictionary(NSDictionary *dict);
NSString *LongInfoLineForEntryWithDictionary(NSDictionary *dict);

BOOL IsInteractive();
int GetPromptCharacter();
NSString *AskForPassword(NSString *prompt);
