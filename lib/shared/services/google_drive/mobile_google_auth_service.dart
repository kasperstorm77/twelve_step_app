// --------------------------------------------------------------------------
// Mobile Google Authentication Service - Android/iOS Only
// --------------------------------------------------------------------------
// 
// PLATFORM SUPPORT: Android and iOS only
// This service depends on google_sign_in which is only available on mobile platforms.
// For desktop platforms (Windows/macOS/Linux), use desktop_drive_auth instead.
// 
// Usage: Only import and use this service when PlatformHelper.isMobile returns true.
// --------------------------------------------------------------------------

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'drive_config.dart';
import 'drive_crud_client.dart';

/// Handles Google Sign-In authentication for Drive access on mobile platforms
class MobileGoogleAuthService {
  final GoogleSignIn _googleSignIn;
  final GoogleDriveConfig _config;
  
  GoogleSignInAccount? _currentUser;
  String? _accessToken;

  MobileGoogleAuthService({required GoogleDriveConfig config})
      : _config = config,
        // Scopes MUST match the set requested by the interactive sign-in path
        // in data_management_tab_mobile.dart (['email', driveAppdataScope]).
        // If they diverge, signInSilently() on this instance can return null
        // even though the cached account from the tab is still valid, which
        // silently breaks background uploads.
        _googleSignIn = Platform.isIOS
            ? GoogleSignIn(
                scopes: ['email', config.scope],
                // iOS requires iOS OAuth client for Drive API access
                serverClientId: '628217349107-2u1kqe686mqd9a2mncfs4hr9sgmq4f9k.apps.googleusercontent.com',
              )
            : GoogleSignIn(scopes: ['email', config.scope]); // Android uses default (no serverClientId)

  /// Current authenticated user
  GoogleSignInAccount? get currentUser => _currentUser;
  
  /// Current access token
  String? get accessToken => _accessToken;
  
  /// Drive configuration
  GoogleDriveConfig get config => _config;
  
  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null && _accessToken != null;

  /// Stream of authentication state changes
  Stream<GoogleSignInAccount?> get onAuthStateChanged => 
      _googleSignIn.onCurrentUserChanged;

  /// Initialize and attempt silent sign-in
  Future<bool> initializeAuth() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _updateAuthState(account);
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Silent sign-in failed: $e');
    }
    return false;
  }

  /// Interactive sign-in
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _updateAuthState(account);
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Interactive sign-in failed: $e');
    }
    return false;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _accessToken = null;
  }

  /// Create authenticated Drive client
  Future<GoogleDriveCrudClient?> createDriveClient() async {
    if (!isSignedIn) return null;
    
    return GoogleDriveCrudClient.create(
      accessToken: _accessToken!,
      config: _config,
    );
  }

  /// Refresh access token if needed.
  ///
  /// If [_currentUser] is null we still try to recover the account via
  /// signInSilently() before giving up. This is the common case on Android:
  /// the interactive sign-in happens on a *different* GoogleSignIn instance
  /// (the Data Management tab) which only hands this service a one-shot access
  /// token via setExternalClientFromToken(). That token is hardcoded to a
  /// 59-minute expiry with no refresh token, so once it lapses every background
  /// upload 401s and lands here. Without recovering the account first, this
  /// returned false immediately and background sync died silently forever.
  Future<bool> refreshTokenIfNeeded() async {
    if (_currentUser == null) {
      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          // Evict the client-side token cache before reading. On Android
          // account.authentication can otherwise return the SAME stale token
          // that just 401'd, so the upload retry would immediately re-401.
          try {
            await account.clearAuthCache();
          } catch (_) {}
          await _updateAuthState(account);
          return _accessToken != null;
        }
      } catch (e) {
        if (kDebugMode) print('Token refresh: silent account recovery failed: $e');
      }
      return false;
    }

    try {
      // Drop the cached token first so authentication mints a fresh one rather
      // than handing back the expired token again.
      try {
        await _currentUser!.clearAuthCache();
      } catch (_) {}
      final auth = await _currentUser!.authentication;
      if (auth.accessToken != null) {
        _accessToken = auth.accessToken;
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Token refresh failed: $e');
    }
    return false;
  }

  /// Update internal auth state
  Future<void> _updateAuthState(GoogleSignInAccount account) async {
    _currentUser = account;
    
    final auth = await account.authentication;
    _accessToken = auth.accessToken;
    
    if (_accessToken == null) {
      throw Exception('Failed to get access token');
    }
  }

  /// Listen to auth state changes
  void listenToAuthChanges(void Function(GoogleSignInAccount?) callback) {
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      if (account != null) {
        await _updateAuthState(account);
      } else {
        _currentUser = null;
        _accessToken = null;
      }
      callback(account);
    });
  }
}