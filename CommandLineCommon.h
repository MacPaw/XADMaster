#import <Foundation/Foundation.h>

BOOL IsListRequest(NSString *encoding);
void PrintEncodingList();

NSString *DisplayNameForEntryWithDictionary(NSDictionary *dict);

NSString *AskForPassword(NSString *prompt);
BOOL IsInteractive();
