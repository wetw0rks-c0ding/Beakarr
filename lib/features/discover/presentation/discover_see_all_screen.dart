import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/core/models/media_preview.dart';
import 'package:seekarr/core/utils/service_routes.dart';
import 'package:seekarr/core/widgets/content_card.dart';
import 'package:seekarr/features/discover/presentation/discover_provider.dart';

class DiscoverSeeAllScreen extends ConsumerStatefulWidget {
  final String type; // 'movies', 'tv', 'trending'
  final String title;

  const DiscoverSeeAllScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  ConsumerState<DiscoverSeeAllScreen> createState() =>
      _DiscoverSeeAllScreenState();
}

class _DiscoverSeeAllScreenState extends ConsumerState<DiscoverSeeAllScreen> {
  late final PagingController<int, MediaPreview> _pagingController;

  @override
  void initState() {
    _pagingController = PagingController<int, MediaPreview>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: (pageKey) => _fetchPage(pageKey),
    );
    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<List<MediaPreview>> _fetchPage(int pageKey) async {
    // Determine which provider family to use based on type
    late Future<List<MediaPreview>> future;

    switch (widget.type) {
      case 'movies':
        future = ref.read(discoverMoviesPageProvider(pageKey).future);
        break;
      case 'tv':
        future = ref.read(discoverTVPageProvider(pageKey).future);
        break;
      case 'trending':
        // Trending implies all, but usually mixed or dependent on implementation.
        // Seerr trending endpoint returns mixed results.
        future = ref.read(discoverTrendingPageProvider(pageKey).future);
        break;
      default:
        throw Exception('Unknown type: ${widget.type}');
    }

    final newItems = await future;
    return newItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PagingListener<int, MediaPreview>(
        controller: _pagingController,
        builder: (context, state, fetchNextPage) =>
            PagedGridView<int, MediaPreview>(
              state: state,
              fetchNextPage: fetchNextPage,
              // Nav clearance (see settings_services_screen.dart).
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + FloatingNavBarMetrics.getScrollViewBottomPadding(context),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: AppSpacing.gridGap,
                mainAxisSpacing: AppSpacing.gridGap,
              ),
              builderDelegate: PagedChildBuilderDelegate<MediaPreview>(
                itemBuilder: (context, item, index) {
                  final posterPath = item.posterPath;
                  final imageUrl = posterPath != null
                      ? 'https://image.tmdb.org/t/p/w500$posterPath'
                      : '';

                  final mediaType =
                      item.mediaType; // Might be mixed for trending
                  final heroTag =
                      'discover_seeall_${mediaType}_${item.id}_$index';

                  return GestureDetector(
                    onTap: () {
                      context.push(
                        ServiceRoutes.seerrDetail(
                          mediaType: mediaType,
                          id: item.id,
                          heroTag: heroTag,
                          posterUrl: imageUrl,
                        ),
                      );
                    },
                    child: Hero(
                      tag: heroTag,
                      child: ContentCard(imageUrl: imageUrl),
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }
}
