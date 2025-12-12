# Testing Phone Authentication in iOS Simulator

## Overview
Firebase Phone Authentication works in the iOS Simulator using **test phone numbers** that bypass real SMS. This is the recommended way to test phone authentication during development.

## Setup Steps

### 1. Configure Test Phone Numbers in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method** → **Phone**
4. Scroll down to the **Phone numbers for testing** section
5. Click **Add phone number**
6. Add test phone numbers in E.164 format (e.g., `+12055551234`)
7. **Important**: The verification code for ALL test numbers is always `123456`

### 2. Recommended Test Phone Numbers

Add these test numbers to Firebase Console:
- `+12055551001`
- `+12055551002`
- `+12055551003`
- `+12055551004`

These will work in the simulator without sending real SMS.

### 3. Run the App in Simulator

1. Open Xcode
2. Select an iOS Simulator (iPhone 15 Pro recommended)
3. Build and run the app (⌘R)

### 4. Testing the Phone Auth Flow

#### Step 1: Enter Phone Number
- When the app launches, you'll see the `PhoneAuthView`
- Enter one of your test phone numbers (e.g., `2055551001`)
- The app will auto-format it as `(205) 555-1001`
- Tap **Continue**

#### Step 2: Enter Verification Code
- You'll be taken to `SMSVerificationView`
- **Enter the code: `123456`** (this is the universal test code for all test numbers)
- The app will auto-verify when you enter 6 digits
- You should be successfully authenticated!

### 5. Testing Multiple Users

To test with different phone numbers:
1. Sign out from Settings (if you have a sign-out option)
2. Or delete the app and reinstall
3. Use different test phone numbers you configured in Firebase Console
4. Always use `123456` as the verification code

## Important Notes

### ⚠️ Simulator Limitations
- **Real SMS will NOT work** in the simulator
- You **must** use test phone numbers configured in Firebase Console
- The verification code is **always `123456`** for test numbers

### ✅ Production Testing
- For production testing, use a real device
- Real SMS will be sent to actual phone numbers
- Real verification codes will be received via SMS

### 🔍 Debugging Tips

1. **Check Console Logs**: Look for these log messages:
   - `📱 [AUTH] Sending verification code to: ...`
   - `✅ [AUTH] Verification code sent successfully`
   - `🔐 [AUTH] Verifying code...`
   - `✅ [AUTH] Successfully signed in: ...`

2. **Common Issues**:
   - **"Failed to send verification code"**: Make sure the phone number is added as a test number in Firebase Console
   - **"Invalid verification code"**: Make sure you're using `123456` (not a real SMS code)
   - **reCAPTCHA not showing**: This is normal for test numbers - they bypass reCAPTCHA

3. **View Logs in Xcode**:
   - Open the Console (⌘⇧Y)
   - Filter by "AUTH" to see authentication logs

## Quick Test Checklist

- [ ] Added test phone numbers to Firebase Console
- [ ] Built and run app in simulator
- [ ] Entered test phone number (e.g., `2055551001`)
- [ ] Entered verification code `123456`
- [ ] Successfully authenticated
- [ ] Can see main app interface
- [ ] User document created in Firestore

## Testing Different Scenarios

### Test 1: New User Flow
1. Use a test phone number that hasn't been used before
2. Complete phone authentication
3. Complete onboarding
4. Verify user document exists in Firestore

### Test 2: Returning User Flow
1. Use a test phone number that was previously authenticated
2. Should authenticate immediately
3. Should skip to main app (if onboarding was completed)

### Test 3: Invalid Code
1. Enter a test phone number
2. Enter an incorrect code (e.g., `000000`)
3. Should show error message
4. Can resend code and try again

### Test 4: Phone Number Formatting
1. Test various input formats:
   - `2055551001` (10 digits)
   - `(205) 555-1001` (formatted)
   - `12055551001` (with country code)
2. All should normalize correctly

## Firebase Console Location

The test phone numbers are configured at:
```
Firebase Console → Your Project → Authentication → Sign-in method → Phone → Phone numbers for testing
```

## Need Help?

If you encounter issues:
1. Check Firebase Console to ensure test numbers are added
2. Verify `GoogleService-Info.plist` is in the project
3. Check Xcode console for error messages
4. Ensure you're using the correct verification code: `123456`
