import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';

class WizarrService {
  final WizarrClient client;

  WizarrService(this.client);

  Future<List<WizarrInvitation>> getInvitations() async {
    final response = await client.rpc('Invitation', 'getAll');
    return _items(response, WizarrInvitation.fromJson, const ['invitations']);
  }

  Future<List<WizarrUser>> getUsers() async {
    final response = await client.rpc('User', 'getAll');
    return _items(response, WizarrUser.fromJson, const ['users']);
  }

  /// Unwraps a list from the RPC response. Envelope precedence:
  /// explicit [envelopeKeys] first, then generic `data`/`results`/`items`/
  /// `list`, then the first list-valued entry, then a bare top-level array.
  /// An empty or unrecognised map yields an empty list. Anything that is
  /// neither a Map nor a List (e.g. an HTML login page from a wrong URL)
  /// throws [WizarrException] so the screen shows an error, not "No items".
  static List<T> _items<T>(
    dynamic response,
    T Function(Map<String, dynamic>) fromJson,
    List<String> envelopeKeys,
  ) {
    dynamic data = response;
    if (response is Map) {
      // Try explicit envelope keys first, then generic ones, then first list.
      for (final key in [...envelopeKeys, 'data', 'results', 'items', 'list']) {
        if (response[key] is List) {
          data = response[key];
          break;
        }
      }
      if (data == response) {
        // No recognised list key: look for any list value.
        for (final v in response.values) {
          if (v is List) {
            data = v;
            break;
          }
        }
      }
    }
    if (data is! List) {
      if (response is Map) return const [];
      throw const WizarrException(
        message: 'Unexpected response from Wizarr (not a JSON list)',
      );
    }
    final items = <T>[];
    for (final item in data) {
      final map = item is Map<String, dynamic>
          ? item
          : (item is Map ? Map<String, dynamic>.from(item) : null);
      if (map != null) items.add(fromJson(map));
    }
    return items;
  }
}
