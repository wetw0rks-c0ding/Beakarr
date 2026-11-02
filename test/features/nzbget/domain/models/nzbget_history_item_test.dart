import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/nzbget/domain/models/nzbget_history_item.dart';

void main() {
  group('NzbgetHistoryItem.fromJson', () {
    test('tolerates an empty payload', () {
      final item = NzbgetHistoryItem.fromJson({});

      expect(item.id, 0);
      expect(item.name, '');
      expect(item.status, '');
      expect(item.kind, '');
      expect(item.fileSizeMb, 0);
      expect(item.deleteStatus, 0);
      expect(item.parStatus, '');
      expect(item.unpackStatus, '');
      expect(item.scriptStatus, '');
      expect(item.url, '');
      expect(item.hasHistoryTime, isFalse);
    });

    test('converts the unix history time to a DateTime', () {
      final item = NzbgetHistoryItem.fromJson({'HistoryTime': 1700000000});

      expect(item.historyTime.millisecondsSinceEpoch, 1700000000 * 1000);
      expect(item.hasHistoryTime, isTrue);
    });

    test('accepts numeric strings and normalises the status', () {
      final item = NzbgetHistoryItem.fromJson({
        'NZBID': '12',
        'Status': 'success/all',
        'FileSizeMB': '2048',
        'HistoryTime': '1700000000',
      });

      expect(item.id, 12);
      expect(item.status, 'SUCCESS/ALL');
      expect(item.fileSizeMb, 2048);
      expect(item.hasHistoryTime, isTrue);
    });
  });

  group('NzbgetHistoryItem predicates', () {
    test('SUCCESS/ALL succeeded', () {
      final item = NzbgetHistoryItem.fromJson({'Status': 'SUCCESS/ALL'});

      expect(item.succeeded, isTrue);
      expect(item.failed, isFalse);
      expect(item.deleted, isFalse);
      expect(item.statusLabel, 'SUCCESS');
    });

    test('WARNING/SCRIPT is failed, not succeeded', () {
      final item = NzbgetHistoryItem.fromJson({'Status': 'WARNING/SCRIPT'});

      expect(item.failed, isTrue);
      expect(item.succeeded, isFalse);
    });

    test('FAILURE/PAR is failed', () {
      expect(
        NzbgetHistoryItem.fromJson({'Status': 'FAILURE/PAR'}).failed,
        isTrue,
      );
    });

    test('DELETED/MANUAL is deleted and not failed', () {
      final item = NzbgetHistoryItem.fromJson({'Status': 'DELETED/MANUAL'});

      expect(item.deleted, isTrue);
      expect(item.failed, isFalse);
      expect(item.succeeded, isFalse);
    });
  });

  test('matchesFilter uses the status prefix', () {
    final item = NzbgetHistoryItem.fromJson({'Status': 'WARNING/SCRIPT'});

    expect(item.matchesFilter(null), isTrue);
    expect(item.matchesFilter(''), isTrue);
    expect(item.matchesFilter('WARNING'), isTrue);
    expect(item.matchesFilter('SUCCESS'), isFalse);
  });
}
