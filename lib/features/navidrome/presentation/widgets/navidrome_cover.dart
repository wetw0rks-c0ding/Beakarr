import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/navidrome/data/navidrome_service.dart';

/// Cover-art URL for one item, computed once per id.
///
/// Subsonic auth embeds a fresh random salt per URL, so calling
/// [NavidromeService.coverArtUrl] during every build would defeat
/// [Image.network]'s URL-keyed cache (flicker + refetch on scroll-back).
/// A family provider keeps the URL stable for the widget's lifetime.
final navidromeCoverUrlProvider =
    Provider.autoDispose.family<String, String>((ref, coverArtId) {
  return ref.watch(navidromeServiceProvider).coverArtUrl(coverArtId);
});

/// Square cover-art thumbnail for Navidrome artists/albums.
///
/// Falls back to an icon when the item has no art or the image fails to load.
class NavidromeCover extends ConsumerWidget {
  final String? coverArtId;
  final double size;

  const NavidromeCover({super.key, required this.coverArtId, this.size = 48});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = Icon(Icons.album_rounded, size: 32);
    if (coverArtId == null || coverArtId!.isEmpty) return fallback;
    final url = ref.watch(navidromeCoverUrlProvider(coverArtId!));
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
