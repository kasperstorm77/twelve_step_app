Read the documentation and implementation plan + historic implementation. Familiarize yourself with the instructions and adhere to them. Fix/investigate the below, if bugs or issues are found when fixing/investigating, register them in the implementation plan to fix for later. Ensure to read the instruction on how to output text to me:

Fix this as per google recommendation:
Your app uses deprecated APIs or parameters for edge-to-edge
One or more of the APIs that you use or parameters that you set for edge-to-edge and window display have been deprecated in Android 15. Your app uses the following deprecated APIs or parameters:

android.view.Window.setStatusBarColor
android.view.Window.setNavigationBarColor
android.view.Window.setNavigationBarDividerColor
These start in the following places:

io.flutter.plugin.platform.PlatformPlugin.setSystemChromeSystemUIOverlayStyle
kotlin.io.path.PathTreeWalk$$ExternalSyntheticApiModelOutline0.m
To fix this, migrate away from these APIs or parameters.

User experience
Release name: 106 (2.2.13)

When done, make test releases for IOS - apple connect and android - play console