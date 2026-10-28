import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/not_configured_placeholder.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_album.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_providers.dart';

class NavidromeArtistScreen extends ConsumerWidget {
  final String artistId;
  final String artistName;

  const NavidromeArtistScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(navidromeArtistAlbumsProvider(artistId));

    return Scaffold(
      appBar: AppBar(title: Text(artistName)),
      body: albumsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          if (e.toString().contains('not configured')) {
            return const NotConfiguredPlaceholder(serviceName: 'Navidrome');
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text('Error: $e', textAlign: TextAlign.center),
            ),
          );
        },
        data: (albums) {
          if (albums.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('No albums found'),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  '$artistName · ${albums.length} album${albums.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: albums.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    return _AlbumTile(album: album);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlbumTile extends ConsumerStatefulWidget {
  final NavidromeAlbum album;

  const _AlbumTile({required this.album});

  @override
  ConsumerState<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends ConsumerState<_AlbumTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey<String>(widget.album.id),
      title: Text(widget.album.name),
      subtitle: Text(
        [
          if (widget.album.artist != null) widget.album.artist!,
          if (widget.album.year != null) '${widget.album.year}',
          if (widget.album.songCount != null)
            '${widget.album.songCount} track${widget.album.songCount == 1 ? '' : 's'}',
        ].join(' · '),
      ),
      onExpansionChanged: (value) => setState(() => _expanded = value),
      children: _expanded
          ? [_AlbumTracks(albumId: widget.album.id)]
          : const <Widget>[],
    );
  }
}

class _AlbumTracks extends ConsumerWidget {
  final String albumId;

  const _AlbumTracks({required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(navidromeAlbumTracksProvider(albumId));

    return tracksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Error: $e'),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('No tracks found'),
          );
        }
        return Column(
          children: tracks.map((track) {
            return ListTile(
              leading: Text(
                track.trackNumber != null ? '${track.trackNumber}' : '',
              ),
              title: Text(track.title),
              trailing: track.durationSeconds > 0
                  ? Text(track.formattedDuration)
                  : null,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Playback not supported')),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}