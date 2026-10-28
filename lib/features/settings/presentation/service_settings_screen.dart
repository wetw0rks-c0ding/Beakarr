import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/core/utils/snack_bar_helper.dart';
import 'package:seekarr/core/utils/url_utils.dart';
import 'package:seekarr/core/widgets/section_header.dart';
import 'package:seekarr/features/settings/data/service_connection_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

class ServiceSettingsScreen extends ConsumerStatefulWidget {
  final ServiceKey service;

  const ServiceSettingsScreen({super.key, required this.service});

  @override
  ConsumerState<ServiceSettingsScreen> createState() =>
      _ServiceSettingsScreenState();
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
  bool get isCredentialService => isQbittorrent || isNavidrome;

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
      decoration: const InputDecoration(
        labelText: 'Username',
        hintText: 'Optional',
      ),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      autocorrect: false,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
        hintText: 'Optional',
      ),
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveSettings(),
      obscureText: true,
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
