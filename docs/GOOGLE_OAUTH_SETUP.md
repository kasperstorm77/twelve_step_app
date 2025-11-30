# Google OAuth Setup

This document covers OAuth setup for **desktop platforms only** (Windows/macOS/Linux). Mobile (Android/iOS) platforms have OAuth already configured and working.

## Platform Status

- ✅ **Android**: OAuth configured via SHA-1 fingerprint + package name (no setup needed)
- ✅ **iOS**: OAuth configured via iOS client ID in code and Info.plist (no setup needed)
- ⚙️ **Windows**: Requires OAuth setup + URL protocol registration (this document)
- ⚙️ **macOS/Linux**: Requires manual OAuth setup (not implemented yet)

## Windows OAuth Setup

Windows uses **deep link OAuth** with custom URL protocol for automatic redirect handling.

### Step 1: Create OAuth Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Select your project (or create a new one)
3. Click **"Create Credentials"** → **"OAuth client ID"**
4. Choose Application type: **"Desktop app"** (NOT "Web application")
5. Give it a name (e.g., "12 Steps App - Windows")
6. Click **"Create"**

You'll get:
- **Client ID**: Something like `1234567890-abc123def456.apps.googleusercontent.com`
- **Client Secret**: Something like `GOCSPX-abc123def456`

### Step 2: Add Redirect URI

**CRITICAL**: Desktop OAuth clients need the custom URL scheme as a redirect URI.

1. Edit your Desktop OAuth client in Google Cloud Console
2. Add authorized redirect URI: **`twelvestepsapp://auth`**
3. Click **"Save"**

### Step 3: Enable Google Drive API

1. In Google Cloud Console, go to **"APIs & Services"** → **"Library"**
2. Search for **"Google Drive API"**
3. Click **"Enable"**

### Step 4: Add Credentials to Your App

Copy the template configuration file:

```bash
cp lib/shared/services/google_drive/desktop_oauth_config.dart.template \
   lib/shared/services/google_drive/desktop_oauth_config.dart
```

Open `lib/shared/services/google_drive/desktop_oauth_config.dart` and replace:

```dart
const String desktopOAuthClientId = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
const String desktopOAuthClientSecret = 'YOUR_CLIENT_SECRET';
```

With your actual credentials:

```dart
const String desktopOAuthClientId = '1234567890-abc123def456.apps.googleusercontent.com';
const String desktopOAuthClientSecret = 'GOCSPX-abc123def456';
```

**Note**: The file `desktop_oauth_config.dart` is gitignored for security. The template is tracked in git for reference.

### Step 5: Register Windows URL Protocol

Windows needs to know how to handle `twelvestepsapp://` URLs. See [`WINDOWS_URL_PROTOCOL.md`](WINDOWS_URL_PROTOCOL.md) for detailed instructions.

**Quick steps:**
1. Build the Windows app: `flutter build windows --release`
2. Run as Administrator: `windows\register_url_protocol.bat`

### Step 6: Test the Flow

1. Run the app on Windows: `flutter run -d windows`
2. Go to **Data Management** tab
3. Click **"Upload to Google Drive (Manual)"**
4. Browser opens → Sign in to Google
5. Grant permissions
6. Google shows authorization code
7. Copy the code
8. Paste into dialog in app
9. Click Submit
10. Data uploads to Drive!

## How It Works

### OAuth 2.0 Out-of-Band (OOB) Flow

This is the standard serverless OAuth flow for desktop apps:

```
┌─────────┐           ┌─────────┐           ┌────────────┐
│  User   │           │   App   │           │   Google   │
└────┬────┘           └────┬────┘           └─────┬──────┘
     │                     │                      │
     │  1. Click button    │                      │
     ├────────────────────►│                      │
     │                     │                      │
     │                     │  2. Open browser     │
     │                     │  with OAuth URL      │
     │                     ├─────────────────────►│
     │                     │                      │
     │  3. Sign in & authorize                    │
     ├───────────────────────────────────────────►│
     │                     │                      │
     │  4. Google shows code                      │
     │◄───────────────────────────────────────────┤
     │                     │                      │
     │  5. Copy code       │                      │
     ├──────┐              │                      │
     │      │              │                      │
     │◄─────┘              │                      │
     │                     │                      │
     │  6. Paste code      │                      │
     ├────────────────────►│                      │
     │                     │                      │
     │                     │  7. Exchange code    │
     │                     │  for access token    │
     │                     ├─────────────────────►│
     │                     │                      │
     │                     │  8. Return token     │
     │                     │◄─────────────────────┤
     │                     │                      │
     │                     │  9. Access Drive API │
     │                     ├─────────────────────►│
     │                     │                      │
     │  10. Success!       │  10. Upload data     │
     │◄────────────────────┤◄─────────────────────┤
```

### Why This Approach?

✅ **No local server** - Doesn't require opening ports or running localhost server
✅ **Secure** - Standard OAuth 2.0 flow approved by Google
✅ **Works anywhere** - No firewall or network configuration needed
✅ **User-friendly** - Clear visual flow with instructions

### Security Notes

- **Client ID & Secret**: These identify your app to Google, not your users
- **Safe to include in code**: For desktop/mobile apps, these are not secrets (unlike server apps)
- **User data protected**: Each user authorizes with their own Google account
- **Refresh tokens**: Stored locally, allows reconnection without re-auth

## Troubleshooting

### "Invalid client" error

**Cause:** Wrong client ID or secret

**Solution:**
1. Double-check you copied the full client ID and secret
2. Make sure you selected "Desktop app" not "Web application"

### "Access blocked" error

**Cause:** Google Drive API not enabled

**Solution:**
1. Go to Google Cloud Console
2. APIs & Services → Library
3. Search "Google Drive API"
4. Click Enable

### "redirect_uri_mismatch" error

**Cause:** Wrong redirect URI

**Solution:** We use `urn:ietf:wg:oauth:2.0:oob` which is correct for desktop apps. Make sure you're creating a **Desktop app** OAuth client, not a Web app.

### Browser doesn't open

**Cause:** No default browser or url_launcher issue

**Solution:**
1. Set a default web browser in Windows/macOS settings
2. Or copy the auth URL from console and open manually

## Mobile & Web Platforms

### Android
- **Already configured** - uses Android OAuth client
- **Authentication**: SHA-1 fingerprint + package name
- **No code changes needed** - works out of the box
- **Setup required**: Register your debug SHA-1 in Google Cloud Console (see `docs/LOCAL_SETUP.md`)

### iOS
- **Already configured** - uses iOS OAuth client
- **Client ID**: `628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k.apps.googleusercontent.com`
- **Configured in**: `lib/shared/services/google_drive/mobile_google_auth_service.dart` (serverClientId)
- **Also in**: `ios/Runner/Info.plist` (GIDClientID and CFBundleURLSchemes)
- **No code changes needed** - works out of the box

### Web
- **Already configured** - uses Web OAuth client
- **Client ID**: `628217349107-5d4fmt92g4pomceuedgsva1263ms9lir.apps.googleusercontent.com`
- **Configured in**: `web/index.html` (meta tag: `google-signin-client_id`)
- **Authentication**: OAuth2 browser flow via `google_sign_in` package
- **No code changes needed** - works out of the box
- **Run with**: `flutter run -d chrome`

All three platforms have full Google Drive sync functionality without any setup required (beyond registering your debug SHA-1 for Android development).
