# 🔥 Firebase Setup Guide for Icebreaker

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project" 
3. Name it "Icebreaker"
4. Enable Google Analytics (recommended)
5. Choose your Analytics account

## Step 2: Add iOS App to Firebase

1. In Firebase Console, click "Add app" → iOS
2. Bundle ID: `com.simondoku.Icebreaker` (or your current bundle ID)
3. App nickname: `Icebreaker iOS`
4. Download `GoogleService-Info.plist`
5. **Important**: Add this file to your Xcode project

## Step 3: Add Firebase SDK to Xcode

1. Open `Icebreaker.xcodeproj` in Xcode
2. Select your project in the navigator
3. Go to **Package Dependencies** tab
4. Click the **+** button
5. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
6. Click "Add Package"
7. Select these Firebase products:
   - ✅ **FirebaseAuth** (Authentication)
   - ✅ **FirebaseFirestore** (Database)
   - ✅ **FirebaseStorage** (File storage)
   - ✅ **FirebaseMessaging** (Push notifications)
8. Click "Add Package"

## Step 4: Add GoogleService-Info.plist

1. Drag the downloaded `GoogleService-Info.plist` into your Xcode project
2. Make sure "Add to target" is checked for your main app target
3. The file should appear in your project navigator

## Step 5: Initialize Firebase

Add this to your main app file (we'll do this next):

```swift
import FirebaseCore

@main
struct IcebreakerApp: App {
    init() {
        FirebaseApp.configure()
    }
    // ...rest of code
}
```

## Step 6: Enable Firebase Services in Console

### Authentication
1. Go to Authentication → Sign-in method
2. Enable **Email/Password**

### Firestore Database  
1. Go to Firestore Database → Create database
2. Start in **test mode**
3. Choose region (us-central1 recommended)

### Storage
1. Go to Storage → Get started
2. Start in **test mode**

## Step 7: Update Info.plist Permissions

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Icebreaker uses your location to find people nearby</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Icebreaker uses location to help you discover compatible people</string>
```

## Next Steps

Once Firebase SDK is added, we'll:
1. Replace AuthManager with FirebaseAuthManager
2. Update MatchEngine to use Firestore
3. Add real-time chat functionality
4. Implement push notifications

## Troubleshooting

- **"No such module 'FirebaseCore'"** → Firebase SDK not added to project
- **"GoogleService-Info.plist not found"** → File not added to Xcode project
- **Build errors** → Clean build folder (Cmd+Shift+K) and rebuild
