# Register Custom URL Protocol for Windows OAuth Deep Links

After building the Windows app, you need to register the custom URL protocol so Windows can redirect OAuth callbacks to your app.

## Registration Steps:

### Option 1: Automatic (Recommended)

1. Build your app in Release mode:
   ```powershell
   flutter build windows --release
   ```

2. Run the registration script as Administrator:
   ```powershell
   # Right-click and "Run as Administrator"
   windows\register_url_protocol.bat
   ```

### Option 2: Manual Registry Edit

If you prefer to manually register the protocol:

1. Open Registry Editor (regedit)
2. Navigate to `HKEY_CURRENT_USER\Software\Classes`
3. Create a new key called `twelvestepsapp`
4. Set the default value to: `URL:Twelve Steps App Protocol`
5. Create a string value `URL Protocol` with empty data
6. Create subkey: `twelvestepsapp\DefaultIcon`
   - Set default value to: `C:\path\to\twelvestepsapp.exe,0`
7. Create subkey: `twelvestepsapp\shell\open\command`
   - Set default value to: `"C:\path\to\twelvestepsapp.exe" "%1"`

## How It Works:

- When Google redirects to `twelvestepsapp://auth?code=xyz`, Windows looks up the protocol in the registry
- Windows launches your app with the URL as a command-line argument
- The `app_links` package captures this and triggers the OAuth flow completion

## Testing:

After registration, test the deep link:

```powershell
start twelvestepsapp://auth?code=test123
```

This should launch your app.

## Google Cloud Console Setup:

Update your OAuth client redirect URI to:
```
twelvestepsapp://auth
```

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Edit your Desktop OAuth client
3. Add authorized redirect URI: `twelvestepsapp://auth`
