import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart'
    show AccessDeniedException;
import 'package:twelvestepsapp/shared/services/google_drive/drive_auth_errors.dart';

/// Sync stuck on a dead token (found 2026-08-07).
///
/// A phone that was signed in, with sync on, had failed every upload for days:
///
///   Synkronisering fejlede: Access was denied (www-authenticate header was:
///   Bearer realm="https://accounts.google.com/", error="invalid_token").
///
/// The upload path *does* auto-heal an expired token — clear the auth cache,
/// re-mint, retry once — but only for errors it recognises. It matched on
/// substrings like `401`, `Invalid Credentials` and `PERMISSION_DENIED`, and
/// this message contains none of them: `googleapis_auth` throws
/// `AccessDeniedException`, whose `toString()` is the www-authenticate text.
/// So recovery never ran, the error was surfaced instead, and the token stayed
/// dead until someone signed out and in by hand. A finished morning ritual sat
/// on the device meanwhile.
void main() {
  // The exact text from the phone, including the Danish prefix the UI adds.
  const realWorldMessage =
      'Access was denied (www-authenticate header was: Bearer '
      'realm="https://accounts.google.com/", error="invalid_token").';

  group('the message that started this', () {
    test('the real AccessDeniedException is recoverable', () {
      expect(
        isRecoverableAuthError(AccessDeniedException(realWorldMessage)),
        isTrue,
        reason: 'this is the error that silently stopped syncing for days',
      );
    });

    test('its bare text is recoverable too', () {
      // It reaches some call sites already wrapped in another exception's
      // message, so type alone is not enough.
      expect(isRecoverableAuthError(realWorldMessage), isTrue);
      expect(
        isRecoverableAuthError('Upload failed: $realWorldMessage'),
        isTrue,
      );
    });
  });

  group('the markers that were already handled stay handled', () {
    for (final message in const [
      'DetailedApiRequestError(status: 401, message: Invalid Credentials)',
      'UNAUTHENTICATED',
      'Login Required',
      'insufficientPermissions',
      'insufficient authentication scopes',
      'ACCESS_TOKEN_SCOPE_INSUFFICIENT',
      'PERMISSION_DENIED',
    ]) {
      test('recoverable: ${_label(message)}', () {
        expect(isRecoverableAuthError(message), isTrue);
      });
    }
  });

  group('other token failures Google actually returns', () {
    for (final message in const [
      'error="invalid_token"',
      'invalid_grant',
      'Token has been expired or revoked.',
      'The access token has expired',
      'AccessDeniedException: Access was denied',
    ]) {
      test('recoverable: $message', () {
        expect(isRecoverableAuthError(message), isTrue);
      });
    }
  });

  group('what must NOT be treated as an auth problem', () {
    // Retrying these with a fresh token would just fail again, and worse,
    // would hide a real fault behind a token refresh.
    for (final message in const [
      'SocketException: Failed host lookup',
      'DetailedApiRequestError(status: 500, message: Internal Error)',
      'DetailedApiRequestError(status: 429, message: Rate Limit Exceeded)',
      'FormatException: Unexpected end of input',
      'The user denied access to the file',
      'Storage quota exceeded',
    ]) {
      test('not an auth error: ${_label(message)}', () {
        expect(isRecoverableAuthError(message), isFalse);
      });
    }

    test('null and empty are not auth errors', () {
      expect(isRecoverableAuthError(null), isFalse);
      expect(isRecoverableAuthError(''), isFalse);
    });
  });

  test('matching ignores case', () {
    expect(isRecoverableAuthError('invalid_TOKEN'), isTrue);
    expect(isRecoverableAuthError('access was DENIED'), isTrue);
  });
}

/// Test names must stay short without overflowing on a short message.
String _label(String message) =>
    message.length <= 34 ? message : '${message.substring(0, 34)}…';
