import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Permanent guard for the floating-nav overlap class of bugs.
///
/// Every scrollable screen inside the shell must reserve bottom space via
/// [FloatingNavBarMetrics], or the last rows scroll underneath the floating
/// nav bar (see the NZBGet/NPM settings-list reports). This test scans all
/// `*_screen.dart` files and fails with instructions when a screen neither
/// references the metrics nor carries a documented exemption below.
///
/// Exemptions (documented, not forgotten):
final Map<String, String> _exemptScreens = {
  // Own flow outside the shell: no floating nav is ever visible.
  'lib/features/onboarding/presentation/onboarding_screen.dart':
      'standalone onboarding flow, no shell nav',
  // The shell hides the nav on these routes (_isImportRoute) and disables
  // extendBody, so Scaffold reserves the space automatically.
  'lib/features/import/presentation/manual_import_browse_screen.dart':
      'nav hidden on import routes',
  'lib/features/import/presentation/manual_import_folder_screen.dart':
      'nav hidden on import routes',
  'lib/features/import/presentation/manual_import_match_screen.dart':
      'nav hidden on import routes',
  'lib/features/import/presentation/manual_import_progress_screen.dart':
      'nav hidden on import routes',
  // Shell chrome itself: Stacks the app bar over [child], scrolls nothing.
  'lib/features/services/presentation/service_dashboard_screen.dart':
      'shell chrome, no own scrollable',
  'lib/features/shell/presentation/shell_screen.dart':
      'shell chrome, no own scrollable',
  // Delegate all scrolling to MediaBrowseScaffold (which pads) or
  // MediaDetailView (viewport-fill slivers).
  'lib/features/movies/presentation/movies_screen.dart':
      'delegates scrolling to MediaBrowseScaffold',
  'lib/features/music/presentation/music_screen.dart':
      'delegates scrolling to MediaBrowseScaffold',
  'lib/features/series/presentation/series_screen.dart':
      'delegates scrolling to MediaBrowseScaffold',
  // SliverAppBar + SliverFillRemaining viewport-fill the body: nothing can
  // scroll underneath the nav (long content lives in MediaDetailView,
  // which pads its own slivers).
  'lib/features/movies/presentation/movie_detail_screen.dart':
      'viewport-fill slivers only',
  'lib/features/series/presentation/series_detail_screen.dart':
      'viewport-fill slivers only',
  'lib/features/music/presentation/music_detail_screen.dart':
      'viewport-fill slivers only, long content in MediaDetailView',
};

void main() {
  test('every shell screen clears the floating nav bar', () {
    final libDir = Directory('lib/features');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run from the repo root',
    );

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      final path = entity.path;
      if (!path.endsWith('_screen.dart')) continue;
      if (_exemptScreens.containsKey(path)) continue;
      final content = File(path).readAsStringSync();
      if (!content.contains('FloatingNavBarMetrics')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These screens never reference FloatingNavBarMetrics, so their '
          'bottom content scrolls under the floating nav bar. Add '
          'getScrollViewBottomPadding(context) to the bottom inset of every '
          'scrollable that can reach the nav (or SliverPadding for slivers) '
          '— see settings_services_screen.dart. If a screen genuinely needs '
          'no clearance, add it to _exemptScreens with the reason why.\n'
          'Offenders:\n${offenders.join('\n')}',
    );
  });
}
