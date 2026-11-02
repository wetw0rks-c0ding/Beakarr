import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/openmediavault/domain/models/omv_disk.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_filesystem.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_parse.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_service_status.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_smart_device.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';

void main() {
  group('omv_parse', () {
    test('bytesFromString handles "-1" and human formats', () {
      expect(bytesFromString('-1'), isNull);
      expect(bytesFromString('500107862016'), 500107862016);
      expect(bytesFromString(''), isNull);
      expect(bytesFromString(null), isNull);
    });

    test('smartAssessmentIsHealthy maps the known table', () {
      expect(smartAssessmentIsHealthy('GOOD'), isTrue);
      expect(smartAssessmentIsHealthy('BAD_STATUS'), isFalse);
      expect(smartAssessmentIsHealthy('BAD_SECTOR_MANY'), isFalse);
      expect(smartAssessmentIsHealthy(''), isFalse);
      expect(smartAssessmentIsHealthy(null), isFalse);
    });

    test('formatUptime renders d/h/m', () {
      expect(formatUptime(90), contains('1m'));
      expect(formatUptime(90061), contains('1d'));
      expect(formatUptime(null), isEmpty);
    });
  });

  group('OmvSystemInfo.fromJson', () {
    test('tolerates string bytes and object load average', () {
      final info = OmvSystemInfo.fromJson(const {
        'hostname': 'bertha',
        'version': '7.4.17 (Sandworm)',
        'uptime': 90061.5,
        'loadAverage': {'1min': 0.5, '5min': 0.4, '15min': 0.3},
        'memTotal': '16777216000',
        'memUtilization': 0.42,
      });

      expect(info.hostname, 'bertha');
      expect(info.uptime, 90061.5);
      expect(info.loadAverage?['1min'], 0.5);
      expect(info.memTotal, '16777216000');
      expect(info.memoryUsedRatio, closeTo(0.42, 0.001));
      expect(info.uptimeLabel, contains('1d'));
    });

    test('missing keys degrade to null, never throw', () {
      expect(() => OmvSystemInfo.fromJson(const {}), returnsNormally);
    });
  });

  group('OmvFilesystem.fromJson', () {
    test('parses mount and degrades "-1" sentinels', () {
      final fs = OmvFilesystem.fromJson(const {
        'devicefile': '/dev/sda1',
        'mountpoint': '/',
        'type': 'ext4',
        'size': '500107862016',
        'used': 'human-formatted',
        'available': '123456789',
        'percentage': 75,
        'mounted': true,
      });

      expect(fs.devicefile, '/dev/sda1');
      expect(fs.sizeBytes, 500107862016);
      // 'used' is human-formatted on the wire, not bytes.
      expect(fs.usedBytes, isNull);
      expect(fs.availableBytes, 123456789);
      expect(fs.usageRatio, closeTo(0.75, 0.001));
      expect(fs.mounted, isTrue);
    });

    test('negative percentage means unknown, not 0%', () {
      final fs = OmvFilesystem.fromJson(const {'percentage': -1});
      expect(fs.percentage, isNull);
      expect(fs.usageRatio, isNull);
    });
  });

  group('OmvDisk.fromJson', () {
    test('standby temperature "" maps to null', () {
      final disk = OmvDisk.fromJson(const {
        'devicename': 'sda',
        'model': 'ST4000DM004',
        'size': '4000787030016',
        'temperature': '',
      });

      expect(disk.devicename, 'sda');
      expect(disk.sizeBytes, 4000787030016);
      expect(disk.temperatureC, isNull);
    });
  });

  group('OmvSmartDevice', () {
    test('isHealthy follows the assessment table', () {
      OmvSmartDevice h(String s) =>
          OmvSmartDevice.fromJson({'overallstatus': s});
      expect(h('GOOD').isHealthy, isTrue);
      expect(h('BAD_STATUS').isHealthy, isFalse);
      expect(h('').isHealthy, isFalse);
    });
  });

  group('OmvServiceStatus.fromJson', () {
    test('keeps identity separate from localized title', () {
      final svc = OmvServiceStatus.fromJson(const {
        'name': 'nfs',
        'title': 'NFS',
        'enabled': true,
        'running': false,
      });
      expect(svc.name, 'nfs');
      expect(svc.title, 'NFS');
      expect(svc.enabled, isTrue);
      expect(svc.running, isFalse);
    });
  });
}
