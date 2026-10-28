import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_download.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_discover_result.dart';

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

final soulsyncDiscoverQueryProvider = StateProvider<String>((ref) => '');

final soulsyncDiscoverResultsProvider =
    FutureProvider<List<SoulSyncDiscoverResult>>((ref) async {
  final query = ref.watch(soulsyncDiscoverQueryProvider).trim();
  if (query.isEmpty) return const [];
  final s = ref.read(soulsyncServiceProvider);
  return s.search(query);
});
