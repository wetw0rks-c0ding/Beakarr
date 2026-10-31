import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/regions.dart';

const _regionScreenDescription =
    'This setting allows the app to show accurate release dates, content '
    'ratings, and watch providers for your region.';

class SettingsRegionScreen extends ConsumerWidget {
  const SettingsRegionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final selectedRegion = SettingsModel.normalizeRegion(settings.region);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Region')),
      body: ListView(
        // Nav clearance (see settings_services_screen.dart).
        padding: EdgeInsets.only(
          bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              _regionScreenDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          ...commonRegions.entries.map((entry) {
            return RadioListTile<String>(
              title: Text('${entry.value} (${entry.key})'),
              value: entry.key,
              // TODO(seekarr): Migrate to the replacement Radio API once this
              // project updates to the Flutter SDK version that fully supports
              // it across our targets.
              // ignore: deprecated_member_use
              groupValue: selectedRegion,
              // ignore: deprecated_member_use
              onChanged: (String? value) async {
                if (value != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .updateSettings(settings.copyWith(region: value));
                }
              },
            );
          }),
        ],
      ),
    );
  }
}
