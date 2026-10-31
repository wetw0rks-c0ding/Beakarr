import 'package:flutter/material.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/widgets/async_value_widget.dart';
import 'package:seekarr/features/openmediavault/data/openmediavault_providers.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_disk.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_filesystem.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_parse.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_service_status.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_smart_device.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';
import 'package:seekarr/features/openmediavault/presentation/widgets/omv_health_pill.dart';
import 'package:seekarr/features/openmediavault/presentation/widgets/omv_stat_tile.dart';
import 'package:seekarr/features/openmediavault/presentation/widgets/omv_usage_bar.dart';

class OpenMediaVaultScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final double topPadding;

  const OpenMediaVaultScreen({
    super.key,
    this.showAppBar = true,
    this.topPadding = 0,
  });

  @override
  ConsumerState<OpenMediaVaultScreen> createState() =>
      _OpenMediaVaultScreenState();
}

const int _overviewTab = 0;
const int _storageTab = 1;
const int _disksTab = 2;
const int _servicesTab = 3;

class _OpenMediaVaultScreenState extends ConsumerState<OpenMediaVaultScreen> {
  int _tab = _overviewTab;

  @override
  Widget build(BuildContext context) {
    // SegmentedButton + conditional child, same pattern as NzbgetScreen.
    // (An earlier DefaultTabController + TabBarView version of this screen
    // rendered blank on-device; bisecting proved the tab controller innocent
    // — the blank came from OmvUsageBar used as OmvStatTile.trailing, which
    // throws an unbounded-width layout exception that blanks the whole body
    // in release builds. See the NOTE on the Memory tile below.)
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('OpenMediaVault'))
          : null,
      body: Column(
        children: [
          // The shell overlays a SafeArea-padded app bar (status bar +
          // kToolbarHeight) on top of this body, so the spacer must clear
          // both, not just widget.topPadding. Sibling screens absorb the
          // overlap in their tall summary bars; OMV's switcher is first
          // and would otherwise hide under the overlay.
          if (widget.topPadding > 0)
            SizedBox(
              height:
                  widget.topPadding + MediaQuery.paddingOf(context).top,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: _overviewTab,
                  label: Text('Overview'),
                ),
                ButtonSegment(
                  value: _storageTab,
                  label: Text('Storage'),
                ),
                ButtonSegment(
                  value: _disksTab,
                  label: Text('Disks'),
                ),
                ButtonSegment(
                  value: _servicesTab,
                  label: Text('Services'),
                ),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _storageTab => _StorageTab(),
              _disksTab => _DisksTab(),
              _servicesTab => _ServicesTab(),
              _ => _OverviewTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(omvSystemInfoProvider);
    return AsyncValueWidget<OmvSystemInfo>(
      value: async,
      serviceName: 'OpenMediaVault',
      data: (info) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(omvSystemInfoProvider);
            await ref.read(omvSystemInfoProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            children: [
              OmvStatTile(label: 'Hostname', value: info.hostname ?? '—'),
              OmvStatTile(label: 'Version', value: info.displayVersion.isEmpty ? '—' : info.displayVersion),
              OmvStatTile(label: 'Kernel', value: info.kernel ?? '—'),
              OmvStatTile(label: 'Uptime', value: info.uptimeLabel.isEmpty ? '—' : info.uptimeLabel),
              OmvStatTile(label: 'Load (1/5/15m)', value: info.loadLabel.isEmpty ? '—' : info.loadLabel),
              OmvStatTile(
                label: 'CPU',
                value: '${info.cpuModelName ?? '—'} (${info.cpuCores ?? 0} cores)',
              ),
              OmvStatTile(
                label: 'Memory',
                value: info.memTotal == null
                    ? '—'
                    : '${_fmtBytes(info.memUsed)} / ${_fmtBytes(info.memTotal)}',
              ),
              // NOTE: OmvUsageBar must NOT be OmvStatTile.trailing. A Row
              // gives non-flex children unbounded width constraints, and the
              // bar's inner Row contains an Expanded -> layout exception
              // ("RenderFlex children have non-zero flex but incoming width
              // constraints are unbounded") that blanks the whole screen in
              // release builds with zero logcat errors. Full-width below the
              // tile, same as the Storage tab.
              if (info.memoryUsedRatio != null)
                OmvUsageBar(
                  label: '',
                  ratio: info.memoryUsedRatio,
                  valueLabel:
                      '${(info.memoryUsedRatio! * 100).toStringAsFixed(0)}%',
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Read-only — Beakarr never changes your OMV configuration.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
      );
  }
}

String _fmtBytes(String? s) {
  // OMV uses "-1" for "unknown" and sends decimals as strings; reuse the
  // model-layer formatter so sentinels and garbage render as "—".
  return formatBytesFromString(s) ?? '—';
}

class _StorageTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(omvFilesystemsProvider);
    return AsyncValueWidget<List<OmvFilesystem>>(
      value: async,
      serviceName: 'OpenMediaVault',
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(omvFilesystemsProvider);
              await ref.read(omvFilesystemsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
              children: const [
                SizedBox(height: 64),
                Center(child: Text('No filesystems')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(omvFilesystemsProvider);
            await ref.read(omvFilesystemsProvider.future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final fs = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fs.mountpoint ?? fs.devicefile ?? '—',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (!fs.mounted)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('not mounted'),
                        ),
                      OmvUsageBar(
                        label: fs.type ?? '',
                        ratio: fs.usageRatio,
                        valueLabel: fs.percentage == null
                            ? null
                            : '${fs.percentage}%',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DisksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disksAsync = ref.watch(omvDisksProvider);
    final smartAsync = ref.watch(omvSmartDevicesProvider);
    final smartMap = <String, OmvSmartDevice>{};
    final smartList = smartAsync.asData?.value ?? const <OmvSmartDevice>[];
    for (final s in smartList) {
      if (s.devicefile != null) smartMap[s.devicefile!] = s;
    }
    return AsyncValueWidget<List<OmvDisk>>(
      value: disksAsync,
      serviceName: 'OpenMediaVault',
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(omvDisksProvider);
              await ref.read(omvDisksProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
              children: const [
                SizedBox(height: 64),
                Center(child: Text('No disks')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(omvDisksProvider);
            ref.invalidate(omvSmartDevicesProvider);
            await ref.read(omvDisksProvider.future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final disk = items[index];
              final smart = disk.devicefile != null
                  ? smartMap[disk.devicefile]
                  : null;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              disk.devicename ?? disk.devicefile ?? '—',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          OmvHealthPill(
                            status: smart?.overallStatus ?? '',
                          ),
                        ],
                      ),
                      Text(disk.model ?? ''),
                      Text(
                        '${disk.sizeBytes == null ? '—' : _fmtBytesNum(disk.sizeBytes)}  '
                        'Temp: ${disk.temperatureC == null ? '—' : '${disk.temperatureC}°C'}  '
                        '${disk.powerMode ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ServicesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(omvServicesProvider);
    return AsyncValueWidget<List<OmvServiceStatus>>(
      value: async,
      serviceName: 'OpenMediaVault',
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(omvServicesProvider);
              await ref.read(omvServicesProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
              children: const [
                SizedBox(height: 64),
                Center(child: Text('No services')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(omvServicesProvider);
            await ref.read(omvServicesProvider.future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // Nav clearance (see settings_services_screen.dart).
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final s = items[index];
              return ListTile(
                title: Text(s.title ?? s.name ?? '—'),
                subtitle: Text(s.name ?? ''),
                trailing: Text(s.stabilityLabel),
              );
            },
          ),
        );
      },
    );
  }
}

String _fmtBytesNum(int? bytes) {
  if (bytes == null) return '—';
  // simple
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  int i = 0;
  double s = bytes.toDouble();
  while (s >= 1024 && i < units.length - 1) {
    s /= 1024;
    i++;
  }
  return '${s.toStringAsFixed(1)} ${units[i]}';
}