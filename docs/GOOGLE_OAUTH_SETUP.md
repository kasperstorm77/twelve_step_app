# Google OAuth Setup for Desktop App

## Quick Start Guide

To enable Google Drive sync on Windows/macOS/Linux, you need to create OAuth credentials in Google Cloud Console.

### Step 1: Create OAuth Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Select your project (or create a new one)
3. Click **"Create Credentials"** → **"OAuth client ID"**
4. Choose Application type: **"Desktop app"**
5. Give it a name (e.g., "4-Step Inventory Desktop")
6. Click **"Create"**

You'll get:
- **Client ID**: Something like `1234567890-abc123def456.apps.googleusercontent.com`
- **Client Secret**: Something like `GOCSPX-abc123def456`

### Step 2: Enable Google Drive API

1. In Google Cloud Console, go to **"APIs & Services"** → **"Library"**
2. Search for **"Google Drive API"**
3. Click **"Enable"**

### Step 3: Add Credentials to Your App

Open `lib/services/google_drive/desktop_drive_auth.dart` and replace:

```dart
static const String _clientId = 'YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com';
static const String _clientSecret = 'YOUR_CLIENT_SECRET';
```

With your actual credentials:

```dart
static const String _clientId = '1234567890-abc123def456.apps.googleusercontent.com';
static const String _clientSecret = 'GOCSPX-abc123def456';
```

### Step 4: Test the Flow

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

## Alternative: JSON Export/Import

If you prefer not to set up OAuth, you can still transfer data using JSON files:

1. **Mobile:** Export JSON → Save to cloud/USB
2. **Desktop:** Import JSON → Load from cloud/USB
3. Data transfers seamlessly!

Both approaches use the same JSON v2.0 format and are 100% compatible.
