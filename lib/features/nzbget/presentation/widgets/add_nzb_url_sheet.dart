import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_actions.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_provider.dart';

/// Bottom sheet that adds an NZB by URL.
///
/// NZBGet fetches the file itself, so no upload/multipart path is needed.
class AddNzbUrlSheet extends ConsumerStatefulWidget {
  const AddNzbUrlSheet({super.key});

  @override
  ConsumerState<AddNzbUrlSheet> createState() => _AddNzbUrlSheetState();
}

class _AddNzbUrlSheetState extends ConsumerState<AddNzbUrlSheet> {
  static const _priorities = <int, String>{
    -100: 'Very low',
    -50: 'Low',
    0: 'Normal',
    50: 'High',
    100: 'Very high',
    900: 'Force',
  };

  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _categoryController = TextEditingController();

  int _priority = 0;
  bool _addPaused = false;
  bool _submitting = false;

  @override
  void dispose() {
    _urlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_link_rounded, color: AppColors.nzbget),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Add NZB by URL',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/release.nzb',
                border: OutlineInputBorder(),
              ),
              validator: _validateUrl,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _categoryController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in _priorities.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add paused'),
              value: _addPaused,
              onChanged: (value) => setState(() => _addPaused = value),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Add to queue'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.nzbget,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'URL is required';
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return 'Enter a valid URL';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final ok = await runNzbgetAction(
      context,
      ref,
      action: (service) => service.addUrl(
        _urlController.text.trim(),
        category: _categoryController.text.trim(),
        priority: _priority,
        paused: _addPaused,
      ),
      successMessage: 'NZB added',
      failureMessage: 'Failed to add NZB',
      invalidate: [nzbgetStatusProvider, nzbgetQueueProvider],
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitting = false);
    }
  }
}
