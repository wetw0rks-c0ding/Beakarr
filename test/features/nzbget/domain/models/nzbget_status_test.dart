import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/nzbget/domain/models/nzbget_status.dart';

void main() {
  group('NzbgetStatus.fromJson', () {
    test('tolerates an empty payload', () {
      final status = NzbgetStatus.fromJson({});

      expect(status.remainingSizeMb, 0);
      expect(status.downloadedSizeMb, 0);
      expect(status.downloadRateBps, 0);
      expect(status.downloadPaused, isFalse);
      expect(status.postPaused, isFalse);
      expect(status.serverStandBy, isFalse);
      expect(status.postJobCount, 0);
      expect(status.urlCount, 0);
      expect(status.serverTime, 0);
      expect(status.freeDiskSpaceMb, 0);
    });

    test('recomposes the 64-bit download rate from Lo/Hi', () {
      final status = NzbgetStatus.fromJson({
        'DownloadRateLo': 5,
        'DownloadRateHi': 1,
      });

      expect(status.downloadRateBps, 0x100000005);
    });

    test('prefers Lo/Hi over the deprecated DownloadRate', () {
      final status = NzbgetStatus.fromJson({
        'DownloadRate': 999,
        'DownloadRateLo': 10,
        'DownloadRateHi': 0,
      });

      expect(status.downloadRateBps, 10);
    });

    test('falls back to DownloadRate when Lo is absent', () {
      final status = NzbgetStatus.fromJson({'DownloadRate': 4242});

      expect(status.downloadRateBps, 4242);
    });

    test('treats a lone DownloadRateLo as the full rate', () {
      final status = NzbgetStatus.fromJson({'DownloadRateLo': 512});

      expect(status.downloadRateBps, 512);
    });

    test('accepts numeric strings and truthy booleans', () {
      final status = NzbgetStatus.fromJson({
        'RemainingSizeMB': '1024',
        'DownloadRateLo': '2048',
        'DownloadPaused': 1,
        'PostPaused': 'true',
        'ServerStandBy': 0,
      });

      expect(status.remainingSizeMb, 1024);
      expect(status.downloadRateBps, 2048);
      expect(status.downloadPaused, isTrue);
      expect(status.postPaused, isTrue);
      expect(status.serverStandBy, isFalse);
    });
  });

  group('formatting', () {
    test('downloadRateFormatted converts to human units', () {
      expect(const NzbgetStatus().downloadRateFormatted, '0 B/s');
      expect(
        const NzbgetStatus(downloadRateBps: 1536).downloadRateFormatted,
        '1.5 KB/s',
      );
    });

    test('remainingSizeFormatted promotes MB to GB', () {
      expect(const NzbgetStatus().remainingSizeFormatted, '0 MB');
      expect(
        const NzbgetStatus(remainingSizeMb: 2048).remainingSizeFormatted,
        '2.00 GB',
      );
    });
  });
}
