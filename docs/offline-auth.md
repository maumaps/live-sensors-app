# Offline authentication behavior

The app stores the latest OpenID tokens in Flutter secure storage.
On startup it tries to refresh the stored refresh token.

Expected behavior:

- If refresh succeeds, the new tokens are saved and the app starts normally.
- If the phone is offline or the auth server is temporarily unavailable, the app
  keeps the restored session and starts in degraded offline mode.
- If Keycloak returns `invalid_grant`, the refresh token is no longer valid and
  the app clears the session.
- A stale access token on an API request should trigger one refresh and then
  retry the protected request with the new access token.

This distinction matters because field users can collect sensor data while
offline.
Network outages must not erase a valid session or force an unexpected login
screen.

Covered tests:

- `test/open_id_api_test.dart`
- `test/open_id_client_test.dart`
- `test/session_test.dart`
