# Runtime token refresh

## Problem

The mobile app refreshes an expired access token only during `AuthController.initialize()`. While the app remains open, feature clients continue sending the access token captured from the stored session. After a long period of inactivity, HTTP calls return `401`, and SignalR automatic reconnect can reuse the same expired token. The user remains visually authenticated but must log out and log in again to recover.

## Desired behavior

Every authenticated operation must obtain a valid access token before it starts. If a request still receives `401`, the app must force one token refresh and retry that request exactly once. A failed refresh ends the local session and returns the app to the login flow. Other failures retain their existing handling.

## Design

### Session coordinator

`AuthController` remains the source of truth for tokens and authenticated state. It will expose an asynchronous method that returns a usable access token:

- return the current access token when it remains valid beyond the existing one-minute safety window;
- refresh before returning when the token is near expiry;
- support a forced refresh after an unexpected `401`;
- share one in-flight refresh future across concurrent callers so rotating refresh tokens are not submitted more than once;
- persist successful token rotation and notify listeners;
- clear stored tokens and transition to `unauthenticated` when refresh fails.

The method will return no token after refresh failure. Callers must not send or retry the protected request in that case.

### Authenticated HTTP transport

A shared `http.BaseClient` wrapper will be used by all feature API clients, while `AuthApiClient` keeps a separate underlying client to avoid refresh recursion.

For requests containing a bearer authorization header, the wrapper will:

1. obtain a valid token from `AuthController` and replace the outgoing bearer value;
2. send the request once;
3. on `401`, drain the response, force a refresh, rebuild the request, and retry once with the new token;
4. return the second response unchanged, including a second `401`, without entering another refresh loop.

Unauthenticated requests pass through unchanged. The wrapper only supports replaying request types used by the current feature clients; request metadata and body bytes must be preserved exactly.

### SignalR

The realtime connection will use an asynchronous token provider instead of capturing a token string at connection creation. The provider delegates to `AuthController`, allowing the initial handshake and automatic reconnect to obtain a current access token. If refresh fails, connection establishment fails and the authentication state already transitions to `unauthenticated`.

### Composition

`main.dart` will construct objects in this order:

1. raw auth HTTP client and `AuthApiClient`;
2. `AuthController`;
3. session-aware authenticated HTTP client;
4. feature API clients using that authenticated client;
5. SignalR client factory using the asynchronous token provider.

Existing feature controllers and API result types remain unchanged. They continue passing their current token argument, but the shared transport replaces stale bearer values immediately before sending.

## Error handling

- Expired or nearly expired access token: refresh before the protected request.
- Unexpected first `401`: one forced refresh and one retry.
- Failed refresh: clear local tokens and show the login flow.
- Second `401`: return it to the existing feature error handling; do not retry again.
- Offline, timeout, `403`, validation, and server errors: preserve current behavior and do not refresh.
- Concurrent protected calls: wait for the same refresh operation and then use the same rotated access token.

## Verification

Automated tests will prove:

- an expired token is refreshed before a feature request and the request uses the rotated access token;
- an unexpected `401` causes one refresh and exactly one retry;
- a second `401` does not loop;
- concurrent callers trigger one refresh request;
- failed refresh clears persisted and in-memory tokens and transitions to `unauthenticated`;
- unauthenticated requests are not modified;
- SignalR's access-token callback fetches the current token rather than retaining the original one.

Targeted tests will run first, followed by the complete Flutter test suite and `flutter analyze`.

## Scope

This change does not alter API token lifetime, refresh-token rotation rules, login UI, endpoint contracts, or non-authentication error messages. It does not add periodic background refresh; tokens are refreshed on demand immediately before authenticated activity.
