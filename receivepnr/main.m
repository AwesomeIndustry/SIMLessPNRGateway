#include <stdio.h>
#import <MRYIPCCenter.h>


//Shamelessly stolen from StackOverflow. https://stackoverflow.com/questions/2501033/nsstring-hex-to-bytes
//This converts a string with hex data (such as @"37C3F2AE") into a real NSData* object (i.e. <37c3 f2ae>)
//Used for converting the signature string in the REG-RESP SMS into an NSData* object
@interface NSString (NSStringHexToBytes)
-(NSData*) hexToBytes ;
@end

@implementation NSString (NSStringHexToBytes)
-(NSData*) hexToBytes {
  NSMutableData* data = [NSMutableData data];
  int idx;
  for (idx = 0; idx+2 <= self.length; idx+=2) {
    NSRange range = NSMakeRange(idx, 2);
    NSString* hexStr = [self substringWithRange:range];
    NSScanner* scanner = [NSScanner scannerWithString:hexStr];
    unsigned int intValue;
    [scanner scanHexInt:&intValue];
    [data appendBytes:&intValue length:1];
  }
  return data;
}
@end

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		printf("Hello world!\n");


		char *respMessage = argv[1];

	    NSString* msgText = [NSString stringWithUTF8String:respMessage];

		// NSLog(@"Response text is %@", msgText);
	    // Message text is REG-RESP?v=3;r=72325403;n=+11234567890;s=CA21C50C645469B25F4B65C38A7DCEC56592E038F39489F35C7CD6972D

	    NSLog(@"PNRGateway: msgText is %@", msgText);
	    NSLog(@"PNRGateway: This is the new regex match method!");

	    //Uses a regular expression to extract the relevant fields from the received SMS: the phone number (starting with n=)
	    //  and the signature (starting with s=)
	    NSRegularExpression *regRespRegex = [NSRegularExpression regularExpressionWithPattern:@"REG-RESP\\?v=\\d;r=\\d+;n=([\\+\\d]+);s=([0-9A-F]+)" options:0 error:nil];
	    NSTextCheckingResult *result = [regRespRegex firstMatchInString:msgText options:0 range:NSMakeRange(0, [msgText length])];


	    if (result) {
	        NSLog(@"PNRGateway: Regex match: %@", result);
	    } else {
	        NSLog(@"PNRGateway: No match found");
	        return 0;
	    }

	    if (result.numberOfRanges < 2) {
	        NSLog(@"PNRGateway: Not enough matches found!");
	        return 0;
	    }

	    //Extracts the phone number from the regex
	    NSRange phoneNumberRange = [result rangeAtIndex:1];
	    NSString *phoneNumberMatch = [msgText substringWithRange:phoneNumberRange];
	    NSLog(@"PNRGateway: Phone number: %@", phoneNumberMatch);

	    //Extracts the signature from the regex
	    NSRange signatureRange = [result rangeAtIndex:2];
	    NSString *signatureMatch = [msgText substringWithRange:signatureRange];
	    NSLog(@"PNRGateway: Signature: %@", signatureMatch);

	    //Converts the signature to NSData* using the hexToBytes method defined above.
	    NSData* byteSignature = [signatureMatch hexToBytes];

	    NSLog(@"PNRGateway: Converted signature to bytes: %@", byteSignature);






		//Sets up the MRYIPC client so this method (running inside SMSApplication) can call the emulateReceivedResponsePNR
	    //  method located in the IDSPhoneNumberValidationStateMachine
	    NSLog(@"PNRGateway: Setting up MRYIPC client");
	    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"dev.altavision.SIMLessPNR"];
	    NSLog(@"PNRGateway: Got reference to dev.altavision.SIMLessPNR: %@", center);


        // [center addTarget:^id() {
        //     // Inline block code
        //     NSLog(@"Block executed");
        //
        // } forSelector:@selector(testIPC:)];
        NSLog(@"PNRGateway: Testing IPC center...");
        // [center callExternalMethod:@selector(testIPC:) withArguments:nil];
        NSLog(@"PNRGateway: Finished testing IPC center");


	    //Calls the emulateReceivedResponsePNR method inside the state machine
	    // NSLog(@"PNRGateway: Calling external method handleIncomingSMSForPhoneNumber...");
	    [center callExternalMethod:@selector(performResponse:) withArguments:@[phoneNumberMatch, byteSignature]];
	    // NSLog(@"PNRGateway: Called external method handleIncomingSMSForPhoneNumber");



        NSLog(@".");
        NSLog(@".");

		return 0;
	}
}
