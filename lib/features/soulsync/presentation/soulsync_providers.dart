import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_download.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_discover_item.dart';

final soulsyncWishlistProvider =
    FutureProvider.autoDispose<List<SoulSyncWishlistItem>>((ref) async {
  final s = ref.watch(soulsyncServiceProvider);
  return s.getWishlist();
});

final soulsyncDownloadsProvider =
    FutureProvider.autoDispose<List<SoulSyncDownload>>((ref) async {
  final s = ref.watch(soulsyncServiceProvider);
  return s.getDownloads();
});

/// One pool page for user-driven "Load more" pagination.
final soulsyncDiscoveryPoolPageProvider = FutureProvider.autoDispose
    .family<({List<SoulSyncDiscoverItem> items, bool hasNext}), int>((
  ref,
  page,
) async {
  final s = ref.watch(soulsyncServiceProvider);
  return s.getDiscoveryPoolPage(page: page);
});

final soulsyncDiscoveryBubblesProvider =
    FutureProvider.autoDispose<List<SoulSyncDiscoverItem>>((ref) async {
  final s = ref.watch(soulsyncServiceProvider);
  return s.getDiscoveryBubbles();
});

final soulsyncSimilarArtistsProvider =
    FutureProvider.autoDispose<List<SoulSyncDiscoverItem>>((ref) async {
  final s = ref.watch(soulsyncServiceProvider);
  return s.getSimilarArtists();
});

final soulsyncRecentReleasesProvider =
    FutureProvider.autoDispose<List<SoulSyncDiscoverItem>>((ref) async {
  final s = ref.watch(soulsyncServiceProvider);
  return s.getRecentReleases();
});
