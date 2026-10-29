import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/app_version.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/core/updater/app_updater.dart';
import 'package:seekarr/core/utils/snack_bar_helper.dart';
import 'package:seekarr/core/widgets/app_card.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/features/onboarding/data/onboarding_provider.dart';
import 'package:seekarr/features/settings/data/donation_service.dart';
import 'package:seekarr/features/settings/data/service_connection_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/regions.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/settings/presentation/widgets/donation_sheet.dart';

class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  static final Uri _githubUri = Uri.parse(
    'https://github.com/wetw0rks-c0ding/seekarr',
  );
  static final Uri _feedbackUri = Uri(
    scheme: 'mailto',
    path: 'matthw.labs@gmail.com',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final bottomPadding = FloatingNavBarMetrics.getScrollViewBottomPadding(
      context,
    );
    final content = [
      ..._buildGeneralSection(context, ref, settings),
      const SizedBox(height: AppSpacing.lg),
      ..._buildServicesSection(context, ref, settings),
      const SizedBox(height: AppSpacing.lg),
      ..._buildAboutSection(context, ref),
      const SizedBox(height: AppSpacing.lg),
      ..._buildDangerZoneSection(context, ref),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGeneralSection(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      const _SettingsSectionLabel('General'),
      const SizedBox(height: AppSpacing.sm),
      SettingsGroupCard(
        children: [
          SettingsCard.grouped(
            leading: const Icon(Icons.language_rounded),
            title: 'Region',
            subtitle: _formatRegionLabel(settings.region),
            accentColor: AppColors.success,
            onTap: () => context.push('/settings/region'),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.palette_rounded),
            title: 'Appearance',
            subtitle: settings.themeMode.label,
            onTap: () => context.push('/settings/appearance'),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.apps_rounded),
            title: 'Dashboard',
            subtitle: 'All services',
            accentColor: colorScheme.primary,
            onTap: () => context.push('/settings/services'),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.lock_rounded),
            title: 'Authentication',
            subtitle: 'Single sign-on',
            accentColor: colorScheme.primary,
            onTap: () => context.push('/settings/auth'),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.security_rounded),
            title: 'Jailbroken',
            subtitle: 'Enable TrollStore install path on iOS',
            accentColor: colorScheme.primary,
            trailing: Switch.adaptive(
              value: settings.jailbroken,
              onChanged: (value) async {
                final current = ref.read(currentSettingsProvider);
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(current.copyWith(jailbroken: value));
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildServicesSection(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) {
    final configured = ServiceKey.values
        .where((s) => settings.isServiceConfigured(s))
        .toList();

    if (configured.isEmpty) return [];

    return [
      const _SettingsSectionLabel('Services'),
      const SizedBox(height: AppSpacing.sm),
      SettingsGroupCard(
        children: [
          for (final service in configured)
            SettingsCard.grouped(
              leading: Icon(service.icon),
              title: service.title,
              subtitle: _getServiceSubtitle(settings, service),
              accentColor: service.accent,
              subtitleLeading: _buildConnectionIndicator(
                context,
                ref,
                settings,
                service,
              ),
              onTap: () =>
                  context.push('/settings/service/${service.routeParam}'),
            ),
        ],
      ),
    ];
  }

  Widget? _buildConnectionIndicator(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
    ServiceKey service,
  ) {
    // No indicator when the service isn't configured yet.
    if (settings.urlFor(service).isEmpty) {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final asyncStatus = ref.watch(serviceConnectionProvider(service));
    const checkingIndicator = SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final disconnectedIndicator = Icon(
      Icons.cloud_off_rounded,
      size: 16,
      color: colorScheme.error,
    );

    return asyncStatus.when(
      loading: () => checkingIndicator,
      error: (_, __) => disconnectedIndicator,
      data: (status) {
        switch (status) {
          case ServiceConnectionStatus.connected:
            return Icon(
              Icons.cloud_done_rounded,
              size: 16,
              color: service.accent,
            );
          case ServiceConnectionStatus.disconnected:
            return disconnectedIndicator;
          case ServiceConnectionStatus.checking:
            return checkingIndicator;
          case ServiceConnectionStatus.notConfigured:
            return null;
        }
      },
    );
  }

  List<Widget> _buildAboutSection(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      const _SettingsSectionLabel('About'),
      const SizedBox(height: AppSpacing.sm),
      SettingsGroupCard(
        children: [
          SettingsCard.grouped(
            leading: const Icon(Icons.share_rounded),
            title: 'Share App',
            accentColor: AppColors.success,
            onTap: () => SnackBarHelper.info(context, 'Coming soon!'),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.info_outline_rounded),
            title: 'Version',
            subtitle: kAppVersion,
            accentColor: colorScheme.onSurfaceVariant,
            onTap: () => _checkForUpdates(context, ref),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.code_rounded),
            title: 'GitHub',
            accentColor: colorScheme.onSurfaceVariant,
            onTap: () => _openGitHub(context),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.feedback_rounded),
            title: 'Send Feedback',
            accentColor: AppColors.warning,
            onTap: () => _sendFeedback(context),
          ),
          SettingsCard.grouped(
            leading: const Icon(Icons.favorite_rounded),
            title: 'Support Development',
            subtitle: 'Buy me a coffee',
            accentColor: AppColors.lidarr,
            onTap: () => _openDonation(context),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildDangerZoneSection(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      const _SettingsSectionLabel('Danger Zone'),
      const SizedBox(height: AppSpacing.sm),
      SettingsGroupCard(
        children: [
          SettingsCard.grouped(
            leading: const Icon(Icons.restart_alt_rounded),
            title: 'Reset app data',
            subtitle: 'Clear all services, settings, and restart onboarding',
            accentColor: colorScheme.error,
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: colorScheme.error,
          size: 40,
        ),
        title: const Text('Reset all data?'),
        content: const Text(
          'This clears all saved services, credentials, and preferences. '
          'Onboarding will restart. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(settingsProvider.notifier).resetSettings();
      await markOnboardingIncomplete(ref);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarHelper.error(context, "Couldn't reset app data. ($e)");
    }
  }

  String _getServiceSubtitle(SettingsModel settings, ServiceKey service) {
    final url = settings.urlFor(service);
    return url.isEmpty ? 'Not configured' : service.extractHost(url) ?? url;
  }

  String _formatRegionLabel(String region) {
    final normalizedRegion = SettingsModel.normalizeRegion(region);
    final regionName = commonRegions[normalizedRegion] ?? normalizedRegion;
    return '$regionName ($normalizedRegion)';
  }

  Future<void> _openGitHub(BuildContext context) {
    return _launchExternalUri(
      context: context,
      uri: _githubUri,
      failureMessage: 'Unable to open the GitHub repository.',
    );
  }

  Future<void> _sendFeedback(BuildContext context) {
    return _launchExternalUri(
      context: context,
      uri: _feedbackUri,
      failureMessage: 'Unable to open the email composer.',
    );
  }

  Future<void> _openDonation(BuildContext context) async {
    if (DonationService.usesIAP) {
      final useFallback = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
        ),
        builder: (_) => const DonationSheet(),
      );
      // Sheet returned true when IAP products aren't available — open Ko-fi.
      if (useFallback == true && context.mounted) {
        final launched = await DonationService.launchKofi();
        if (!launched && context.mounted) {
          SnackBarHelper.info(context, 'Unable to open the donation page.');
        }
      }
    } else {
      final launched = await DonationService.launchKofi();
      if (!launched && context.mounted) {
        SnackBarHelper.info(context, 'Unable to open the donation page.');
      }
    }
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    final updater = AppUpdater();
    GitHubRelease? latest;
    try {
      latest = await updater.checkForUpdate();
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, "Couldn't check for updates. ($e)");
      }
      return;
    }
    if (!context.mounted) return;

    if (latest == null) {
      SnackBarHelper.info(context, "You're up to date");
      return;
    }

    final jailbroken = ref.read(currentSettingsProvider).jailbroken;

    if (Platform.isAndroid) {
      final asset = pickAsset(latest, '-android.apk');
      if (asset == null) {
        SnackBarHelper.info(
          context,
          'No Android update asset found for ${latest.version}.',
        );
        return;
      }
      await _downloadAndInstallAndroid(context, updater, asset);
      return;
    }

    if (Platform.isIOS) {
      if (jailbroken) {
        final asset = pickAsset(latest, '-ios.ipa');
        if (asset == null) {
          SnackBarHelper.info(
            context,
            'No iOS update asset found for ${latest.version}.',
          );
          return;
        }
        await _downloadIpaForTrollStore(context, updater, asset);
        return;
      }
      // Not jailbroken: open releases page.
      await _launchExternalUri(
        context: context,
        uri: Uri.parse(
          'https://github.com/wetw0rks-c0ding/seekarr/releases',
        ),
        failureMessage: 'Unable to open the releases page.',
      );
      return;
    }

    // Other platforms: open releases page.
    await _launchExternalUri(
      context: context,
      uri: Uri.parse('https://github.com/wetw0rks-c0ding/seekarr/releases'),
      failureMessage: 'Unable to open the releases page.',
    );
  }

  Future<void> _downloadAndInstallAndroid(
    BuildContext context,
    AppUpdater updater,
    GitHubAsset asset,
  ) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/${asset.name}';
    final progress = ValueNotifier<double?>(null);
    BuildContext? dialogContext;

    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext_) {
          dialogContext = dialogContext_;
          return AlertDialog(
          title: Text('Downloading ${asset.name}'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p),
                const SizedBox(height: 8),
                Text(
                  p == null
                      ? 'Starting...'
                      : '${(p * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await updater.downloadAsset(
        asset,
        savePath,
        onProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
    } catch (e) {
      final dlg = dialogContext;
      if (dlg != null && dlg.mounted) Navigator.of(dlg).pop();
      if (context.mounted) {
        SnackBarHelper.error(context, "Couldn't download update. ($e)");
      }
      return;
    }

    final dlg = dialogContext;
    if (dlg != null && dlg.mounted) Navigator.of(dlg).pop();

    // Trigger system install prompt via platform channel.
    try {
      const channel = MethodChannel('seekarr/installer');
      final result = await channel.invokeMethod<String>('installApk', {
        'path': savePath,
      });
      if (result == 'needs_permission' && context.mounted) {
        SnackBarHelper.info(
          context,
          'Enable "Install unknown apps" for Seekarr, then tap Version again.',
        );
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(
          context,
          "Couldn't start installer. (${e.message})",
        );
      }
    }
  }

  Future<void> _downloadIpaForTrollStore(
    BuildContext context,
    AppUpdater updater,
    GitHubAsset asset,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/${asset.name}';
    final progress = ValueNotifier<double?>(null);
    BuildContext? dialogContext;

    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext_) {
          dialogContext = dialogContext_;
          return AlertDialog(
          title: Text('Downloading ${asset.name}'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p),
                const SizedBox(height: 8),
                Text(
                  p == null
                      ? 'Starting...'
                      : '${(p * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await updater.downloadAsset(
        asset,
        savePath,
        onProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
    } catch (e) {
      final dlg = dialogContext;
      if (dlg != null && dlg.mounted) Navigator.of(dlg).pop();
      if (context.mounted) {
        SnackBarHelper.error(context, "Couldn't download update. ($e)");
      }
      return;
    }

    final dlg = dialogContext;
    if (dlg != null && dlg.mounted) Navigator.of(dlg).pop();

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? const Rect.fromLTWH(0, 0, 1, 1)
          : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(savePath)],
          text: 'Open in TrollStore',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, "Couldn't hand off to TrollStore. ($e)");
      }
    }
  }

  Future<void> _launchExternalUri({
    required BuildContext context,
    required Uri uri,
    required String failureMessage,
  }) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      SnackBarHelper.info(context, failureMessage);
    }
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String title;

  const _SettingsSectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          fontSize: 11,
        ),
      ),
    );
  }
}
