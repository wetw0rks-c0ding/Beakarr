import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_server.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_library.dart';
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

  /// Get all servers from the Wizarr API.
  Future<List<WizarrServer>> getServers() async {
    final response = await client.rpc('Server', 'getAll');
    return _items(response, WizarrServer.fromJson, const ['servers']);
  }

  /// Get all libraries from the Wizarr API.
  Future<List<WizarrLibrary>> getLibraries() async {
    final response = await client.rpc('Library', 'getAll');
    return _items(response, WizarrLibrary.fromJson, const ['libraries']);
  }

  /// Creates a guest invitation via POST to /api/invitations.
  /// Only allowed via the [post()] method; throws [StateError] for other mutations.
  Future<WizarrInvitation> createInvitation({
    required List<int> serverIds,
    List<int> libraryIds = const [],
    int? expiresInDays,
    String? duration,
    bool? unlimited,
    bool allowDownloads = true,
    bool allowLiveTv = true,
    bool allowMobileUploads = true,
  }) async {
    // Argument validation before I/O
    if (serverIds.isEmpty) {
      throw ArgumentError('serverIds cannot be empty');
    }

    final payload = <String, dynamic>{
      'server_ids': serverIds,
      'expires_in_days': expiresInDays,
      'duration': duration,
      'unlimited': unlimited ?? false,
      'library_ids': libraryIds,
      'allow_downloads': allowDownloads,
      'allow_live_tv': allowLiveTv,
      'allow_mobile_uploads': allowMobileUploads,
    };

    final response = await client.post('Invitation', 'create', payload);
    return _mapToInvitation(response);
  }

  /// Revokes (deletes) a guest invitation via DELETE /api/invitations/{id}.
  /// Returns true on success; exceptions propagate untouched.
  Future<bool> revokeInvitation({required int id}) async {
    await client.deleteInvitation(id: id);
    return true;
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

  /// Maps a raw RPC response to [WizarrInvitation].
  /// Handles both 201 (created) and 200 responses, extracting the invitation object.
  static WizarrInvitation _mapToInvitation(dynamic response) {
    dynamic data = response;
    
    // Check for common envelope keys
    if (response is Map) {
      for (final key in ['invitation', 'data']) {
        if (response[key] != null) {
          data = response[key];
          break;
        }
      }
    }
    
    if (data is! Map) {
      throw const WizarrException(
        message: 'Unexpected response from createInvitation (not an invitation object)',
      );
    }

    final map = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data);
    final invitation = WizarrInvitation.fromJson(map);
    if (invitation.code == null) {
      throw const WizarrException(
        message: 'Invalid invitation response (missing code or id)',
      );
    }
    return invitation;
  }
}
