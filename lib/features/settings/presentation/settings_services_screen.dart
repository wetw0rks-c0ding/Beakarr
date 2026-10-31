import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/core/widgets/app_card.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

class SettingsServicesScreen extends ConsumerWidget {
  const SettingsServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: ListView(
        // Nav clearance: the floating bar overlays extended body content;
        // without this the last rows scroll underneath it.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg +
              FloatingNavBarMetrics.getScrollViewBottomPadding(context),
        ),
        children: [
          SettingsGroupCard(
            children: [
              for (final service in ServiceKey.values)
                SettingsCard.grouped(
                  leading: Icon(service.icon),
                  title: service.title,
                  subtitle: _serviceSubtitle(settings, service),
                  accentColor: service.accent,
                  onTap: () =>
                      context.push('/settings/service/${service.routeParam}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isConfigured(settings, service))
                        _DeleteButton(
                          serviceName: service.title,
                          onConfirm: () async {
                            final cleared = settings.clearedService(service);
                            await ref
                                .read(settingsProvider.notifier)
                                .updateSettings(cleared);
                          },
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isConfigured(SettingsModel settings, ServiceKey service) {
    return settings.isServiceConfigured(service);
  }

  String _serviceSubtitle(SettingsModel settings, ServiceKey service) {
    final url = settings.urlFor(service);
    return url.isEmpty ? 'Not configured' : service.extractHost(url) ?? url;
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.serviceName, required this.onConfirm});

  final String serviceName;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline_rounded),
      color: Theme.of(context).colorScheme.error,
      iconSize: 20,
      tooltip: 'Remove credentials',
      visualDensity: VisualDensity.compact,
      onPressed: () => _showConfirmation(context),
    );
  }

  void _showConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $serviceName'),
        content: Text(
          'This will delete all saved credentials and disconnect $serviceName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
