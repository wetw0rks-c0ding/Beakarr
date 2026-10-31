import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/nzbget/domain/models/nzbget_queue_item.dart';

void main() {
  group('NzbgetQueueItem.fromJson', () {
    test('tolerates an empty payload', () {
      final item = NzbgetQueueItem.fromJson({});

      expect(item.id, 0);
      expect(item.name, '');
      expect(item.status, '');
      expect(item.category, '');
      expect(item.fileSizeMb, 0);
      expect(item.remainingSizeMb, 0);
      expect(item.health, 0);
      expect(item.postInfoText, '');
    });

    test('accepts numeric strings for numeric fields', () {
      final item = NzbgetQueueItem.fromJson({
        'NZBID': '42',
        'FileSizeMB': '1000',
        'RemainingSizeMB': '250',
        'Health': '997',
        'DownloadedSizeMB': '750',
      });

      expect(item.id, 42);
      expect(item.fileSizeMb, 1000);
      expect(item.remainingSizeMb, 250);
      expect(item.health, 997);
      expect(item.downloadedSizeMb, 750);
    });

    test('normalises the status to upper case', () {
      final item = NzbgetQueueItem.fromJson({'Status': 'paused'});

      expect(item.status, 'PAUSED');
      expect(item.isPaused, isTrue);
    });
  });

  group('NzbgetQueueItem.progress', () {
    test('is 0 for a zero total size', () {
      final item = NzbgetQueueItem.fromJson({
        'FileSizeMB': 0,
        'RemainingSizeMB': 0,
      });

      expect(item.progress, 0);
    });

    test('is 0 when remaining exceeds the total', () {
      final item = NzbgetQueueItem.fromJson({
        'FileSizeMB': 100,
        'RemainingSizeMB': 150,
      });

      expect(item.progress, 0);
    });

    test('computes the downloaded fraction', () {
      final item = NzbgetQueueItem.fromJson({
        'FileSizeMB': 2000,
        'RemainingSizeMB': 500,
      });

      expect(item.progress, 0.75);
      expect(item.progressFormatted, '75.0%');
    });
  });

  group('NzbgetQueueItem predicates', () {
    test('isPaused only matches PAUSED', () {
      expect(NzbgetQueueItem.fromJson({'Status': 'PAUSED'}).isPaused, isTrue);
      expect(
        NzbgetQueueItem.fromJson({'Status': 'DOWNLOADING'}).isPaused,
        isFalse,
      );
    });

    test('isPostProcessing matches every PP stage', () {
      for (final status in [
        'LOADING_PARS',
        'VERIFYING_SOURCES',
        'REPAIRING',
        'UNPACKING',
        'PP_QUEUED',
        'PP_FINISHED',
      ]) {
        expect(
          NzbgetQueueItem.fromJson({'Status': status}).isPostProcessing,
          isTrue,
          reason: status,
        );
      }
      expect(
        NzbgetQueueItem.fromJson({'Status': 'DOWNLOADING'}).isPostProcessing,
        isFalse,
      );
    });
  });

  test('health is rendered from permille', () {
    expect(NzbgetQueueItem.fromJson({'Health': 1000}).healthFormatted, '100%');
    expect(NzbgetQueueItem.fromJson({'Health': 997}).healthFormatted, '99.7%');
    expect(NzbgetQueueItem.fromJson({'Health': 0}).healthFormatted, '0%');
  });
}
