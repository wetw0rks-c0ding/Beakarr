import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_download.dart';

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
