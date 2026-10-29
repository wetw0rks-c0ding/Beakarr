import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:flutter/foundation.dart';

final Map<String, bool> bearerCapableServices = {
  'seerr': true,
  'radarr': true,
  'sonarr': true,
  'lidarr': true,
  'prowlarr': true,
  'bazarr': true,
  'qbittorrent': false,
};

class OidcAuthInterceptor extends Interceptor {
  final OidcSessionService _session;
  final String _clientId;
  final String _issuerUrl;
  final String? serviceKey;
  final String? baseUrl;

  OidcAuthInterceptor(this._session, {required String issuerUrl, required String clientId, this.serviceKey, this.baseUrl})
      : _clientId = clientId,
        _issuerUrl = issuerUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final svc = serviceKey ?? 'unknown';
    final allowBearer = bearerCapableServices[svc] ?? false;
    if (allowBearer && _issuerUrl.isNotEmpty && baseUrl != null && baseUrl!.isNotEmpty && svc == 'sonarr') {
      final session = SonarrOidcSessionProvider.getSonarrSession(baseUrl!);
      if (session != null && !session.isExpired()) {
        options.headers['Authorization'] = 'Bearer ${session.serviceToken}';
      }
    } else if (allowBearer && _issuerUrl.isNotEmpty) {
      final token = await _session.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  // Slice-1 Seekarr-UI refresh helper. Unused by the Sonarr pilot (which
  // uses [_doSonarrRefresh]), retained for the remaining slice-1 Bearer
  // services until they migrate to per-service pairs.
  // ignore: unused_element
  Future<bool> _doRefresh() => _session.refresh(_issuerUrl, _clientId);

  /// Per-service Authentik identity for Sonarr: the exchange `subject_token`
  /// must be minted by the `sonarr` provider (`iss .../o/sonarr/`,
  /// `aud=sonarr`). The Seekarr-UI pair (`aud=seekarr`) is never sent here.
  String get _sonarrIssuer =>
      OidcSessionService.perServiceIssuer(_issuerUrl, 'sonarr');
  String get _sonarrClientId =>
      OidcSessionService.perServiceClientId('sonarr');
  Future<bool> _doSonarrRefresh() =>
      _session.refreshFor('sonarr', _sonarrIssuer, _sonarrClientId);
  Future<String?> _sonarrAuthToken() => _session.accessTokenFor('sonarr');
  Future<void> _clearSonarrAuth() => _session.clearFor('sonarr');

  Future<bool> _postExchange(String urlBase, String authToken) async {
    try {
      final res = await http.post(
        Uri.parse('$urlBase/api/auth/oidc/exchange'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $authToken'},
        body: jsonEncode(<String, String>{'subject_token': authToken}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final token = body['token'] as String?;
        if (token == null || token.isEmpty) return false;
        final meRes = await http.get(Uri.parse('$urlBase/api/auth/me'), headers: {'Authorization': 'Bearer $token'});
        if (meRes.statusCode == 200) {
          final meBody = jsonDecode(meRes.body) as Map<String, dynamic>;
          SonarrOidcSessionProvider.update(urlBase, <String, dynamic>{
            ...body,
            'permissions': meBody['permissions'] ?? body['permissions'] ?? <String>[],
            'role': meBody['role'] ?? body['role'] ?? 'ReadOnly',
          });
          if (kDebugMode) debugPrint('Sonarr OIDC cached for $urlBase');
          return true;
        }
        SonarrOidcSessionProvider.update(urlBase, body);
        return true;
      }
      return res.statusCode == 401 ? false : false;
    } catch (e) {
      if (kDebugMode) debugPrint('Exchange error: $e');
      return false;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (status == 401 && baseUrl != null && baseUrl!.isNotEmpty && (serviceKey == 'sonarr' || (serviceKey ?? '') == 'sonarr')) {
      final carriedBearer = (err.requestOptions.headers['Authorization'] as String?)?.startsWith('Bearer ') ?? false;
      if (!carriedBearer) {
        handler.next(err);
        return;
      }
      try {
        final authToken = await _sonarrAuthToken();
        if (authToken == null || authToken.isEmpty) {
          handler.next(err);
          return;
        }
        final hasValid = SonarrOidcSessionProvider.hasValidSession(baseUrl!);
        if (!hasValid) {
          final ok = await _postExchange(baseUrl!, authToken);
          if (ok) {
            final s = SonarrOidcSessionProvider.getSonarrSession(baseUrl!);
            if (s != null) {
              final opts = err.requestOptions..headers['Authorization'] = 'Bearer ${s.serviceToken}';
              try {
                final retry = await Dio(BaseOptions(baseUrl: baseUrl!)).fetch(opts);
                handler.resolve(retry);
                return;
              } catch (_) {}
            }
          } else {
            final refreshed = await _doSonarrRefresh();
            if (refreshed) {
              final newAuth = await _sonarrAuthToken();
              if (newAuth != null && newAuth.isNotEmpty) {
                final ok2 = await _postExchange(baseUrl!, newAuth);
                if (ok2) {
                  final s2 = SonarrOidcSessionProvider.getSonarrSession(baseUrl!);
                  if (s2 != null) {
                    final opts = err.requestOptions..headers['Authorization'] = 'Bearer ${s2.serviceToken}';
                    try {
                      final retry = await Dio(BaseOptions(baseUrl: baseUrl!)).fetch(opts);
                      handler.resolve(retry);
                      return;
                    } catch (_) {}
                  }
                } else {
                  await _clearSonarrAuth();
                  SonarrOidcSessionProvider.clear(baseUrl);
                  handler.reject(DioException(requestOptions: err.requestOptions, error: 'Session expired — log in again', response: err.response));
                  return;
                }
              } else {
                await _clearSonarrAuth();
                SonarrOidcSessionProvider.clear(baseUrl);
                handler.reject(DioException(requestOptions: err.requestOptions, error: 'Session expired — log in again', response: err.response));
                return;
              }
            } else {
              await _clearSonarrAuth();
              SonarrOidcSessionProvider.clear(baseUrl);
              handler.reject(DioException(requestOptions: err.requestOptions, error: 'Session expired — log in again', response: err.response));
              return;
            }
          }
        } else {
          final refreshed = await _doSonarrRefresh();
          if (refreshed) {
            final opts = err.requestOptions;
            final s = SonarrOidcSessionProvider.getSonarrSession(baseUrl!);
            if (s != null) opts.headers['Authorization'] = 'Bearer ${s.serviceToken}';
            else {
              final newAuth = await _sonarrAuthToken();
              if (newAuth != null && newAuth.isNotEmpty) {
                await _postExchange(baseUrl!, newAuth);
                final s2 = SonarrOidcSessionProvider.getSonarrSession(baseUrl!);
                if (s2 != null) opts.headers['Authorization'] = 'Bearer ${s2.serviceToken}';
              }
            }
            try {
              final retry = await Dio(BaseOptions(baseUrl: baseUrl!)).fetch(opts);
              handler.resolve(retry);
              return;
            } catch (_) {}
          } else {
            await _clearSonarrAuth();
            SonarrOidcSessionProvider.clear(baseUrl);
            handler.reject(DioException(requestOptions: err.requestOptions, error: 'Session expired — log in again', response: err.response));
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Interceptor error: $e');
      }
    }
    if (err.requestOptions.headers['Authorization'] != null) {
      err.requestOptions.headers.remove('Authorization');
    }
    handler.next(err);
  }
}
