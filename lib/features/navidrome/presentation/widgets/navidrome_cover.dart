import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/navidrome/data/navidrome_service.dart';

/// Square cover-art thumbnail for Navidrome artists/albums.
///
/// Builds a fresh authenticated `getCoverArt` URL per widget (same
/// per-request salt/token scheme as the API). Falls back to an icon when
/// the item has no art or the image fails to load.
class NavidromeCover extends ConsumerWidget {
  final String? coverArtId;
  final double size;

  const NavidromeCover({super.key, required this.coverArtId, this.size = 48});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = Icon(Icons.album_rounded, size: 32);
    if (coverArtId == null || coverArtId!.isEmpty) return fallback;
    final url = ref.watch(navidromeServiceProvider).coverArtUrl(coverArtId!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
