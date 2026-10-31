import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

const _appearanceScreenDescription =
    'Choose how Seekarr looks. System will follow your device setting.';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        // Nav clearance (see settings_services_screen.dart).
        padding: EdgeInsets.only(
          bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              _appearanceScreenDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          ...AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(mode.label),
              value: mode,
              // TODO(seekarr): Migrate to the replacement Radio API once this
              // project updates to the Flutter SDK version that fully supports
              // it across our targets.
              // ignore: deprecated_member_use
              groupValue: settings.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) => _updateThemeMode(ref, settings, value),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _updateThemeMode(
    WidgetRef ref,
    SettingsModel settings,
    AppThemeMode? value,
  ) async {
    if (value == null || value == settings.themeMode) {
      return;
    }

    await ref
        .read(settingsProvider.notifier)
        .updateSettings(settings.copyWith(themeMode: value));
  }
}
