import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';

enum VerdictSearchStatus {
  complete,
  incomplete,
  unavailable;

  String get wireValue => name;

  static VerdictSearchStatus parse(Object? value) => switch (value) {
        'complete' => VerdictSearchStatus.complete,
        'incomplete' => VerdictSearchStatus.incomplete,
        _ => VerdictSearchStatus.unavailable,
      };
}

class SearchedVerdict {
  const SearchedVerdict({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.kind,
    required this.source,
    required this.issueType,
    this.url,
  });

  final String id;
  final String title;
  final String excerpt;
  final String? url;
  final String kind;
  final String source;
  final String issueType;

  static SearchedVerdict? tryParse(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final id = _nonEmptyText(json['id']);
    final title = _nonEmptyText(json['title']);
    final excerpt = _nonEmptyText(json['excerpt']);
    final kind = _nonEmptyText(json['kind']);
    final source = _nonEmptyText(json['source']);
    final issueType = _nonEmptyText(json['issue_type']);
    if (id == null ||
        title == null ||
        excerpt == null ||
        issueType == null ||
        !{'statute', 'precedent'}.contains(kind) ||
        source != 'user_keyword') {
      return null;
    }
    return SearchedVerdict(
      id: id,
      title: title,
      excerpt: excerpt,
      url: _nonEmptyText(json['url']),
      kind: kind!,
      source: source!,
      issueType: issueType,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'excerpt': excerpt,
        'url': url,
        'kind': kind,
        'source': source,
        'issue_type': issueType,
      };
}

class VerdictSearchResult {
  const VerdictSearchResult({
    required this.provider,
    required this.status,
    required this.query,
    required this.results,
    required this.unknowns,
    this.version,
  });

  final String provider;
  final String? version;
  final VerdictSearchStatus status;
  final String query;
  final List<SearchedVerdict> results;
  final List<String> unknowns;

  bool get isEmpty => results.isEmpty;
  bool get queryMismatch => unknowns.contains('search_query_mismatch');

  Map<String, dynamic> toAnalysis() => {
        'providers': {'law': provider},
        'law': {
          'status': status.wireValue,
          'keywords': [query],
          'evidence': results.map((result) => result.toJson()).toList(),
          'unknowns': unknowns,
        },
      };

  static VerdictSearchResult unavailable(
    String query, {
    String provider = 'unavailable',
    List<String> unknowns = const ['law_service_unavailable'],
  }) =>
      VerdictSearchResult(
        provider: provider,
        status: VerdictSearchStatus.unavailable,
        query: query,
        results: const [],
        unknowns: unknowns,
      );
}

class VerdictSearchService {
  VerdictSearchService({
    Dio? dio,
    Future<String?> Function()? accessToken,
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status != null && status < 500,
            )),
        _accessToken = accessToken ?? _storedAccessToken;

  final Dio _dio;
  final Future<String?> Function() _accessToken;
  VerdictSearchStatus? lastStatus;
  String? lastProvider;

  Future<VerdictSearchResult> search(String query, {int limit = 10}) async {
    final requestedQuery = query.trim();
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      return _remember(VerdictSearchResult.unavailable(requestedQuery));
    }
    final response = await _dio.get(
      '/api/v1/law/search',
      queryParameters: {'q': requestedQuery, 'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200 || response.data is! Map) {
      return _remember(VerdictSearchResult.unavailable(requestedQuery));
    }
    final envelope = Map<String, dynamic>.from(response.data as Map);
    if (envelope['data'] is! Map) {
      return _remember(VerdictSearchResult.unavailable(requestedQuery));
    }
    final data = Map<String, dynamic>.from(envelope['data'] as Map);
    final provider = _text(data['provider']) ?? 'unavailable';
    final responseQuery = _text(data['query']);
    if (responseQuery != requestedQuery) {
      return _remember(VerdictSearchResult.unavailable(
        requestedQuery,
        provider: provider,
        unknowns: const ['search_query_mismatch'],
      ));
    }

    final status = VerdictSearchStatus.parse(data['status']);
    final evidenceAllowed =
        provider == 'real' && status != VerdictSearchStatus.unavailable;
    final results = evidenceAllowed && data['results'] is List
        ? (data['results'] as List)
            .map(SearchedVerdict.tryParse)
            .whereType<SearchedVerdict>()
            .toList(growable: false)
        : const <SearchedVerdict>[];
    final unknowns = data['unknowns'] is List
        ? (data['unknowns'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return _remember(VerdictSearchResult(
      provider: provider,
      version: _text(data['version']),
      status: status,
      query: requestedQuery,
      results: results,
      unknowns: unknowns,
    ));
  }

  VerdictSearchResult _remember(VerdictSearchResult result) {
    lastProvider = result.provider;
    lastStatus = result.status;
    return result;
  }

  static String? _text(Object? value) => _nonEmptyText(value);

  static Future<String?> _storedAccessToken() {
    return const FlutterSecureStorage().read(key: authAccessKey);
  }
}

String? _nonEmptyText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
