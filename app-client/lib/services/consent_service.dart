import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

const legalReferenceWarning = 'AI 분석은 참고용이며 법적 효력이 없습니다. 최종 판단은 전문가에게 확인하세요.';

enum ConsentDocument { privacy, location, externalAi }

extension ConsentDocumentApi on ConsentDocument {
  String get apiName => switch (this) {
        ConsentDocument.privacy => 'privacy',
        ConsentDocument.location => 'location',
        ConsentDocument.externalAi => 'external_ai',
      };

  static ConsentDocument? tryParse(Object? value) => switch (value) {
        'privacy' => ConsentDocument.privacy,
        'location' => ConsentDocument.location,
        'external_ai' => ConsentDocument.externalAi,
        _ => null,
      };
}

class PolicyDocument {
  const PolicyDocument({
    required this.document,
    required this.version,
    required this.title,
    required this.text,
    required this.required,
  });

  final ConsentDocument document;
  final String version;
  final String title;
  final String text;
  final bool required;

  factory PolicyDocument.fromJson(Map<String, dynamic> json) {
    final document = ConsentDocumentApi.tryParse(json['document']);
    final version = json['version'];
    final fallbackTitle = json['title'];
    final fallbackText = json['text'];
    final title = json['title_ko'] is String &&
            (json['title_ko'] as String).trim().isNotEmpty
        ? json['title_ko']
        : fallbackTitle;
    final text = json['text_ko'] is String &&
            (json['text_ko'] as String).trim().isNotEmpty
        ? json['text_ko']
        : fallbackText;
    final required = json['required'];
    if (document == null ||
        version is! String ||
        version.isEmpty ||
        title is! String ||
        title.isEmpty ||
        text is! String ||
        text.isEmpty ||
        required is! bool) {
      throw const ConsentServiceException('정책 문서 응답이 올바르지 않습니다.');
    }
    return PolicyDocument(
      document: document,
      version: version,
      title: title,
      text: text,
      required: required,
    );
  }
}

class PolicyBundle {
  const PolicyBundle({
    required this.version,
    required this.disclaimer,
    required this.documents,
  });

  final String version;
  final String disclaimer;
  final List<PolicyDocument> documents;
}

class ConsentSnapshot {
  const ConsentSnapshot({required this.version, required this.grants});

  final String version;
  final Map<ConsentDocument, bool> grants;

  bool isGranted(ConsentDocument document) => grants[document] == true;
  bool get canCollect =>
      isGranted(ConsentDocument.privacy) && isGranted(ConsentDocument.location);
  bool get canUseExternalAi => isGranted(ConsentDocument.externalAi);
}

class ConsentServiceException implements Exception {
  const ConsentServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ConsentService {
  ConsentService({
    Dio? dio,
    required Future<String?> Function() accessToken,
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (status) => status != null && status < 500,
            )),
        _accessToken = accessToken;

  final Dio _dio;
  final Future<String?> Function() _accessToken;

  Future<PolicyBundle> fetchPolicies() async {
    final response = await _dio.get('/api/v1/policies');
    if (response.statusCode != 200) {
      throw const ConsentServiceException('정책 문서를 불러오지 못했습니다.');
    }
    final data = _data(response);
    final version = data['version'];
    final disclaimer = data['disclaimer'];
    final documents = data['documents'];
    if (version is! String ||
        version.trim().isEmpty ||
        version.length > 64 ||
        disclaimer is! String ||
        documents is! List) {
      throw const ConsentServiceException('정책 문서 응답이 올바르지 않습니다.');
    }
    final parsed = documents
        .map((item) => PolicyDocument.fromJson(_map(item)))
        .toList(growable: false);
    if (parsed.length != ConsentDocument.values.length ||
        parsed.map((item) => item.document).toSet().length !=
            ConsentDocument.values.length ||
        parsed.any((item) => item.version != version)) {
      throw const ConsentServiceException('필수 정책 문서가 누락되었습니다.');
    }
    return PolicyBundle(
      version: version,
      disclaimer: disclaimer,
      documents: parsed,
    );
  }

  Future<ConsentSnapshot> fetchConsents() async {
    final options = await _authOptions();
    final grants = <ConsentDocument, bool>{};
    String? cursor;
    String version = '2026-10-15';
    do {
      final response = await _dio.get(
        '/api/v1/consents',
        queryParameters: {
          'limit': 100,
          if (cursor != null) 'cursor': cursor,
        },
        options: options,
      );
      if (response.statusCode != 200) {
        throw const ConsentServiceException('동의 상태를 불러오지 못했습니다.');
      }
      final data = _data(response);
      if (data['version'] is String) version = data['version'] as String;
      final rawGrants = data['grants'];
      if (rawGrants is Map) {
        for (final document in ConsentDocument.values) {
          grants[document] = rawGrants[document.apiName] == true;
        }
        cursor = null;
        continue;
      }
      final consents = data['consents'];
      if (consents is! List) {
        throw const ConsentServiceException('동의 상태 응답이 올바르지 않습니다.');
      }
      for (final item in consents) {
        final consent = _map(item);
        final document = ConsentDocumentApi.tryParse(consent['document']);
        if (document == null || consent['version'] != version) continue;
        grants.putIfAbsent(document, () => consent['revoked_at'] == null);
      }
      cursor = data['next_cursor'] is String &&
              (data['next_cursor'] as String).isNotEmpty
          ? data['next_cursor'] as String
          : null;
    } while (cursor != null);
    return ConsentSnapshot(
      version: version,
      grants: {
        for (final document in ConsentDocument.values)
          document: grants[document] == true,
      },
    );
  }

  Future<void> setConsent({
    required ConsentDocument document,
    required String version,
    required bool granted,
  }) async {
    final response = await _dio.put(
      '/api/v1/consents/${document.apiName}',
      data: {'version': version, 'granted': granted},
      options: await _authOptions(),
    );
    if (response.statusCode != 200) {
      throw const ConsentServiceException('동의 상태를 저장하지 못했습니다.');
    }
  }

  Future<Options> _authOptions() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ConsentServiceException('로그인이 필요합니다.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  static Map<String, dynamic> _data(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map || body['data'] is! Map) {
      throw const ConsentServiceException('서버 응답이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const ConsentServiceException('정책 문서 항목이 올바르지 않습니다.');
  }
  return Map<String, dynamic>.from(value);
}

final consentServiceProvider = Provider<ConsentService>((ref) {
  return ConsentService(
    accessToken: () => ref.read(authProvider.notifier).validAccessToken(),
  );
});

enum ConsentLoadStatus { idle, loading, ready, error }

class ConsentState {
  const ConsentState({
    this.status = ConsentLoadStatus.idle,
    this.policies,
    this.snapshot,
    this.error,
  });

  final ConsentLoadStatus status;
  final PolicyBundle? policies;
  final ConsentSnapshot? snapshot;
  final String? error;

  bool get canCollect => snapshot?.canCollect == true;
  bool get canUseExternalAi => snapshot?.canUseExternalAi == true;
  bool get needsRequiredConsent =>
      status == ConsentLoadStatus.ready && !canCollect;

  ConsentState copyWith({
    ConsentLoadStatus? status,
    PolicyBundle? policies,
    ConsentSnapshot? snapshot,
    String? error,
  }) =>
      ConsentState(
        status: status ?? this.status,
        policies: policies ?? this.policies,
        snapshot: snapshot ?? this.snapshot,
        error: error,
      );
}

class ConsentController extends StateNotifier<ConsentState> {
  ConsentController({required ConsentService service})
      : _service = service,
        super(const ConsentState());

  final ConsentService _service;
  final Map<ConsentDocument, int> _grantSequences = {};
  final Map<ConsentDocument, Future<void>> _grantWrites = {};

  Future<void> load() async {
    state = state.copyWith(status: ConsentLoadStatus.loading);
    try {
      final values = await Future.wait([
        _service.fetchPolicies(),
        _service.fetchConsents(),
      ]);
      if (!mounted) return;
      final policies = values[0] as PolicyBundle;
      final snapshot = values[1] as ConsentSnapshot;
      state = ConsentState(
        status: ConsentLoadStatus.ready,
        policies: policies,
        snapshot: snapshot.version == policies.version
            ? snapshot
            : ConsentSnapshot(version: policies.version, grants: const {}),
      );
    } on Object catch (error) {
      if (!mounted) return;
      state = ConsentState(
        status: ConsentLoadStatus.error,
        error: error.toString(),
      );
    }
  }

  Future<void> setGrant(ConsentDocument document, bool granted) {
    final policies = state.policies;
    if (policies == null || state.snapshot == null) return Future.value();
    final sequence = (_grantSequences[document] ?? 0) + 1;
    _grantSequences[document] = sequence;

    final operation = _setGrantAfter(
      predecessor: _grantWrites[document],
      document: document,
      version: policies.version,
      granted: granted,
      sequence: sequence,
    );
    _grantWrites[document] = operation;
    return operation.whenComplete(() {
      if (identical(_grantWrites[document], operation)) {
        _grantWrites.remove(document);
      }
    });
  }

  Future<void> _setGrantAfter({
    required Future<void>? predecessor,
    required ConsentDocument document,
    required String version,
    required bool granted,
    required int sequence,
  }) async {
    if (predecessor != null) {
      try {
        await predecessor;
      } catch (_) {
        // A failed write must not prevent the user's newer intent from running.
      }
    }
    await _service.setConsent(
      document: document,
      version: version,
      granted: granted,
    );
    if (!mounted || _grantSequences[document] != sequence) return;
    final latest = state.snapshot;
    if (latest == null || latest.version != version) return;
    state = state.copyWith(
      snapshot: ConsentSnapshot(
        version: version,
        grants: {...latest.grants, document: granted},
      ),
    );
  }
}

final consentControllerProvider =
    StateNotifierProvider<ConsentController, ConsentState>((ref) {
  final service = ref.read(consentServiceProvider);
  final controller = ConsentController(service: service);
  final auth = ref.watch(authProvider);
  if (auth.status == AuthStatus.authenticated) {
    Future<void>.microtask(controller.load);
  }
  return controller;
});
