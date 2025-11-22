import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Simple platform detection helper for conditional code execution.
/// Import this anywhere you need platform-specific code:
/// ```dart
/// import 'package:twelvestepsapp/shared/utils/platform_helper.dart';
/// 
/// if (PlatformHelper.isAndroid) {
///   // Android-specific code
/// } else if (PlatformHelper.isWindows) {
///   // Windows-specific code
/// }
/// ```
class PlatformHelper {
  // Prevent instantiation
  PlatformHelper._();

  /// Returns true if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Returns true if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Returns true if running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Returns true if running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Returns true if running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Returns true if running on Web
  static bool get isWeb => kIsWeb;

  /// Returns true if running on any mobile platform (Android or iOS)
  static bool get isMobile => isAndroid || isIOS;

  /// Returns true if running on any desktop platform (Windows, macOS, or Linux)
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Returns a platform name string for debugging/logging
  static String get platformName {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  /// Execute platform-specific code
  static T when<T>({
    required T Function() fallback,
    T Function()? android,
    T Function()? iOS,
    T Function()? windows,
    T Function()? macOS,
    T Function()? linux,
    T Function()? web,
    T Function()? mobile,
    T Function()? desktop,
  }) {
    if (mobile != null && isMobile) return mobile();
    if (desktop != null && isDesktop) return desktop();
    if (android != null && isAndroid) return android();
    if (iOS != null && isIOS) return iOS();
    if (windows != null && isWindows) return windows();
    if (macOS != null && isMacOS) return macOS();
    if (linux != null && isLinux) return linux();
    if (web != null && isWeb) return web();
    return fallback();
  }
}
