import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_create_defaults.dart';
import 'package:seekarr/features/wizarr/data/wizarr_providers.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_library.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_server.dart';

/// Full-screen form for creating a Wizarr guest invitation.
class WizarrCreateSheet extends ConsumerStatefulWidget {
  const WizarrCreateSheet({super.key});

  @override
  ConsumerState<WizarrCreateSheet> createState() => _WizarrCreateSheetState();
}

/// Back-compat aliases.
typedef WizarrCreateInviteSheet = WizarrCreateSheet;
typedef WizarrInviteCreateSheet = WizarrCreateSheet;

Future<void> showWizarrCreateSheet(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const WizarrCreateSheet(),
    ),
  );
}

class _WizarrCreateSheetState extends ConsumerState<WizarrCreateSheet> {
  bool _defaultsLoaded = false;
  bool _loadingDefaults = false;
  bool _submitting = false;

  Set<int> _selectedServers = <int>{};
  Set<int> _selectedLibraries = <int>{};
  int? _expiresInDays = 7;
  bool _unlimited = false;
  final TextEditingController _durationController =
      TextEditingController(text: '30');
  bool _allowDownloads = true;
  bool _allowLiveTv = true;
  bool _allowMobileUploads = true;

  String? _error;
  WizarrInvitation? _created;

  SharedPreferences? _prefs;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serversAsync = ref.read(wizarrServersProvider);
    if (serversAsync.hasValue && !_defaultsLoaded && !_loadingDefaults) {
      _loadDefaults();
    }
  }

  Future<void> _loadDefaults() async {
    if (_loadingDefaults || _defaultsLoaded) return;
    _loadingDefaults = true;
    late SharedPreferences prefs;
    try {
      prefs = ref.read(sharedPreferencesProvider);
    } catch (_) {
      prefs = await SharedPreferences.getInstance();
    }
    _prefs = prefs;

    final servers = ref.read(wizarrServersProvider).asData?.value ??
        const <WizarrServer>[];
    final d = loadCreateDefaults(prefs);
    if (!mounted) return;
    setState(() {
      if (d.serverIds.isEmpty) {
        _selectedServers = servers
            .map((s) => s.id)
            .whereType<int>()
            .toSet();
      } else {
        // Intersect with the loaded servers: a saved server removed from
        // Wizarr has no chip and could never be deselected, yet its ID
        // would otherwise be submitted (and fail) forever.
        final known =
            servers.map((s) => s.id).whereType<int>().toSet();
        _selectedServers = d.serverIds.where(known.contains).toSet();
      }
      _selectedLibraries = d.libraryIds.toSet();
      _expiresInDays = d.expiresInDays;
      _unlimited = d.unlimited;
      _durationController.text = d.durationDays.toString();
      _allowDownloads = d.allowDownloads;
      _allowLiveTv = d.allowLiveTv;
      _allowMobileUploads = d.allowMobileUploads;
      _defaultsLoaded = true;
    });
    _loadingDefaults = false;
  }

  int get _effectiveServerCount {
    return _selectedServers.length;
  }

  List<WizarrLibrary> _visibleLibraries(
    List<WizarrLibrary> libraries,
  ) {
    if (_selectedServers.isEmpty) return libraries;
    return libraries
        .where((l) => l.serverId == null || _selectedServers.contains(l.serverId))
        .toList(growable: false);
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final libraries = ref.read(wizarrLibrariesProvider).asData?.value ??
        const <WizarrLibrary>[];
    final serverIds = _selectedServers.toList();

    if (serverIds.isEmpty) {
      setState(() {
        _error = 'Select at least one server';
        _submitting = false;
      });
      return;
    }

    final durationDays = int.tryParse(_durationController.text.trim()) ?? 30;
    final duration = _unlimited ? 'unlimited' : '${durationDays}d';

    try {
      final service = ref.read(wizarrServiceProvider);
      final effectiveServerIds = serverIds.toSet();
      final prunedLibraryIds = _selectedLibraries.where((libId) {
        final lib = libraries.firstWhere(
          (l) => l.id == libId,
          orElse: () => WizarrLibrary(id: libId),
        );
        return lib.serverId == null || effectiveServerIds.contains(lib.serverId);
      }).toList();

      final invitation = await service.createInvitation(
        serverIds: serverIds,
        libraryIds: prunedLibraryIds,
        expiresInDays: _expiresInDays,
        duration: duration,
        unlimited: _unlimited,
        allowDownloads: _allowDownloads,
        allowLiveTv: _allowLiveTv,
        allowMobileUploads: _allowMobileUploads,
      );

      final prefs = _prefs;
      if (prefs != null) {
        // Best effort: the invite already exists; a prefs failure must
        // not report the create as failed (or invite a retry duplicate).
        try {
          await saveCreateDefaults(
          prefs,
          serverIds: _selectedServers.toList(),
          libraryIds: prunedLibraryIds,
          expiresInDays: _expiresInDays,
          unlimited: _unlimited,
          durationDays: durationDays,
          allowDownloads: _allowDownloads,
          allowLiveTv: _allowLiveTv,
          allowMobileUploads: _allowMobileUploads,
        );
        } catch (_) {}
      }

      ref.invalidate(wizarrInvitationsProvider);

      if (!mounted) return;
      setState(() {
        _created = invitation;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      // WizarrException already carries a scrubbed server message; anything
      // else (programming errors, unexpected failure shapes) stays generic
      // so internals never reach the screen.
      final msg = e is WizarrException
          ? e.message
          : "Couldn't create invite — check connection and try again.";
      setState(() {
        _error = msg;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger defaults load once servers are available.
    final serversAsync = ref.watch(wizarrServersProvider);
    if (serversAsync.hasValue && !_defaultsLoaded && !_loadingDefaults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_defaultsLoaded && !_loadingDefaults) _loadDefaults();
      });
    }

    if (_created != null) {
      return _buildSuccess(context, _created!);
    }

    final librariesAsync = ref.watch(wizarrLibrariesProvider);
    final servers = serversAsync.asData?.value ?? const <WizarrServer>[];
    final libraries = librariesAsync.asData?.value ?? const <WizarrLibrary>[];
    final visibleLibs = _visibleLibraries(libraries);

    return Scaffold(
      appBar: AppBar(title: const Text('New invite')),
      body: serversAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (serversAsync.hasError)
                    Text(
                      serversAsync.error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (servers.isEmpty && !serversAsync.hasError) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          'No servers',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                  if (servers.isNotEmpty) ...[
                    Text('Servers', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final s in servers)
                          FilterChip(
                            label: Text(s.name ?? 'Server ${s.id}'),
                            selected: _selectedServers.contains(s.id),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  if (s.id != null) _selectedServers.add(s.id!);
                                } else {
                                  _selectedServers.remove(s.id);
                                  final libs = ref
                                          .read(wizarrLibrariesProvider)
                                          .asData
                                          ?.value ??
                                      const <WizarrLibrary>[];
                                  for (final l in libs) {
                                    if (l.serverId == s.id) {
                                      _selectedLibraries.remove(l.id);
                                    }
                                  }
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Libraries', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final l in visibleLibs)
                          FilterChip(
                            label: Text(l.name ?? 'Library ${l.id}'),
                            selected: _selectedLibraries.contains(l.id),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  if (l.id != null) {
                                    _selectedLibraries.add(l.id!);
                                  }
                                } else {
                                  _selectedLibraries.remove(l.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Expiry', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<int?>(
                      segments: const [
                        ButtonSegment<int?>(value: null, label: Text('Never')),
                        ButtonSegment<int?>(value: 1, label: Text('1')),
                        ButtonSegment<int?>(value: 7, label: Text('7')),
                        ButtonSegment<int?>(value: 30, label: Text('30')),
                      ],
                      selected: {_expiresInDays},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _expiresInDays = selection.first);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Text('Unlimited'),
                        const Spacer(),
                        Switch(
                          value: _unlimited,
                          onChanged: (v) => setState(() => _unlimited = v),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _durationController,
                      enabled: !_unlimited,
                      decoration: const InputDecoration(
                        labelText: 'Duration (days)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Permissions',
                        style: Theme.of(context).textTheme.titleSmall),
                    SwitchListTile(
                      title: const Text('Allow downloads'),
                      value: _allowDownloads,
                      onChanged: (v) => setState(() => _allowDownloads = v),
                    ),
                    SwitchListTile(
                      title: const Text('Allow live TV'),
                      value: _allowLiveTv,
                      onChanged: (v) => setState(() => _allowLiveTv = v),
                    ),
                    SwitchListTile(
                      title: const Text('Allow mobile uploads'),
                      value: _allowMobileUploads,
                      onChanged: (v) =>
                          setState(() => _allowMobileUploads = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Create invite for $_effectiveServerCount servers, '
                      'expires in ${_expiresInDays == null ? 'Never' : '$_expiresInDays days'}?',
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (servers.isEmpty ||
                              _selectedServers.isEmpty ||
                              _submitting)
                          ? null
                          : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSuccess(BuildContext context, WizarrInvitation invitation) {
    final baseUrl = ref.read(wizarrServiceProvider).client.baseUrl;
    final link = invitation.absoluteInviteUrl(baseUrl) ?? invitation.inviteUrl;

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: link ?? ''));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Invite created')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                link ?? '',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy',
                    onPressed: copy,
                  ),
                  TextButton(onPressed: copy, child: const Text('Copy')),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
