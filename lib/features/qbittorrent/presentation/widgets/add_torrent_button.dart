import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/theme.dart';
import 'package:seekarr/core/utils/sheet_utils.dart';
import 'package:seekarr/core/utils/snack_bar_helper.dart';
import 'package:seekarr/features/qbittorrent/presentation/qbittorrent_provider.dart';

class AddTorrentButton extends ConsumerWidget {
  const AddTorrentButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.add_rounded, color: AppColors.qbittorrent),
      onPressed: () => _showAddTorrentSheet(context, ref),
      tooltip: 'Add Torrent',
    );
  }

  void _showAddTorrentSheet(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    final categoryController = TextEditingController();
    final savePathController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final pickedFilesNotifier = ValueNotifier<List<PlatformFile>>([]);

    SheetUtils.showSeekarrModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add Torrent',
                    style: Theme.of(ctx2).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Magnet / URL',
                      hintText: 'magnet:?xt=urn:btih:...',
                    ),
                    onChanged: (_) => setModalState(() {}),
                    validator: (v) {
                      if (pickedFilesNotifier.value.isNotEmpty) return null;
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Required';
                      final isMagnet = value.toLowerCase().startsWith(
                        'magnet:',
                      );
                      final isHttp =
                          value.toLowerCase().startsWith('http://') ||
                          value.toLowerCase().startsWith('https://');
                      if (!isMagnet && !isHttp) {
                        return 'Enter a magnet link or an http(s) URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<List<PlatformFile>>(
                    valueListenable: pickedFilesNotifier,
                    builder: (context, files, _) {
                      if (files.isEmpty) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              size: 18,
                            ),
                            label: const Text('Pick .torrent files'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.qbittorrent,
                              side: BorderSide(color: AppColors.qbittorrent),
                            ),
                            onPressed: () async {
                              // Note: FileType.custom extension filters throw
                              // PlatformException(Unsupported filter) on some
                              // Android targets, so accept any file and keep
                              // only .torrent picks (fail-closed otherwise).
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    allowMultiple: true,
                                    type: FileType.any,
                                    withData: true,
                                  );
                              if (result != null && result.files.isNotEmpty) {
                                final torrents = result.files
                                    .where(
                                      (f) => f.name.toLowerCase().endsWith(
                                        '.torrent',
                                      ),
                                    )
                                    .toList(growable: false);
                                if (torrents.isEmpty) {
                                  SnackBarHelper.info(
                                    ctx2,
                                    'No .torrent files selected',
                                  );
                                  return;
                                }
                                pickedFilesNotifier.value = torrents;
                                setModalState(() {});
                              }
                            },
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...files.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.description_rounded,
                                    size: 16,
                                    color: AppColors.qbittorrent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    tooltip: 'Remove',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      pickedFilesNotifier.value = files
                                          .where((x) => x != f)
                                          .toList(growable: false);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add more files'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.qbittorrent,
                            ),
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    allowMultiple: true,
                                    type: FileType.any,
                                    withData: true,
                                  );
                              if (result != null && result.files.isNotEmpty) {
                                final torrents = result.files
                                    .where(
                                      (f) => f.name.toLowerCase().endsWith(
                                        '.torrent',
                                      ),
                                    )
                                    .toList(growable: false);
                                if (torrents.isEmpty) {
                                  SnackBarHelper.info(
                                    ctx2,
                                    'No .torrent files selected',
                                  );
                                  return;
                                }
                                pickedFilesNotifier.value = [
                                  ...files,
                                  ...torrents,
                                ];
                                setModalState(() {});
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: savePathController,
                    decoration: const InputDecoration(
                      labelText: 'Save Path (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.qbittorrent,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final service = ref.read(qbittorrentServiceProvider);
                        final files = pickedFilesNotifier.value;
                        final category = categoryController.text.trim().isEmpty
                            ? null
                            : categoryController.text.trim();
                        final savePath = savePathController.text.trim().isEmpty
                            ? null
                            : savePathController.text.trim();

                        if (files.isNotEmpty) {
                          final multipart = <MultipartFile>[];
                          for (final f in files) {
                            if (f.bytes != null) {
                              multipart.add(
                                MultipartFile.fromBytes(
                                  f.bytes!,
                                  filename: f.name,
                                ),
                              );
                            }
                          }
                          await service.addTorrentFiles(
                            multipart,
                            category: category,
                            savePath: savePath,
                          );
                        } else {
                          await service.addTorrentUrl(
                            urlController.text.trim(),
                            category: category,
                            savePath: savePath,
                          );
                        }
                        ref.invalidate(torrentsProvider);
                        Navigator.of(ctx2).pop();
                        if (context.mounted) {
                          SnackBarHelper.success(
                            context,
                            'Torrent added successfully',
                          );
                        }
                      } catch (e) {
                        SnackBarHelper.error(ctx2, 'Failed to add torrent: $e');
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Add Torrent',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
