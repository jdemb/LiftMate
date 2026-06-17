import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/auth/token_store.dart';

void main() {
  group('TokenStore', () {
    test('in-memory implementation saves and reads tokens', () async {
      final store = InMemoryTokenStore();
      final expiresAt = DateTime.utc(2026, 6, 2, 12);

      await store.save(
        StoredAuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: expiresAt,
        ),
      );

      final stored = await store.read();

      expect(stored?.accessToken, 'access-token');
      expect(stored?.refreshToken, 'refresh-token');
      expect(stored?.expiresAt, expiresAt);
    });

    test('save overwrites existing tokens', () async {
      final store = InMemoryTokenStore();

      await store.save(
        StoredAuthTokens(
          accessToken: 'access-token-1',
          refreshToken: 'refresh-token-1',
          expiresAt: DateTime.utc(2026, 6, 2, 12),
        ),
      );
      await store.save(
        StoredAuthTokens(
          accessToken: 'access-token-2',
          refreshToken: 'refresh-token-2',
          expiresAt: DateTime.utc(2026, 6, 2, 13),
        ),
      );

      final stored = await store.read();

      expect(stored?.accessToken, 'access-token-2');
      expect(stored?.refreshToken, 'refresh-token-2');
      expect(stored?.expiresAt, DateTime.utc(2026, 6, 2, 13));
    });

    test('clear removes tokens', () async {
      final store = InMemoryTokenStore();

      await store.save(
        StoredAuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.utc(2026, 6, 2, 12),
        ),
      );
      await store.clear();

      expect(await store.read(), isNull);
    });
  });
}

class InMemoryTokenStore implements TokenStore {
  StoredAuthTokens? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> read() async => _tokens;

  @override
  Future<void> save(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}
