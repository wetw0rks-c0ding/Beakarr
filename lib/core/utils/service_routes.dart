class ServiceRoutes {
  ServiceRoutes._();

  static const services = '/services';
  static const seerr = '$services/seerr';
  static const radarr = '$services/radarr';
  static const sonarr = '$services/sonarr';
  static const lidarr = '$services/lidarr';
  static const qbittorrent = '$services/qbittorrent';
  static const bazarr = '$services/bazarr';
  static const prowlarr = '$services/prowlarr';

  static const seerrRequests = '$seerr/requests';
  static const seerrMoviesAll = '$seerr/movies/all';
  static const seerrTvAll = '$seerr/tv/all';
  static const seerrTrendingAll = '$seerr/trending/all';

  static const radarrMovieBase = '$radarr/movie';
  static const sonarrSeriesBase = '$sonarr/series';
  static const lidarrArtistBase = '$lidarr/artist';
  static const nzbget = '$services/nzbget';
  static const npm = '$services/npm';
  static const openmediavault = '$services/openmediavault';
  static const qbittorrentTorrentBase = '$qbittorrent/torrent';
  static const prowlarrSearch = '$prowlarr/search';

  static String radarrMovie(int id, {String? heroTag}) {
    return _withQuery('$radarrMovieBase/$id', {'heroTag': heroTag});
  }

  static String sonarrSeries(int id, {String? heroTag}) {
    return _withQuery('$sonarrSeriesBase/$id', {'heroTag': heroTag});
  }

  static String lidarrArtist(int id, {String? heroTag}) {
    return _withQuery('$lidarrArtistBase/$id', {'heroTag': heroTag});
  }

  static String qbittorrentTorrent(String hash) {
    return '$qbittorrentTorrentBase/$hash';
  }

  static String seerrDetail({
    required String mediaType,
    required int id,
    String? heroTag,
    String? posterUrl,
  }) {
    final normalizedMediaType = mediaType == 'tv' ? 'tv' : 'movie';
    return _withQuery('$seerr/$normalizedMediaType/$id', {
      'heroTag': heroTag,
      'posterUrl': posterUrl,
    });
  }

  static String _withQuery(String path, Map<String, String?> queryParameters) {
    final values = {
      for (final entry in queryParameters.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };

    if (values.isEmpty) {
      return path;
    }

    return Uri(path: path, queryParameters: values).toString();
  }
}
