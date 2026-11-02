import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

import 'package:seekarr/features/nzbget/data/nzbget_service.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_history_item.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_queue_item.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_status.dart';

final nzbgetStatusProvider = FutureProvider.autoDispose<NzbgetStatus>((
  ref,
) async {
  final service = ref.watch(nzbgetServiceProvider);
  return service.getStatus();
});

final nzbgetQueueProvider = FutureProvider.autoDispose<List<NzbgetQueueItem>>((
  ref,
) async {
  final service = ref.watch(nzbgetServiceProvider);
  return service.getQueue();
});

final nzbgetHistoryProvider =
    FutureProvider.autoDispose<List<NzbgetHistoryItem>>((ref) async {
      final service = ref.watch(nzbgetServiceProvider);
      return service.getHistory();
    });

/// NZBIDs selected for a multi-item action.
final nzbgetSelectionProvider = StateProvider.autoDispose<Set<int>>(
  (ref) => {},
);

/// Queue (`0`) or history (`1`).
final nzbgetTabProvider = StateProvider<int>((ref) => 0);

/// History status-prefix filter: `null` = all, else `SUCCESS`/`WARNING`/
/// `FAILURE`/`DELETED`.
final nzbgetHistoryFilterProvider = StateProvider<String?>((ref) => null);

/// Toggled by [NzbgetScreen]'s lifecycle observer so polling stops while the
/// app is backgrounded.
final nzbgetPollingEnabledProvider = StateProvider<bool>((ref) => true);

/// Refreshes status + queue every 5 s. History is intentionally excluded: it
/// only changes on user actions (upload/delete) and is invalidated explicitly
/// by those actions, so polling it would be pure traffic.
final nzbgetPollingProvider = Provider.autoDispose<void>((ref) {
  final enabled = ref.watch(nzbgetPollingEnabledProvider);
  if (!enabled) return;
  final timer = Timer.periodic(const Duration(seconds: 5), (_) {
    ref.invalidate(nzbgetStatusProvider);
    ref.invalidate(nzbgetQueueProvider);
  });
  ref.onDispose(timer.cancel);
});
