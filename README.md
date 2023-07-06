# SIMLessPNRGateway
[Public version] iMessage phone number registration on Android devices, but this time without requiring a separate SIM card!

Version 2 of [PNRGatewayTweak](https://github.com/AwesomeIndustry/PNRGatewayTweak) and [PNRGatewayClient](https://github.com/AwesomeIndustry/PNRGatewayClient) is here!

This tweak/Android app system allows you to register an Android phone number to iMessage! You'll need a jailbroken iPhone (I have a 5S on 12.5.7, results may vary by device and iOS version), but
it doesn't need to have its own SIM card anymore! This is more of a demo version, so there's still a fair amount of manual copy/pasting to/from the iPhone, Android phone, etc. If
you're interested in a standalone solution, PNRGateway Version 1 (linked above) requires you to have an active phone plan and SIM card in the iPhone (I used a cheap IoT SIM plan for $2ish/month), but
is more stable and will work automatically. Version 2 right now requires lots of manual copying/pasting, so it's more intended for use in an existing application
where you can send the data back and forth over the internet using something like Firebase or HTTP.

## How to get it working!

You'll need an iPhone 5S running iOS 12.5.7 (the lastest version as of writing). Other iPhones and versions may work but are untested.


You'll also need to have [PNRGatewayClientV2](https://github.com/AwesomeIndustry/PNRGatewayClientV2) installed on your Android phone, with notification and SMS permissions.


You'll also need a way to view your iPhone's logs. The Console app on Mac appears to be the easiest way to do that


It's also super helpful to have a quick way to send snippets of text between your computer and Android phone. Any messaging app installed on both will do just fine

1. Ensure FaceTime and iMessage are both turned off in the iPhone settings. Also make sure you're SSHed into your iPhone
2. Make sure your gateway address is set correctly in the Android app. This is the Apple phone number that your phone talks to to receive the SMS. This varies by carrier--on AT&T it's `28818773`, on T-Mobile MVNOs (like Google Fi) it's `22223333`, and on lots of other carriers it's `+447786205094`. If you're unsure, you can usually find it on your iPhone in `/System/Library/Carrier Bundles/iPhone/[your carrier]/carrier.bundle` under `PhoneNumberRegistrationGatewayAddress`.
3. Modify `ANDROID_PHONE_NUMBER` at the top of `pnrsender/Tweak.x` to your Android phone's number (in international format)
4. Install Theos and run `make package` inside both `pnrsender` and `receivepnr` and install the .deb to your device. You could also use `make package install` if Theos and your iPhone are set up with SSH
5. At this stage, I like to SSH into my iPhone and `killall identityservicesd` for good measure
6. Open the Console app on your Mac and filter for "PNRGateway". (All the log messages start with PNRGateway so it's easy to filter for them)
7. Open Settings on the iPhone and select "Messages". Switch iMessage on. If no log messages appear, `killall identityservicesd`, turn off iMessage, and try again.
8. In the Console app on your Mac, you should see a log message like `>>>> PNRGateway: Push Token Received!` Copy this entire log message and paste it into the PNRGatewayClientV2 Android app. Don't click Send just yet!
9. Make sure you can see a log message that says `>>>>> PNRGateway: Device tried to send SMS Identification!`. Once you can, click "Send REG-REQ SMS!" in the Android app
10. You should see a notification on your Android phone that says "REG-RESP Message Received!" Click Copy, which will copy the "REG-RESP?v=3..." message to your clipboard
11. On the SSH session on your computer, run `ReceivePNR "[REG-RESP message you copied earlier]"`, pasting in the REG-RESP message you copied on the Android phone
12. That's it! With a little luck, your iPhone should show your Android phone's number as registered for iMessage, and you should be able to send iMessages to your phone number while keeping your SIM in your Android phone!
