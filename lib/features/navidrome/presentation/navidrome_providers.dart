import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/navidrome/data/navidrome_service.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_album.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_artist.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_track.dart';

final navidromeArtistsProvider =
    FutureProvider.autoDispose<List<NavidromeArtist>>((ref) async {
  final s = ref.watch(navidromeServiceProvider);
  return s.getArtists();
});

final navidromeAlbumsProvider =
    FutureProvider.autoDispose<List<NavidromeAlbum>>((ref) async {
  final s = ref.watch(navidromeServiceProvider);
  return s.getAlbums();
});

final navidromeAlbumTracksProvider =
    FutureProvider.autoDispose.family<List<NavidromeTrack>, String>((ref, albumId) async {
  final s = ref.watch(navidromeServiceProvider);
  return s.getAlbumTracks(albumId);
});