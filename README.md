# SIMLessPNRGateway
[Public version] iMessage phone number registration on Android devices, without a separate SIM card! Special thanks to [itsjunetime](https://github.com/itsjunetime) and [ericmigi](https://gist.github.com/ericmigi) for Objective-C help and advice!

Also, if you need a version for 10.x, 9.x, 8.x, or 7.x, check out [VintagePNR](https://github.com/AwesomeIndustry/VintagePNR), which does
the same thing as SIMLessPNRGateway, but for these older iOS versions. 8.x and 7.x might take some minor tweaking to work, but I've
tested it on 10.3.3 and it works great.

This is version 2 of the older [PNRGatewayTweak](https://github.com/AwesomeIndustry/PNRGatewayTweak) and [PNRGatewayClient](https://github.com/AwesomeIndustry/PNRGatewayClient).

This tweak/Android app system allows you to register an Android phone number to iMessage! You'll need a jailbroken iPhone (I have a 5S on 12.5.7, results may vary by device and iOS version), but
it doesn't need to have its own SIM card anymore! This is more of a demo version, so there's still a fair amount of manual copy/pasting to/from the iPhone, Android phone, etc. If
you're interested in a standalone solution, PNRGateway Version 1 (linked above) requires you to have an active phone plan and SIM card in the iPhone (I used a cheap IoT SIM plan for $2ish/month), but
is more stable and will work automatically. Version 2 right now requires lots of manual copying/pasting, so it's more intended for use in an existing application
where you can send the data back and forth over the internet using something like Firebase or HTTP.

## How to build SIMLessPNRGateway

1. [Install theos](https://theos.dev/docs/installation) if you haven't already
2. [Install MRYIPC for Theos](https://github.com/Muirey03/MRYIPC) following the first step under "How to use": (copy `MRYIPCCenter.h` to `$THEOS/include` and `usr/lib/libmryipc.dylib` to `$THEOS/lib`)
3. `cd` into the project directory
4. Run `make package`. This creates a `.deb` file in the `packages` directory--transfer that to your iOS device and install it.
5. Alternatively to step (3), if you have SSH enabled on your iPhone, open the Makefile and change `THEOS_DEVICE_IP` to your iPhone's IP Address, and then run `make package install`. You'll have to enter your iPhone password twice (the default password is alpine)

## How to use/test SIMLessPNRGateway

You'll need an iPhone 5S running iOS 12.5.7 (the lastest version as of writing). Other iPhones and versions may work but are untested.


You'll also need to have [PNRGatewayClientV2](https://github.com/AwesomeIndustry/PNRGatewayClientV2) installed on your Android phone, with notification and SMS permissions.


You'll also need a way to view your iPhone's logs. The Console app on Mac appears to be the easiest way to do that


It's also super helpful to have a quick way to send snippets of text between your computer and Android phone. Any messaging app installed on both will do just fine

1. Ensure FaceTime and iMessage are both turned off in the iPhone settings. Also make sure you're SSHed into your iPhone
2. On your iPhone, make a text file in the root directory: `/pnr_android_number.txt`, and set its contents to your Android phone's number in international format (ex. `+11234567890`)
3. Make sure your gateway address is set correctly in the Android app. This is the Apple phone number that your phone talks to to receive the SMS. This varies by carrier--on AT&T it's `28818773`, on T-Mobile MVNOs (like Google Fi) it's `22223333`, and on lots of other carriers it's `+447786205094`. If you're unsure, you can usually find it on your iPhone in `/System/Library/Carrier Bundles/iPhone/[your carrier]/carrier.bundle` under `PhoneNumberRegistrationGatewayAddress`.
4. Modify `ANDROID_PHONE_NUMBER` at the top of `pnrsender/Tweak.x` to your Android phone's number (in international format)
5. Install Theos and run `make package` inside both `pnrsender` and `receivepnr` and install the .deb to your device. You could also use `make package install` if Theos and your iPhone are set up with SSH
6. At this stage, I like to SSH into my iPhone and `killall identityservicesd` for good measure
7. Open the Console app on your Mac and filter for "PNRGateway". (All the log messages start with PNRGateway so it's easy to filter for them)
8. Open Settings on the iPhone and select "Messages". Switch iMessage on. If no log messages appear, `killall identityservicesd`, turn off iMessage, and try again.
9. In the Console app on your Mac, you should see a log message like `>>>> PNRGateway: Push Token Received!` Copy this entire log message and paste it into the PNRGatewayClientV2 Android app. Don't click Send just yet!
10. Make sure you can see a log message that says `>>>>> PNRGateway: Device tried to send SMS Identification!`. Once you can, click "Send REG-REQ SMS!" in the Android app
11. You should see a notification on your Android phone that says "REG-RESP Message Received!" Click Copy, which will copy the "REG-RESP?v=3..." message to your clipboard
12. On the SSH session on your computer, run `ReceivePNR "[REG-RESP message you copied earlier]"`, pasting in the REG-RESP message you copied from the Android phone
13. That's it! With a little luck, your iPhone should show your Android phone's number as registered for iMessage, and you should be able to send iMessages to your phone number while keeping your SIM in your Android phone!

## How it works

If you'd like to understand how the phone number registration process works, I highly recommend reading my write-up of how the original [PNRGateway](https://github.com/AwesomeIndustry/PNRGatewayTweak) worked, as it has lots of background of how the iMessage registration system works.

Basically, version 1 modified `IDSPhoneNumberValidationStateMachine` (among other libraries) on the iPhone such that it sends the `REG-REQ` SMS first to the Android phone, before the Android phone sends it off to Apple's registration phone number. This would cause Apple to see the iPhone's request SMS as originating from the Android phone's number, thus tricking the iPhone into registering for iMessage on the Android phone's number.

SIMLessPNRGateway essentially does the same thing, except it's modified such that the iPhone can still register without a SIM card in it at all.
Most of the code in the tweak is just overriding lots of methods in identityservicesd to convince the iPhone it has a SIM card in it, but here's how the actual registration process differs from that of Version 1--it involves a much deeper understanding of the contents of the `REG-REQ` and `REG-RESP` SMS messages

1. The iPhone skips the preflight entirely--A call to `- (void)_sendPreflightVerificationIfNeeded` will now just start the SMS registration process with `[self _sendSMSVerificationWithMechanism:nil];`
2. Instead of the iPhone sending the SMS itself, we extract the push token and generate the `REG-REQ` SMS on the Android side.
    1. The REG-REQ message has the format `REG-REQ?v=3;t=76AAFD15711EF157CF1B8F90FAF21B561CB12EFCE9DE861D8AAE6816CF4A8A71;r=8875166862`
    2. The `v=3` indicates the version of Phone Number Registration to use. On my iPhone it's always 3, on older phones it might use an older version
    3. The `t=76AA...` is the iMessage push token of your device. This is how Apple identifies your device on the iMessage network. It acts a lot like a "shell" user ID that your phone numbers/emails/etc are attached to. Thus, when others type your phone number or email into their iPhone, it'll look up your push token in Apple's big database and send an iMessage to it.
    4. The `r=` is the request number (the REG-RESP message will contain a matching number). Appears to be random--the PNRGatewayClientV2 Android app just generates this randomly and that appears to be fine
3. The Android phone receives the `REG-RESP` SMS from Apple
    1. In version 1 of PNRGateway, it just sends this back via SMS so the iPhone can process it. In version 2 this isn't possible (the iPhone can't receive SMS message anymore), so it just shows a notification and leaves transporting the SMS as an exercise to the user. If you're integrating this into an app, of course, you'll want to use some sort of push notification delivery system to send this over the internet. (Adding push notification support into the tweak was out of the scope of this proof-of-concept, but I wish you the best of luck!)
    2. The `ReceivePNR` .deb is just a command-line tool. There's no technical requirement for it to be a spearate tweak (and if you're integrating push notifications it'll probably make more sense to just make one), but I split it out as a separate command line tool to make it easy to paste in the REG-RESP message over SSH.
    3. Also, some fun information about the contents of the REG-RESP message!
        1. The REG-RESP message has this format: `REG-RESP?v=3;r=72325403;n=+11234567890;s=CA21C50C645469B25F4B65C38A7DCEC56592E038F39489F35C7CD6972D`
        2. The `v=3` is the version number, just like in the REG-REQ message
        3. The `r=72327403` is the request number, which is exactly the same as in the REG-REQ message
        4. The `n=+11234567890` is the phone number Apple thinks you have. In this example it's `+1 (123) 456-7890`
        5. The `s=CA21C5...` is a digital signature, which is how Apple verifies that your phone number and push token are linked. **Apple appears to be running a certificate authority over SMS, where it signs push tokens alongside the phone number they come from (which is just bonkers).**
 
That's about it as far as major technical differences go--most of the rest of the tweak is just playing whack-a-mole on which methods tell identityservicesd whether it has an active SIM in the phone or not, as well as a little state modification so the iPhone is able to accept the REG-RESP SMS when we pipe it in. I tried to put in some helpful block comments throughout the tweak, so hopefully those will make sense.

## Registration Stages

I also learned a little bit about the different stages of registration. If you've [unredacted the iOS logs](https://github.com/EthanArbuckle/unredact-private-os_logs), you should see lots of log messages displaying a registration info that looks like this: 

```
Registration info (0x1013cd720): [Status: Waiting for Authentication Response] [Type: Phone Number]...
```

There are five different statuses that I've observed

| Status      | Description |
| ----------- | ----------- |
| Unregistered      | Device has not sent the registration SMS. The preflight message is part of this stage       |
| Waiting for Authentication Response   | The SMS message has been sent and the device is waiting for a REG-RESP response        |
| Authenticated   | The iPhone has received the REG-RESP SMS with the digitally signed phone number and push token, but has not applied to be in Apple's iMessage database. In this stage, your iPhone has a signature for its own phone number, but Apple's database doesn't have it yet.         |
| HTTP Registering   | The device sends its signature to Apple to add itself to Apple’s database of registered iMessage users        |
| Registered   | Apple accepts the signature as valid and you're now active on the iMessage network        |


I hope this was at least a little helpful. Happy hacking!
