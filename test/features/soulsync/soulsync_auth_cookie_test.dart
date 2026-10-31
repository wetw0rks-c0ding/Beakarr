import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/core/api/service_auth.dart';

void main() {
  group('SoulSyncAuth header matrix', () {
    test('key-only -> Bearer + X-Profile-Id, no empty Bearer', () {
      final auth = SoulSyncAuth('mykey', profileId: 'p1');
      final h = auth.headers();
      expect(h['Authorization'], 'Bearer mykey');
      expect(h['X-Profile-Id'], 'p1');
      expect(h.containsKey('Cookie'), false);
    });
    test('cookie-only -> Cookie verbatim, no Bearer (empty token)', () {
      // proxyCookie carries finder-built `name=value[; ...]` pairs.
      final auth = SoulSyncAuth(
        '',
        proxyCookie: 'session=abc',
      );
      final h = auth.headers();
      expect(h.containsKey('Authorization'), false); // never empty Bearer
      expect(h['Cookie'], 'session=abc');
    });
    test('both -> both headers', () {
      final auth = SoulSyncAuth(
        't',
        profileId: 'p',
        proxyCookie: '_soulsync_proxy=x',
      );
      final h = auth.headers();
      expect(h['Authorization'], 'Bearer t');
      expect(h['X-Profile-Id'], 'p');
      expect(h['Cookie'], '_soulsync_proxy=x');
    });
    test('neither -> no auth headers', () {
      final auth = SoulSyncAuth('');
      expect(auth.headers(), {});
    });
    test('Bearer only when token non-empty', () {
      final empty = SoulSyncAuth('   ');
      expect(empty.headers().containsKey('Authorization'), false);
      final nonEmpty = SoulSyncAuth('x');
      expect(nonEmpty.headers()['Authorization'], 'Bearer x');
    });
  });
}
