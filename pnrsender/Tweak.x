#import <Foundation/NSObject.h>
#import <objc/runtime.h>
#import <SpringBoard/SpringBoard.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MRYIPCCenter.h>

#import "Tweak.h"
#import "dlfcn.h"


NSString * const DUMMY_PLMN = @"310410"; //AT&T USA
NSString * const DUMMY_IMSI = @"310410777777778";


@interface IDSPreflightMessage
- (void)handleResponseDictionary:(id)arg1;
- (id)bagKey;
- (id)requiredKeys;
- (id)messageBody;
- (id)additionalMessageHeaders;
- (id)copyWithZone:(struct _NSZone *)arg1;

+ (Class) class;

@end


%hook IDSPhoneNumberValidationMechanism

    + (id)SMSMechanismWithContext:(id)gatewayAddress {
        %log;
        //When the SMSMechanismWithContext constructor is called, it's passed the gateway phone number (i.e. +447786205094 in most cases)
        //The gateway phone number is the phone number the iPhone sends the REG-REQ SMS to (when registering for iMessage normally).
        //This code overwrites the gateway number to the Android phone's number such that the Android phone gets the
        //  REG-REQ SMS instead.

        //Note: This appeared to work when overriding with @"28818773", but I'm fairly sure it's supposed to be the Android phone number
        // NSString *pnrGatewayNumber = @"28818773";
        // return %orig(pnrGatewayNumber);

        NSLog(@"PNRGateway: SMSMechanismWithContext called");


        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:@"/pnr_android_number.txt" encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            NSLog(@"PNRGateway: Error reading phone number from file: %@", error);
        }

        NSString *trimmedString = [fileContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSLog(@"PNRGateway: Overriding gatewayAddress with %@", trimmedString);
        return %orig(trimmedString);
    }

    + (id)SMSLessMechanism {
        //Some carriers support a registration method called "SMSLess", which doesn't send SMSes at all, and instead registers
        //  directly with the carrier's VoLTE servers via HTTP.
        //This code makes sure that if the system asks for an SMSLessMechanism object, it's replaced with an SMSMechanismWithContext
        //  object, forcing the iPhone to register via SMS.

        NSLog(@"PNRGateway: Got SMSLess mechanism, overriding with SMS mechanism");
        %log;

        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:@"/pnr_android_number.txt" encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            NSLog(@"PNRGateway: Error reading phone number from file: %@", error);
        }

        NSString *trimmedString = [fileContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];


        return [%c(IDSPhoneNumberValidationMechanism) SMSMechanismWithContext:trimmedString];

    }

    - (id)initWithType:(long long)type context:(id)gatewayAddress {
        //This appears to be some other constructor involved in creating the IDSPhoneNumberValidationMechanism object.
        //This code is just here to make sure it creates an SMS registration object (type = 1) with the Android phone
        //  number for the gatewayAddress.

        NSLog(@"PNRGateway: Got initWithType call");

        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:@"/pnr_android_number.txt" encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            NSLog(@"PNRGateway: Error reading phone number from file: %@", error);
        }

        NSString *trimmedString = [fileContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSLog(@"PNRGateway: Overriding with type 1 and gatewayAddress %@", trimmedString);


        %log; // -[<IDSPhoneNumberValidationMechanism: 0x1017cc160> initWithType:1 context:+447537410287]
        // return %orig(1, @"+11234567890"); //Type 1 = SMS-based
        return %orig(1,trimmedString);
    }

%end

%hook IDSPhoneNumberValidationStateMachineDeviceSupport
    - (_Bool)supportsSMSIdentification {
        %log;
        return YES;
    };
%end

MSHook(int, _CTServerConnectionIsUserIdentityModuleRequired, void* arg1, void* arg2) {
    return 0;
}


%hook IDSPhoneNumberValidationStateMachine

    - (long long) status {

        //Overriding this "status" function fixes a problem I ran into when piping in
        //the REG-RESP SMS data--the IDSPhoneNumberValidationStateMachine kept throwing
        //an error that it wasn't in the right state to accept the REG-RESP message.
        //Thus, before PNRGateway hands off the REG-RESP data to the state machine, it
        //sets up the "fakeStatus" instance variable, which causes the state machine
        //to report a status of "3" while it's processing the REG-RESP message. Once
        //it's done, the "fakeStatus" variable is set to nil, going back to letting the
        //state machine modify its status value. (At the end of handleIncomingSMSForPhoneNumber,
        //the state machine changes its real status value to indicate that it's done
        //processing the SMS, so setting "fakeStatus" to nil gives control over the status
        //variable back to the state machine.

        //Known status values:
        // 2: Happens sometime before request SMS is sent
        // 3: Waiting for Authentication Response, I think!!

        id instance = self;
        NSLog(@"PNRGateway: Got status getter call: %lld", %orig);

        id propertyValue = objc_getAssociatedObject(instance, &"fakeStatus");
        if (propertyValue) {
            // If the property exists, do nothing. MRYIPC server has already been created
            NSLog(@"PNRGateway: Fake status exists! Sending that instead: %@", propertyValue);
            return [propertyValue longLongValue];
        } else {
            return %orig;
        }

    };

    %new

    - (void)emulateReceivedResponsePNR:(NSArray *) responseData {

        //Runs when ReceivePNR calls this method through IPC. This sets the rest of
        //the registration process in motion, causing the IDSPhoneNumberValidationStateMachine
        //to accept the REG-RESP data as if it was received via a genuine SMS

        //responseData should be an NSArray with two elements:
        //  1. An NSString with the phone number in international format (i.e. +18882278255)
        //  2. An NSData with the signature data (i.e. <0123 45ab c23d ...>)

        NSLog(@"PNRGateway: Got emulateReceivedResponsePNR call! %@", responseData);

        if (responseData.count != 2) {
            NSLog(@"PNRGateway: Response data has wrong length! %@", responseData);
            return;
        }


        //Sets the fake status to 3, which apparently means "Waiting for authentication response".
        //See the status hook above for more information
        objc_setAssociatedObject(self, &"fakeStatus", @(3), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        //Calls the real handleIncomingSMSForPhoneNumber method in IDSPhoneNumberValidationStateMachine, which will
        //  give the phone number and signature back to the state machine, which will complete phone number registration
        //  for the Android phone number!
        NSLog(@"PNRGateway: Calling handleIncomingSMSForPhoneNumber");
        [self handleIncomingSMSForPhoneNumber:responseData[0] signature:responseData[1]];
        NSLog(@"PNRGateway: Finished calling handleIncomingSMSForPhoneNumber");

        //Erases the fake status to make sure it can proceed through the rest of the
        //registration process. See the status hook above for more information
        objc_setAssociatedObject(self, &"fakeStatus", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    }

    %new

    - (void) ensureIPCIsSetUp {
        //This method just makes sure that the MRYIPC center is set up, so
        //the emulateReceivedResponsePNR method can run when called by ReceivePNR (via IPC)

        id instance = self;

        // Check if the property exists
        id propertyValue = objc_getAssociatedObject(instance, &"HasSetUpMRYIPC");
        if (propertyValue) {
            // If the property exists, do nothing. MRYIPC server has already been created
            NSLog(@"PNRGateway: MRYIPC center already exists! Value is %@", propertyValue);
        } else {

            NSLog(@"PNRGateway: Overriding _CTServerConnectionIsUserIdentityModuleRequired");


            //This overrides the _CTServerConnectionIsUserIdentityModuleRequired C function, which
            //IDSRegistration checks later during the HTTP Registration step (to make sure there's a SIM
            //card in the device).
            //It might also work to hook -(bool)requiresSIMInserted in IMMobileNetworkManager
            void *coretelephony_ref = dlopen("/System/Library/PrivateFrameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);

            if (coretelephony_ref) {
                NSLog(@"PNRGateway: libdyld_handle is not null!");
                void *dlsym_funcptr = dlsym(coretelephony_ref, "_CTServerConnectionIsUserIdentityModuleRequired");

                if (dlsym_funcptr) {
                    NSLog(@"PNRGateway: dlsym_funcptr is not null!");
                    MSHookFunction(dlsym_funcptr, MSHake(_CTServerConnectionIsUserIdentityModuleRequired));
                } else {
                    NSLog(@"PNRGateway: dlsym_funcptr is null :(");
                }

            } else {
                NSLog(@"PNRGateway: libdyld_handle is null :(");
            }






            // If the property doesn't exist, create it
            NSLog(@"PNRGateway: MRYIPC center does not exist, creating...");

            NSLog(@"PNRGateway: Setting up the MRYIPCCenter");
            MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"dev.altavision.SIMLessPNR"];
            NSLog(@"PNRGateway: MRYIPCCenter is %@", center);

            [center addTarget:^id(NSArray *responseData) {
                // Runs emulateReceivedResponsePNR when data is received via IPC
                NSLog(@"PNRGateway: IPC center test success!!");
                NSLog(@"PNRGateway: State machine reference: %@", self);
                NSLog(@"PNRGateway: Response data is %@", responseData);
                [self emulateReceivedResponsePNR:responseData];

                return nil;
            } forSelector:@selector(performResponse:)];


            objc_setAssociatedObject(instance, &"HasSetUpMRYIPC", center, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }


    }



    - (id) init {
        NSLog(@"PNRGateway: State machine initialized!!");

        //Erases the fake status to make sure it can proceed through the rest of the
        //registration process. See the status hook above for more information
        objc_setAssociatedObject(self, &"fakeStatus", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [self ensureIPCIsSetUp]; //Ensures the IPC center is set up to allow communication with ReceivePNR script

        return %orig;
    }

    //TODO: Maybe look at _IDSFetchPhoneNumber ?

    - (id)initWithHTTPDelivery:(id)arg1 lockdownManager:(id)arg2 arbiter:(id)arg3 deviceSupport:(id)arg4 systemAccountAdapter:(id)arg5 {

        NSLog(@"PNRGateway: State machine: Initialized via HTTP delivery instead of in normal mode :(");

        //Erases the fake status to make sure it can proceed through the rest of the
        //registration process. See the status hook above for more information
        objc_setAssociatedObject(self, &"fakeStatus", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self ensureIPCIsSetUp];

        return %orig;
    };

    - (void)_registrationStateChangedNotification:(id)arg1 {
        NSLog(@"PNRGateway: Registration state changed notification: %@", arg1);
        %orig;
    };

    - (void)_checkRegistrationStatus {
        NSLog(@"PNRGateway: Device checked registration status");
        %orig;
    }

    - (long long)_registrationControlStatus {
        long long originalStatus = %orig;
        NSLog(@"Device queried registration control status: %lld", originalStatus);
        return originalStatus;
    }

    - (void)_sendPreflightVerificationWithIMSI:(id)arg1 PLMN:(id)arg2 {
        NSLog(@"PNRGateway: Sent preflight verification with IMSI: arg1: %@ and arg2: %@", arg1, arg2);
        %orig;
    }

    - (void)_popHighestPriorityPreflightVerification {
        NSLog(@"PNRGateway: Called _popHighestPriorityPreflightVerification");
        %orig;
    }
    - (void)_sendPreflightVerificationIfNeeded {

        //This bypasses the preflight entirely and jumps straight to trying to send the SMS.
        //(This was another attempt to thwart error 6001 and I'm too worried to remove it)

        NSLog(@"PNRGateway: Called _sendPreflightVerificationIfNeeded");
        [self _sendSMSVerificationWithMechanism:nil];
    }

    - (void)_sendSMSVerificationWithMechanism:(id)arg1 {
        NSLog(@"PNRGateway: Got _sendSMSVerificationWithMechanism call");
        [self ensureIPCIsSetUp];
        %orig;
    }

    - (void)_issueAsyncCoreTelephonyPhoneNumberValidationRequestWithPushToken:(id)arg1 mechanism:(id)arg2 {

        //This is where identityservicesd tries to set the verification process in motion.
        //As we're taking over this process, we log the push token (this push token needs
        //to be sent to the Android phone) and then don't call %orig to prevent the device
        //from trying (and failing) to send the SMS.

        [self ensureIPCIsSetUp];
        NSLog(@">>>>>>>>>>>>>>>>>>>>>> PNRGateway: Push Token Received! %@", arg1);

    }

    - (void)_failPromisesWithError:(long long)arg1 {
        NSLog(@"PNRGateway: Called _failPromisesWithError: %lld", arg1);
        %orig;
    }
    - (void)_fulfillPromisesWithPhoneNumber:(id)arg1 token:(id)arg2 {
        NSLog(@"PNRGateway: Called _fulfillPromisesWithPhoneNumber: %@, %@", arg1, arg2);
        %orig;
    }
    - (void)_notifySuccess:(id)arg1 token:(id)arg2 {
        NSLog(@"PNRGateway: Called _notifySuccess: %@, token: %@", arg1, arg2);
        %orig;
    }
    - (void)_notifyFailureWithError:(long long)arg1 {

        //Most of the errors in the early registration stages (anything before the HTTP
        //registration step) come through here, so this just makes sure they are
        //easy to find in the logs.

        NSLog(@"PNRGateway:Called _notifyFailureWithError: %lld", arg1);


        if (arg1 == 36) { //Error code 36 = Failed preflight
            NSLog(@"========> [!] [!] [!] ERROR: PNRGateway: Failed preflight request");
        } else if (arg1 == 2) {
            NSLog(@"PNRGateway: Not registering because user denied it");
        }

        %orig;
    }
    - (void)_performHighestPriorityPreflightVerification {
        NSLog(@"PNRGateway:Called _performHighestPriorityPreflightVerification");
        %orig;
    }
    - (void)pnrRequestSent:(id)arg1 pnrReqData:(id)arg2 {
        NSLog(@"PNRGateway: Device says PNR Request sent: %@ and %@", arg1, arg2);
        %orig;
    }
    - (void)handleRegistrationSMSSuccessfullyDeliveredWithTelephonyTimeout:(id)arg1 {
        NSLog(@"PNRGateway: Device says registration SMS successfully delivered: %@", arg1);
        %orig;
    }
    - (void)handleRegistrationSMSDeliveryFailedWithShouldBypassRetry:(_Bool)arg1 {
        NSLog(@"PNRGateway: Device says SMS delivery failed: %d", arg1);
        %orig;
    }
    - (void)handleRegistrationSMSDeliveryFailed {
        NSLog(@"PNRGateway: Device says SMS delivery failed");
        %orig;
    }
    - (void)_tryToSendSMSIdentification {
        //This is really here just to notify us (i.e. the users watching the log messages)
        //that the device has begun trying to send SMS identification and is in a state to
        //receive the REG-RESP message. Don't run ReceivePNR until you see this message
        //appear in the logs.

        //For a more full-featured app that automatically tells the Android phone to send
        //its SMS, make sure to only tell the Android phone to start doing that once this
        //method runs and it has the push token.
        NSLog(@">>>>>>>>>>>>>>>>>>>>>> PNRGateway: Device tried to send SMS Identification!");

        %orig;
    }


    - (void)handleIncomingSMSForPhoneNumber:(id)arg1 signature:(id)arg2 {
        //This is the method that will get the IDSPhoneNumberValidationStateMachine to finish registration after
        //  the SMS is received from the Android phone. The hooked code doesn't do anything of substance, just a
        //  little logging to make sure it's being called. The state machine handles the rest of the registration
        //  from here.

        %log;
        NSLog(@"PNRGateway: Finishing phone number registration!");
        NSObject *a1 = arg1; //"+11234567890", __NSCFString__
        NSObject *a2 = arg2; //<ca21c50c 645469b2 5f4b65c3 8a7dcec5 6592e038 f39489f3 5c7cd697 2d>, _NSInlineData

        NSLog(@"PNRGateway: arg1: %@", arg1);
        NSLog(@"PNRGateway: Type of arg1: %@", NSStringFromClass(a1.class));

        NSLog(@"PNRGateway: arg2: %@", arg2);
        NSLog(@"PNRGateway: Type of arg2: %@", NSStringFromClass(a2.class));

        %orig;
    }


%end

%hook IDSRegistrationController

    + (_Bool)validSIMStateForRegistration {
        return YES;
    }
    - (_Bool)validSIMStateForRegistration {
        return YES;
    }
    - (_Bool)systemSupportsServiceType:(id)arg1 registrationType:(long long)arg2 {
        if ([arg1 isEqualToString:@"iMessage"] && arg2 == 0) {
            //No idea if this actually works to ensure iMessage activates,
            //but I'm keeping it here just for safety
            return YES;
        }
        return %orig;
    }
    - (_Bool)systemSupportsServiceType:(id)arg1 accountType:(int)arg2 {
        //I believe account type 0 is SMS PNR?

        if ([arg1 isEqualToString:@"iMessage"] && arg2 == 0) {
            //No idea if this actually works to ensure iMessage activates,
            //but I'm keeping it here just for safety
            return YES;
        }
        return %orig;
    }

    - (void)_SIMRemoved:(id)arg1 {
        NSLog(@"PNRGateway: Device tried to notify that SIM was removed, but we blocked it");
    }

%end

%hook IDSRegistration
    //This runs once PNR is done and it needs to finalize registration over HTTP
    - (NSString *) phoneNumber {
        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:@"/pnr_android_number.txt" encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            NSLog(@"PNRGateway: Error reading phone number from file: %@", error);
        }

        NSString *trimmedString = [fileContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        return trimmedString;
    };
    - (_Bool) canRegister {
        return YES;
    };

%end

%hook IDSPreflightMessage

    - (NSString *)_PLMN {
        NSLog(@"PNRGateway: Setting up preflight message with fake PLMN");
        %log;
        return DUMMY_PLMN; //TODO: Change the PLMN to a variable that can be anonymized
    }
    - (NSString *)_IMSI {
        NSLog(@"PNRGateway: Setting up preflight message with fake IMSI");
        %log;
        return DUMMY_IMSI;
    }

    - (NSString *)PLMN {
        NSLog(@"PNRGateway: Setting up preflight message with fake PLMN");
        %log;
        return DUMMY_PLMN;
    }
    - (NSString *)IMSI {
        NSLog(@"PNRGateway: Setting up preflight message with fake IMSI");
        %log;
        return DUMMY_IMSI;
    }

    - (NSArray *) responseMechanisms {
        NSLog(@"PNRGateway: Queried the responseMechanisms property");

        NSMutableDictionary *smsMechanism = [[NSMutableDictionary alloc] init];

        [smsMechanism setObject:@"SMS" forKey:@"mechanism"];

        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:@"/pnr_android_number.txt" encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            NSLog(@"PNRGateway: Error reading phone number from file: %@", error);
        }

        NSString *trimmedString = [fileContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];



        [smsMechanism setObject:trimmedString forKey:@"mechanism-data"];

        return @[smsMechanism];
    }


    /*

        For some reason, during the preflight request I sometimes ran into a
        mysterious error 6001 during testing. It's not clear why this error
        occurs and I haven't had it happen recently, but I'm keeping this
        code here for good luck. It's essentially a crude way of intercepting
        the error and pretending everything is all good.

    */

    - (NSNumber *) responseStatus {
        NSLog(@"PNRGateway: Queried the responseStatus property");

        NSNumber *origVal = %orig;
        if ([origVal isEqualToNumber:@6001]) {
            return @0; //Pretends that the preflight request worked (returns a 0 (success code) instead of 6001 (the mysterious error code))
        } else @autoreleasepool {
            return origVal;
        }
    }

    - (void)handleResponseDictionary:(id)arg1 {

        NSLog(@"PNRGateway: Got preflight response dictionary");
        %log;


        NSNumber *status = arg1[@"status"];
        if ([status isEqualToNumber:@(0)]) {
            NSLog(@"PNRGateway: Preflight request succeeded!");
            %orig;
        } else if ([status isEqualToNumber:@(6001)]) {
            NSLog(@"PNRGatway: Got error 6001, overriding...");

            //We're overriding the response to thwart error 6001!
            //    {
            //        mechanisms = (
            //            { mechanism = SMSLess; },
            //            { mechanism = SMS; "mechanism-data" = 28818773; }
            //        ); status = 0;
            //    }

            NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

            NSMutableDictionary *smsMechanism = [[NSMutableDictionary alloc] init];
            [smsMechanism setObject:@"SMS" forKey:@"mechanism"];
            [smsMechanism setObject:@"28818773" forKey:@"mechanism-data"];

            [dictionary setObject:@[smsMechanism] forKey:@"mechanisms"];
            [dictionary setObject:@0 forKey:@"status"];

            NSLog(@"Overriding with new dictionary: %@", dictionary);

            %log;
            %orig(dictionary);
        } else {
            NSLog(@"PNRGatway: No error 6001, continuing as normal...");
            %orig;
        }
    }

%end

%hook CTXPCClientHandler

    - (void)isPNRSupported:(id)subscriptionContext completion:(void (^)(id, SEL))originalHandler { //arg2 is a callback
        NSLog(@"PNRGate: Device checked if PNR was supported");
        originalHandler(@YES, nil);
    };

%end

%hook CTXPCServiceSubscriptionContext

    -(BOOL)isSimPresent {
        %log;
        return YES;
    };
    -(void)setIsSimPresent:(BOOL)arg1 {
        %log;
        %orig(YES);
    };

%end
