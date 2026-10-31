import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/wizarr/data/wizarr_providers.dart';

void main() {
  test('throws Wizarr not configured when url empty', () {
    final container = ProviderContainer(
      overrides: [
        currentSettingsProvider.overrideWith(
          (ref) => const SettingsModel(wizarrApiKey: 'k'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(() => container.read(wizarrClientProvider), throwsException);
    expect(() => container.read(wizarrServiceProvider), throwsException);
  });

  test('throws Wizarr not configured when key empty', () {
    final container = ProviderContainer(
      overrides: [
        currentSettingsProvider.overrideWith(
          (ref) => const SettingsModel(wizarrUrl: 'http://localhost'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(() => container.read(wizarrClientProvider), throwsException);
  });

  test('provider message contains Wizarr not configured', () {
    final container = ProviderContainer(
      overrides: [
        currentSettingsProvider.overrideWith(
          (ref) => const SettingsModel(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      () => container.read(wizarrClientProvider),
      throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Wizarr not configured'))),
    );
  });
}
