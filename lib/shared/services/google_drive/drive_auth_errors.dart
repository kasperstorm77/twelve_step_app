/// Is this Drive failure one a fresh token would fix?
///
/// The upload path auto-heals an expired token: clear the auth cache, re-mint
/// via `signInSilently()`, retry once. That only helps for errors it actually
/// recognises, and the recognition used to be an inline substring list built
/// from `DetailedApiRequestError` messages — `401`, `Invalid Credentials`,
/// `PERMISSION_DENIED` and friends.
///
/// A real phone sat for days failing every upload with:
///
///     Access was denied (www-authenticate header was: Bearer
///     realm="https://accounts.google.com/", error="invalid_token").
///
/// That is `AccessDeniedException` from `googleapis_auth`, a different type
/// whose `toString()` is the raw www-authenticate text. It contains none of the
/// old markers, so the recovery never ran, the raw message was shown instead,
/// and syncing stayed dead until the user signed out and back in by hand. Work
/// finished on the device in the meantime never left it.
///
/// Kept deliberately narrow. Treating a network blip or a 500 as an auth
/// problem would burn a token refresh on every transient failure and hide the
/// real fault behind it, so only markers that genuinely mean "this credential
/// is no good" belong here.
library;

/// Substrings that mean the credential is stale, revoked or wrongly scoped.
///
/// Matched case-insensitively against the exception's `toString()`, because
/// these arrive both as typed exceptions and as text already wrapped in
/// another error's message ("Upload failed: ...").
const _authErrorMarkers = <String>[
  // googleapis_auth AccessDeniedException — the one that was missed.
  'access was denied',
  'invalid_token',
  // OAuth token endpoint failures.
  'invalid_grant',
  'token has been expired or revoked',
  'access token has expired',
  // DetailedApiRequestError / transport variants that were already handled.
  '401',
  'unauthenticated',
  'invalid credentials',
  'login required',
  // Scope problems: a token minted before the scope-align fix can lack
  // drive.appdata. Clearing the cache and re-minting recovers a correct one.
  'insufficientpermissions',
  'insufficient authentication scopes',
  'access_token_scope_insufficient',
  'permission_denied',
];

/// True when [error] should trigger a token refresh and one retry.
///
/// Accepts an exception or a string; anything else is stringified, so both a
/// caught object and an already-wrapped message classify the same way.
bool isRecoverableAuthError(Object? error) {
  if (error == null) return false;
  final message = error.toString().toLowerCase();
  if (message.isEmpty) return false;
  return _authErrorMarkers.any(message.contains);
}
