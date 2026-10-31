import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/core/utils/snack_bar_helper.dart';
import 'package:seekarr/core/utils/url_utils.dart';
import 'package:seekarr/core/widgets/section_header.dart';
import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/settings/data/service_connection_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';
import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_profile.dart';

class ServiceSettingsScreen extends ConsumerStatefulWidget {
  final ServiceKey service;

  const ServiceSettingsScreen({super.key, required this.service});

  @override
  ConsumerState<ServiceSettingsScreen> createState() =>
      _ServiceSettingsScreenState();
}

/// - Empty/failed load (`profiles` empty): keep `savedId` untouched —
///   never wipe a stored selection on a network failure.
/// - Saved id still present: keep it (no silent switches).
/// - Saved id gone (e.g. deleted server-side): null, forcing an
///   explicit re-pick. Must NOT keep the stale id (DropdownButton
///   throws when its value matches no item) and must NOT silently fall
///   back to first (wrong profile).
/// - No saved id: first profile, fresh-setup convenience.
String? resolveSoulSyncProfileSelection({
  required List<SoulSyncProfile> profiles,
  required String? savedId,
}) {
  if (profiles.isEmpty) return savedId;
  final ids = profiles.map((p) => p.id).toSet();
  if (savedId != null && savedId.isNotEmpty && !ids.contains(savedId)) {
    return null;
  }
  return savedId ?? profiles.first.id;
}

class _ServiceSettingsScreenState extends ConsumerState<ServiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  String? _testDetail;

  bool get isQbittorrent => widget.service == ServiceKey.qbittorrent;
  bool get isNavidrome => widget.service == ServiceKey.navidrome;
  bool get isSoulSync => widget.service == ServiceKey.soulsync;
  bool get isCredentialService => isQbittorrent || isNavidrome;

  String? _selectedProfileId;
  List<SoulSyncProfile> _profiles = const [];
  bool _loadingProfiles = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(currentSettingsProvider);
    _urlController = TextEditingController(
      text: settings.urlFor(widget.service),
    );
    _apiKeyController = TextEditingController(
      text: isCredentialService ? '' : settings.apiKeyFor(widget.service),
    );
    _usernameController = TextEditingController(
      text: isCredentialService ? settings.usernameFor(widget.service) : '',
    );
    _passwordController = TextEditingController(
      text: isCredentialService ? settings.passwordFor(widget.service) : '',
    );
    if (isSoulSync) {
      _selectedProfileId = settings.soulsyncProfileId.isEmpty
          ? null
          : settings.soulsyncProfileId;
      // Profiles list is transient screen state (gone on every open),
      // which reads as "the profile disappeared". Auto-load when
      // credentials exist so the picker — and the saved selection —
      // are visible without an extra tap.
      final hasKey = _apiKeyController.text.trim().isNotEmpty;
      final hasCookie = settings.soulsyncProxyCookie.trim().isNotEmpty;
      if (_urlController.text.trim().isNotEmpty && (hasKey || hasCookie)) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadSoulSyncProfiles(silent: true),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final current = ref.read(currentSettingsProvider);
    final updated = _updateServiceSettings(current);

    await ref.read(settingsProvider.notifier).updateSettings(updated);

    if (!mounted) return;

    Navigator.of(context).pop();
    SnackBarHelper.success(context, '${widget.service.title} settings saved');
  }

  SettingsModel _updateServiceSettings(SettingsModel current) {
    if (isQbittorrent) {
      return current.copyWithQbittorrent(
        url: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }
    if (isNavidrome) {
      return current.copyWithNavidrome(
        url: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }
    if (isSoulSync) {
      return current.copyWithSoulSync(
        url: _urlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        profileId: _selectedProfileId ?? '',
      );
    }
    return current.copyWithService(
      widget.service,
      url: _urlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.service.title} Settings'),
        actions: [_buildSaveAction()],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.lg),
            _buildUrlField(),
            const SizedBox(height: AppSpacing.lg),
            if (isCredentialService) _buildUsernameField() else _buildApiKeyField(),
            if (isCredentialService) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildPasswordField(),
            ],
            if (isSoulSync) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildProfilePicker(),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildTestConnectionButton(),
            const SizedBox(height: AppSpacing.sm),
            _buildConnectionStatus(),
            if (_testDetail != null && _testDetail!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                _testDetail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

/// Resolves which profile id the SoulSync picker should hold after a
/// (re)load. Pure for unit testing.
///
  /// Loads SoulSync profiles into the picker. Silent mode (auto-load on
  /// open) skips the missing-credentials snackbar — the fields may
  /// legitimately be empty on first setup. Cookie-SSO setups (no API
  /// key) authenticate via the stored proxy cookie instead.
  Future<void> _loadSoulSyncProfiles({bool silent = false}) async {
    final url = _urlController.text.trim();
    final key = _apiKeyController.text.trim();
    final cookie = ref.read(currentSettingsProvider).soulsyncProxyCookie;
    if (url.isEmpty || (key.isEmpty && cookie.isEmpty)) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the URL and API key first')),
        );
      }
      return;
    }
    setState(() => _loadingProfiles = true);
    ApiClient? client;
    try {
      client = ApiClient(
        baseUrl: url,
        auth: SoulSyncAuth(key, proxyCookie: cookie),
      );
      final service = SoulSyncService(client);
      final profiles = await service
          .getProfiles()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _selectedProfileId = resolveSoulSyncProfileSelection(
          profiles: profiles,
          savedId: _selectedProfileId,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _profiles = const []);
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load profiles: $e')));
      }
    } finally {
      client?.close();
      if (mounted) setState(() => _loadingProfiles = false);
    }
  }

  Widget _buildProfilePicker() {
    // Saved value stays visible even before/after list loads, so the
    // selection never reads as "disappeared".
    final savedProfileId = ref
        .watch(currentSettingsProvider)
        .soulsyncProfileId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _loadingProfiles ? null : () => _loadSoulSyncProfiles(),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_loadingProfiles ? 'Loading…' : 'Load profiles'),
        ),
        if (_profiles.isEmpty && savedProfileId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Saved profile: $savedProfileId',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_profiles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedProfileId),
            initialValue: _selectedProfileId,
            decoration: const InputDecoration(labelText: 'Profile'),
            items: _profiles
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name.isEmpty ? p.id : p.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedProfileId = value),
          ),
        ],
      ],
    );
  }

  Widget _buildTestConnectionButton() {
    return OutlinedButton.icon(
      onPressed: () async {
        final current = ref.read(currentSettingsProvider);
        final updated = _updateServiceSettings(current);
        final result = await testServiceConnection(widget.service, updated);
        if (!mounted) return;
        setState(() => _testDetail = result.detail);
      },
      icon: const Icon(Icons.network_check_rounded),
      label: const Text('Test Connection'),
    );
  }

  Widget _buildConnectionStatus() {
    final colorScheme = Theme.of(context).colorScheme;
    final asyncStatus = ref.watch(serviceConnectionProvider(widget.service));

    final (Widget icon, String text, Color color) = asyncStatus.when(
      loading: () => (
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Testing connection…',
        colorScheme.onSurfaceVariant,
      ),
      error: (_, __) => (
        Icon(Icons.cloud_off_rounded, size: 16, color: colorScheme.error),
        'Connection failed — check URL, credentials and network',
        colorScheme.error,
      ),
      data: (status) => switch (status) {
        ServiceConnectionStatus.connected => (
            Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
            'Connected',
            AppColors.success,
          ),
        ServiceConnectionStatus.disconnected => (
            Icon(Icons.cloud_off_rounded, size: 16, color: colorScheme.error),
            'Connection failed — check URL, credentials and network',
            colorScheme.error,
          ),
        ServiceConnectionStatus.checking => (
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            'Testing connection…',
            colorScheme.onSurfaceVariant,
          ),
        ServiceConnectionStatus.notConfigured => (
            Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
            'Enter the server details above, then test',
            colorScheme.onSurfaceVariant,
          ),
      },
    );

    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveAction() {
    return TextButton.icon(
      onPressed: _saveSettings,
      icon: const Icon(Icons.check_rounded),
      label: const Text('Save'),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SectionHeader(
      title: widget.service.title,
      trailing: Icon(
        widget.service.icon,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: _urlController,
      decoration: const InputDecoration(
        labelText: 'Server URL',
        hintText: 'https://',
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      validator: UrlUtils.validateServiceUrl,
    );
  }

  Widget _buildApiKeyField() {
    return TextFormField(
      controller: _apiKeyController,
      decoration: InputDecoration(
        labelText: 'API Key',
        hintText: 'Enter your API key',
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: _copyApiKey,
          tooltip: 'Copy API key',
        ),
      ),
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveSettings(),
      obscureText: true,
      validator: _validateApiKey,
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: isNavidrome ? 'Username' : 'Username',
        hintText: isNavidrome ? null : 'Optional',
      ),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      validator: isNavidrome
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: isNavidrome ? null : 'Optional',
      ),
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveSettings(),
      obscureText: true,
      validator: isNavidrome
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Password is required';
              }
              return null;
            }
          : null,
    );
  }

  String? _validateApiKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'API Key is required';
    }

    return null;
  }

  void _copyApiKey() {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: apiKey));
      SnackBarHelper.info(context, 'API key copied to clipboard');
    }
  }
}
