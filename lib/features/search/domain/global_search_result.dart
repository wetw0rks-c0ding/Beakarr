import 'package:seekarr/features/settings/domain/service_key.dart';

class GlobalSearchResult {
  final ServiceKey service;
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Map<String, String>? imageHeaders;
  final List<String> tags;
  final String route;
  final Object? routeExtra;
  final String? query;
  final int? seeders;
  final int? size;
  final double? age;

  const GlobalSearchResult({
    required this.service,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.imageHeaders,
    required this.tags,
    required this.route,
    this.routeExtra,
    this.query,
    this.seeders,
    this.size,
    this.age,
  });
}

class GlobalSearchServiceResults {
  final ServiceKey service;
  final List<GlobalSearchResult> results;
  final Object? error;

  const GlobalSearchServiceResults({
    required this.service,
    required this.results,
    this.error,
  });

  bool get hasError => error != null;
}
