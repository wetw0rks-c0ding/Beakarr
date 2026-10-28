import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_album.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_artist.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_track.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

final navidromeServiceProvider = Provider<NavidromeService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.navidromeUrl.isEmpty ||
      settings.navidromeUsername.isEmpty ||
      settings.navidromePassword.isEmpty) {
    throw Exception('Navidrome not configured');
  }
  return NavidromeService(
    ApiClient(
      baseUrl: settings.navidromeUrl,
      auth: SubsonicAuth(
        settings.navidromeUsername,
        settings.navidromePassword,
      ),
    ),
  );
});

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

Map<String, dynamic>? _subsonicResponse(dynamic data) {
  final root = _asMap(data);
  if (root == null) return null;
  return _asMap(root['subsonic-response']);
}

/// Returns true when [data] is a Subsonic response with status "ok".
///
/// Subsonic-compatible servers (including Navidrome) answer failed
/// authentication with HTTP 200 and a body whose `subsonic-response.status`
/// is "failed", so a 2xx status code alone is not sufficient.
bool isSubsonicOk(dynamic data) {
  final sub = _subsonicResponse(data);
  if (sub == null) return false;
  return sub['status'] == 'ok';
}

class NavidromeService {
  final ApiClient client;

  NavidromeService(this.client);

  Future<List<NavidromeArtist>> getArtists() async {
    try {
      final response = await client.get('/rest/getArtists.view');
      if (!isSubsonicOk(response.data)) {
        throw StateError('Navidrome request failed');
      }
      final sub = _subsonicResponse(response.data);
      final artistsNode = _asMap(sub?['artists']);
      final result = <NavidromeArtist>[];
      final index = artistsNode?['index'];
      if (index is List) {
        for (final idx in index) {
          final artistList = _asMap(idx)?['artist'];
          if (artistList is List) {
            for (final a in artistList) {
              final map = _asMap(a);
              if (map != null) result.add(NavidromeArtist.fromJson(map));
            }
          }
        }
      }
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<List<NavidromeAlbum>> getAlbums() async {
    try {
      final response = await client.get(
        '/rest/getAlbumList2.view',
        queryParameters: {'type': 'alphabeticalByName', 'size': 500},
      );
      if (!isSubsonicOk(response.data)) {
        throw StateError('Navidrome request failed');
      }
      final sub = _subsonicResponse(response.data);
      final albumList = _asMap(sub?['albumList2']);
      final albums = albumList?['album'];
      final result = <NavidromeAlbum>[];
      if (albums is List) {
        for (final a in albums) {
          final map = _asMap(a);
          if (map != null) result.add(NavidromeAlbum.fromJson(map));
        }
      }
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<List<NavidromeAlbum>> getArtistAlbums(String artistId) async {
    try {
      final response = await client.get(
        '/rest/getArtist.view',
        queryParameters: {'id': artistId},
      );
      if (!isSubsonicOk(response.data)) {
        throw StateError('Navidrome request failed');
      }
      final sub = _subsonicResponse(response.data);
      final artist = _asMap(sub?['artist']);
      final albums = artist?['album'];
      final result = <NavidromeAlbum>[];
      if (albums is List) {
        for (final a in albums) {
          final map = _asMap(a);
          if (map != null) result.add(NavidromeAlbum.fromJson(map));
        }
      }
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<List<NavidromeTrack>> getAlbumTracks(String albumId) async {
    try {
      final response = await client.get(
        '/rest/getAlbum.view',
        queryParameters: {'id': albumId},
      );
      if (!isSubsonicOk(response.data)) {
        throw StateError('Navidrome request failed');
      }
      final sub = _subsonicResponse(response.data);
      final album = _asMap(sub?['album']);
      final songs = album?['song'];
      final result = <NavidromeTrack>[];
      if (songs is List) {
        for (final s in songs) {
          final map = _asMap(s);
          if (map != null) result.add(NavidromeTrack.fromJson(map));
        }
      }
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      rethrow;
    }
  }

  Future<NavidromeAlbum?> getAlbum(String albumId) async {
    try {
      final response = await client.get(
        '/rest/getAlbum.view',
        queryParameters: {'id': albumId},
      );
      if (!isSubsonicOk(response.data)) {
        return null;
      }
      final sub = _subsonicResponse(response.data);
      final album = _asMap(sub?['album']);
      if (album == null) return null;
      return NavidromeAlbum.fromJson(album);
    } catch (_) {
      return null;
    }
  }
}