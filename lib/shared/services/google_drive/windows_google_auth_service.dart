// --------------------------------------------------------------------------
// Windows Google Authentication Service - Windows Only
// --------------------------------------------------------------------------
// 
// PLATFORM SUPPORT: Windows only
// This service provides automatic OAuth with credential caching,
// similar to the mobile google_sign_in experience.
// 
// Features:
// - Deep link OAuth redirect (native Windows URL scheme)
// - Secure credential caching in Hive
// - Silent sign-in support
// - Automatic token refresh
// 
// Usage: Only import and use when PlatformHelper.isWindows returns true.
// --------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'desktop_oauth_config.dart';
import 'drive_config.dart';
import 'drive_crud_client.dart';

/// Windows-specific Google authentication service
/// Provides automatic OAuth with credential caching
class WindowsGoogleAuthService {
  // OAuth credentials from desktop_oauth_config.dart
  static const String _clientId = desktopOAuthClientId;
  static const String _clientSecret = desktopOAuthClientSecret;
  
  final GoogleDriveConfig _config;
  final Box _credentialsBox;
  final AppLinks _appLinks = AppLinks();
  
  auth.AccessCredentials? _credentials;
  StreamSubscription<Uri>? _linkSubscription;
  Completer<String?>? _authCompleter;
  
  static const String _credentialsKey = 'windows_google_credentials';
  static const String _redirectScheme = 'twelvestepsapp';

  WindowsGoogleAuthService({
    required GoogleDriveConfig config,
    required Box credentialsBox,
  })  : _config = config,
        _credentialsBox = credentialsBox;

  /// Current access token
  String? get accessToken => _credentials?.accessToken.data;
  
  /// Get drive config
  GoogleDriveConfig get config => _config;
  
  /// Check if user is signed in
  bool get isSignedIn => _credentials != null && !_isTokenExpired();
  
  /// Check if user has cached credentials (even if expired)
  bool get hasCachedCredentials => _credentialsBox.containsKey(_credentialsKey);

  /// Initialize and attempt silent sign-in from cached credentials
  Future<bool> initializeAuth() async {
    try {
      // Try to load cached credentials
      final cached = _credentialsBox.get(_credentialsKey);
      if (cached != null) {
        _credentials = _deserializeCredentials(cached);
        
        // Check if token is expired and refresh if needed
        if (_isTokenExpired() && _credentials!.refreshToken != null) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            await _cacheCredentials();
            return true;
          }
        } else if (!_isTokenExpired()) {
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Silent sign-in failed: $e');
      _credentials = null;
    }
    return false;
  }

  /// Interactive sign-in with automatic OAuth flow using deep links
  Future<bool> signIn() async {
    try {
      // Set up deep link listener
      _authCompleter = Completer<String?>();
      
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        if (kDebugMode) print('Deep link received: $uri');
        
        if (uri.scheme == _redirectScheme && uri.host == 'auth') {
          final code = uri.queryParameters['code'];
          if (code != null && !_authCompleter!.isCompleted) {
            _authCompleter!.complete(code);
          }
        }
      });

      // Build OAuth URL with custom scheme redirect
      final redirectUri = '$_redirectScheme://auth';
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _config.scope,
        'access_type': 'offline',
        'prompt': 'consent', // Force consent to get refresh token
      });

      // Open browser for user to authenticate
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch browser');
      }

      // Wait for OAuth callback with timeout
      final code = await _authCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => null,
      );

      // Clean up listener
      await _linkSubscription?.cancel();
      _linkSubscription = null;
      _authCompleter = null;

      if (code == null) {
        return false; // Timeout or user cancelled
      }

      // Exchange code for tokens
      final success = await _exchangeCodeForTokens(code, redirectUri);
      if (success) {
        await _cacheCredentials();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('Interactive sign-in failed: $e');
      
      // Clean up on error
      await _linkSubscription?.cancel();
      _linkSubscription = null;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.complete(null);
      }
      _authCompleter = null;
      
      return false;
    }
  }

  /// Sign out and clear cached credentials
  Future<void> signOut() async {
    _credentials = null;
    await _credentialsBox.delete(_credentialsKey);
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    if (kDebugMode) print('Windows OAuth: Signed out');
  }

  /// Create authenticated Drive client
  Future<GoogleDriveCrudClient?> createDriveClient() async {
    if (!isSignedIn) return null;
    
    // Refresh token if expired
    if (_isTokenExpired() && _credentials!.refreshToken != null) {
      await _refreshAccessToken();
    }
    
    return GoogleDriveCrudClient.create(
      accessToken: _credentials!.accessToken.data,
      config: _config,
    );
  }

  /// Refresh access token if needed
  Future<bool> refreshTokenIfNeeded() async {
    if (_credentials == null || _credentials!.refreshToken == null) {
      return false;
    }
    
    if (_isTokenExpired()) {
      return await _refreshAccessToken();
    }
    
    return true;
  }

  /// Exchange authorization code for tokens
  Future<bool> _exchangeCodeForTokens(String code, String redirectUri) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Token exchange failed: ${response.statusCode} ${response.body}');
        }
        return false;
      }

      final tokens = json.decode(response.body) as Map<String, dynamic>;
      
      _credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          tokens['access_token'] as String,
          DateTime.now().toUtc().add(
            Duration(seconds: tokens['expires_in'] as int? ?? 3600),
          ),
        ),
        tokens['refresh_token'] as String?,
        [_config.scope],
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('Token exchange error: $e');
      return false;
    }
  }

  /// Refresh the access token using refresh token
  Future<bool> _refreshAccessToken() async {
    if (_credentials?.refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': _credentials!.refreshToken!,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Token refresh failed: ${response.statusCode} ${response.body}');
        }
        return false;
      }

      final tokens = json.decode(response.body) as Map<String, dynamic>;
      
      // Update credentials with new access token (keep existing refresh token)
      _credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          tokens['access_token'] as String,
          DateTime.now().toUtc().add(
            Duration(seconds: tokens['expires_in'] as int? ?? 3600),
          ),
        ),
        _credentials!.refreshToken, // Keep existing refresh token
        [_config.scope],
      );

      await _cacheCredentials();
      return true;
    } catch (e) {
      if (kDebugMode) print('Token refresh error: $e');
      return false;
    }
  }

  /// Check if access token is expired
  bool _isTokenExpired() {
    if (_credentials?.accessToken == null) return true;
    
    final expiry = _credentials!.accessToken.expiry;
    final now = DateTime.now().toUtc();
    
    // Consider expired if less than 5 minutes remaining
    return expiry.difference(now).inMinutes < 5;
  }

  /// Cache credentials securely in Hive
  Future<void> _cacheCredentials() async {
    if (_credentials == null) return;
    
    final serialized = _serializeCredentials(_credentials!);
    await _credentialsBox.put(_credentialsKey, serialized);
  }

  /// Serialize credentials to Map for storage
  Map<String, dynamic> _serializeCredentials(auth.AccessCredentials creds) {
    return {
      'access_token': creds.accessToken.data,
      'token_type': creds.accessToken.type,
      'expiry': creds.accessToken.expiry.toIso8601String(),
      'refresh_token': creds.refreshToken,
      'scopes': creds.scopes,
    };
  }

  /// Deserialize credentials from storage
  auth.AccessCredentials _deserializeCredentials(Map<dynamic, dynamic> data) {
    return auth.AccessCredentials(
      auth.AccessToken(
        data['token_type'] as String,
        data['access_token'] as String,
        DateTime.parse(data['expiry'] as String),
      ),
      data['refresh_token'] as String?,
      List<String>.from(data['scopes'] as List),
    );
  }
}
