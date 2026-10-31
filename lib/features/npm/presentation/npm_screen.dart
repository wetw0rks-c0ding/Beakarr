import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/core/widgets/async_value_widget.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';
import 'package:seekarr/features/npm/presentation/npm_provider.dart';
import 'package:seekarr/features/npm/presentation/widgets/npm_cert_tile.dart';
import 'package:seekarr/features/npm/presentation/widgets/npm_host_tile.dart';
import 'package:seekarr/features/npm/presentation/widgets/npm_summary_bar.dart';

const int _hostsTab = 0;
const int _certificatesTab = 1;

/// Read-only Nginx Proxy Manager screen: proxy hosts + certificate expiry.
///
/// No enable/disable toggle and no renew button in v1 — those endpoints are
/// mutating and deferred.
class NpmScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final double topPadding;

  const NpmScreen({super.key, this.showAppBar = true, this.topPadding = 0});

  @override
  ConsumerState<NpmScreen> createState() => _NpmScreenState();
}

class _NpmScreenState extends ConsumerState<NpmScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: ref.read(npmHostQueryProvider),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(npmTabProvider);
    final allHostsAsync = ref.watch(npmHostsProvider);
    final hostsAsync = ref.watch(npmFilteredHostsProvider);
    final certificatesAsync = ref.watch(npmCertificatesProvider);
    final worstCertificate = ref
        .watch(npmWorstCertificateProvider)
        .asData
        ?.value;

    final allHosts = allHostsAsync.asData?.value ?? const <NpmProxyHost>[];
    final certificates =
        certificatesAsync.asData?.value ?? const <NpmCertificate>[];
    final query = ref.watch(npmHostQueryProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Nginx Proxy Manager'))
          : null,
      body: Column(
        children: [
          if (widget.topPadding > 0) SizedBox(height: widget.topPadding),
          NpmSummaryBar(
            hosts: allHosts,
            certificates: certificates,
            worstCertificate: worstCertificate,
            onCertificatesTap: () => _selectTab(_certificatesTab),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: _hostsTab,
                  label: Text('Hosts'),
                  icon: Icon(Icons.router_rounded, size: 16),
                ),
                ButtonSegment(
                  value: _certificatesTab,
                  label: Text('Certificates'),
                  icon: Icon(Icons.verified_user_rounded, size: 16),
                ),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _selectTab(selection.first),
            ),
          ),
          if (tab == _hostsTab)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _HostSearchField(
                controller: _queryController,
                onChanged: (value) {
                  ref.read(npmHostQueryProvider.notifier).state = value;
                },
              ),
            ),
          Expanded(
            child: tab == _certificatesTab
                ? _CertificatesTab(
                    certificates: certificatesAsync,
                    onRefresh: _refresh,
                  )
                : _HostsTab(
                    hosts: hostsAsync,
                    query: query,
                    certificateFor: _certificateFor,
                    onRefresh: _refresh,
                  ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int next) {
    if (ref.read(npmTabProvider) == next) return;
    ref.read(npmTabProvider.notifier).state = next;
  }

  /// Certificate for a host: the `expand=certificate` sub-object when present,
  /// else a local lookup by `certificate_id` in the fetched certificates.
  NpmCertificate? _certificateFor(NpmProxyHost host) {
    final expanded = host.certificate;
    if (expanded != null) return expanded;
    final id = host.certificateId;
    if (id == null) return null;
    final certificates =
        ref.read(npmCertificatesProvider).asData?.value ??
        const <NpmCertificate>[];
    for (final certificate in certificates) {
      if (certificate.id == id) return certificate;
    }
    return null;
  }

  Future<void> _refresh() async {
    ref.invalidate(npmHostsProvider);
    ref.invalidate(npmCertificatesProvider);
    // Keep the indicator up until both reloads settle; the tab's
    // AsyncValueWidget renders any error.
    await Future.wait([
      _settle(ref.read(npmHostsProvider.future)),
      _settle(ref.read(npmCertificatesProvider.future)),
    ]);
  }

  Future<void> _settle(Future<Object?> future) async {
    try {
      await future;
    } catch (_) {
      // Rendered by the tab, not by the refresh indicator.
    }
  }
}

class _HostsTab extends StatelessWidget {
  final AsyncValue<List<NpmProxyHost>> hosts;
  final String query;
  final NpmCertificate? Function(NpmProxyHost host) certificateFor;
  final Future<void> Function() onRefresh;

  const _HostsTab({
    required this.hosts,
    required this.query,
    required this.certificateFor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<NpmProxyHost>>(
      value: hosts,
      serviceName: 'Nginx Proxy Manager',
      data: (items) {
        if (items.isEmpty) {
          final trimmed = query.trim();
          return _EmptyTab(
            icon: Icons.router_outlined,
            label: trimmed.isEmpty
                ? 'No proxy hosts configured'
                : 'No hosts match "$trimmed"',
            onRefresh: onRefresh,
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: 4,
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final host = items[index];
              return NpmHostTile(host: host, certificate: certificateFor(host));
            },
          ),
        );
      },
    );
  }
}

class _CertificatesTab extends StatelessWidget {
  final AsyncValue<List<NpmCertificate>> certificates;
  final Future<void> Function() onRefresh;

  const _CertificatesTab({required this.certificates, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<NpmCertificate>>(
      value: certificates,
      serviceName: 'Nginx Proxy Manager',
      data: (items) {
        if (items.isEmpty) {
          return _EmptyTab(
            icon: Icons.verified_user_outlined,
            label: 'No certificates configured',
            onRefresh: onRefresh,
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: 4,
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                NpmCertTile(certificate: items[index]),
          ),
        );
      },
    );
  }
}

class _HostSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _HostSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Filter hosts',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                tooltip: 'Clear filter',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        fillColor: colorScheme.surfaceContainer,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onRefresh;

  const _EmptyTab({
    required this.icon,
    required this.label,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: AppSpacing.xxxl),
        children: [
          Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pull down to refresh',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
