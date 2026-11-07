import 'package:dio/dio.dart';

typedef AccessTokenProvider = Future<String?> Function();

final RegExp _backendCaseIdPattern = RegExp(r'^case_[0-9a-f]{32}$');
const _providerStates = {'absent', 'mock', 'real', 'unavailable'};
const _reportStatuses = {'complete', 'incomplete', 'unavailable'};

enum ModelReportStatus { complete, incomplete, unavailable }

class LawReference {
  const LawReference({
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
}

class LawIssue {
  const LawIssue({
    required this.label,
    required this.source,
    required this.legalRole,
    required this.issueType,
  });

  final String label;
  final String source;
  final String legalRole;
  final String issueType;
}

class LawReportResult {
  const LawReportResult({
    required this.status,
    required this.keywords,
    required this.references,
    required this.issues,
    required this.unknowns,
  });

  final String status;
  final List<String> keywords;
  final List<LawReference> references;
  final List<LawIssue> issues;
  final List<String> unknowns;

  bool get isAvailable => status == 'complete' && references.isNotEmpty;

  factory LawReportResult.fromAnalysis(Map<String, dynamic> analysis) {
    final raw = analysis['law'];
    if (raw is! Map) {
      return const LawReportResult(
        status: 'unavailable',
        keywords: [],
        references: [],
        issues: [],
        unknowns: ['law_result_missing'],
      );
    }
    final law = Map<String, dynamic>.from(raw);
    final provider = _mapOrNull(analysis['providers'])?['law'];
    final declaredStatus = _text(law['status']);
    final evidenceAllowed = provider == 'real' &&
        {'complete', 'incomplete'}.contains(declaredStatus);
    final references = <LawReference>[];
    final evidence = law['evidence'];
    if (evidenceAllowed && evidence is List) {
      for (final value in evidence) {
        if (value is! Map) continue;
        final item = Map<String, dynamic>.from(value);
        final id = _text(item['id']);
        final issueType = _text(item['issue_type']);
        final title = _text(item['title']);
        final excerpt = _text(item['excerpt']);
        final kind = _text(item['kind']);
        final source = _text(item['source']);
        if (id == null ||
            issueType == null ||
            title == null ||
            excerpt == null ||
            kind == null ||
            source == null ||
            !{'statute', 'precedent'}.contains(kind) ||
            !{'video', 'user_keyword'}.contains(source)) {
          continue;
        }
        references.add(LawReference(
          id: id,
          title: title,
          excerpt: excerpt,
          url: _canonicalUrl(item['url']),
          kind: kind,
          source: source,
          issueType: issueType,
        ));
      }
    }

    final issues = <LawIssue>[];
    final issueValues = law['issues'];
    if (evidenceAllowed && issueValues is List) {
      for (final value in issueValues) {
        if (value is! Map) continue;
        final item = Map<String, dynamic>.from(value);
        final label = _text(item['label']);
        final source = _text(item['source']);
        final role = _text(item['legal_role']);
        final issueType = _text(item['issue_type']);
        final validRole = source == 'video'
            ? {'rule_candidate', 'hint_only'}.contains(role)
            : source == 'user_keyword' && role == 'search_only';
        if (label != null &&
            issueType != null &&
            source != null &&
            role != null &&
            validRole) {
          issues.add(LawIssue(
            label: label,
            source: source,
            legalRole: role,
            issueType: issueType,
          ));
        }
      }
    }

    final keywords = law['keywords'] is List
        ? (law['keywords'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    final unknowns = law['unknowns'] is List
        ? (law['unknowns'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return LawReportResult(
      status: evidenceAllowed ? declaredStatus! : 'unavailable',
      keywords: keywords,
      references: references,
      issues: issues,
      unknowns: unknowns,
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String? _canonicalUrl(Object? value) {
    final text = _text(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        (uri.host != 'law.go.kr' && uri.host != 'www.law.go.kr') ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    const forbidden = {
      'oc',
      'token',
      'key',
      'signature',
      'access_token',
      'authorization',
      'credential',
      'credentials',
      'secret',
      'password',
      'passwd',
      'api_key',
      'apikey',
      'x-api-key',
    };
    for (final name in uri.queryParametersAll.keys) {
      final normalized = name.toLowerCase();
      if (forbidden.contains(normalized) || normalized.startsWith('x-amz-')) {
        return null;
      }
    }
    return text;
  }
}

class SyntheticDemoContext {
  const SyntheticDemoContext({
    required this.address,
    required this.condition,
    required this.temperatureC,
    required this.precipitationMm,
  });

  final String address;
  final String condition;
  final double temperatureC;
  final double precipitationMm;

  String get pdfAddress => '[합성 목업 · 실제 사고 위치 아님] $address';

  String get pdfWeatherText => '[합성 목업 · 실제 사고 기상 아님] $condition · '
      '${_formatNumber(temperatureC)}℃ · 강수 ${_formatNumber(precipitationMm)}mm';

  static SyntheticDemoContext? tryParse(Object? value) {
    final context = _mapOrNull(value);
    if (context == null ||
        context['kind'] != 'synthetic_demo' ||
        context['is_mock'] is! bool ||
        context['is_mock'] != true ||
        context['provider'] != 'mock' ||
        context['source'] != 'gangnam_station_fixture') {
      return null;
    }
    final address = context['address'];
    final weather = _mapOrNull(context['weather']);
    final condition = weather?['condition'];
    final temperature = weather?['temperature_c'];
    final precipitation = weather?['precipitation_mm'];
    if (address is! String ||
        address.isEmpty ||
        address.length > 255 ||
        condition is! String ||
        condition.isEmpty ||
        condition.length > 64 ||
        temperature is! num ||
        !temperature.isFinite ||
        temperature < -100 ||
        temperature > 100 ||
        precipitation is! num ||
        !precipitation.isFinite ||
        precipitation < 0 ||
        precipitation > 10000 ||
        weather?['observed_at'] != null) {
      return null;
    }
    return SyntheticDemoContext(
      address: address,
      condition: condition,
      temperatureC: temperature.toDouble(),
      precipitationMm: precipitation.toDouble(),
    );
  }

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class CaseRoadSelection {
  const CaseRoadSelection({
    required this.place,
    required this.otherAction,
    required this.isUserSelected,
    required this.automaticStatus,
    required this.raw,
  });

  final int? place;
  final String? otherAction;
  final bool isUserSelected;
  final String? automaticStatus;
  final Map<String, dynamic> raw;

  factory CaseRoadSelection.fromRoad(Object? value) {
    final road = _mapOrNull(value) ?? const <String, dynamic>{};
    final selected = _mapOrNull(road['selected']);
    final modelInput =
        _mapOrNull(road['model_input']) ?? const <String, dynamic>{};
    final automatic =
        _mapOrNull(road['automatic']) ?? const <String, dynamic>{};
    final selectedPlace = selected?['place'];
    final inputPlace = modelInput['place'];
    final place = selectedPlace is int ? selectedPlace : inputPlace;
    final selectedAction = selected?['other_action'];
    final inputAction = modelInput['other_action'];
    return CaseRoadSelection(
      place: place is int && place >= 0 && place <= 7 ? place : null,
      otherAction: selectedAction is String
          ? selectedAction
          : inputAction is String
              ? inputAction
              : null,
      isUserSelected: selected != null,
      automaticStatus:
          automatic['status'] is String ? automatic['status'] as String : null,
      raw: road,
    );
  }
}

class VehicleMovements {
  const VehicleMovements({this.ego, this.other});

  final String? ego;
  final String? other;

  Map<String, String>? toJson() {
    final values = <String, String>{};
    for (final entry in {'ego': ego, 'other': other}.entries) {
      final value = entry.value?.trim();
      if (value == null || value.isEmpty) continue;
      if (value.length > 500) {
        throw const ModelAnalysisException('차량 움직임 설명은 500자 이하여야 합니다.');
      }
      values[entry.key] = value;
    }
    return values.isEmpty ? null : values;
  }
}

class SpeedDemo {
  const SpeedDemo(
      {required this.valueKmh, required this.source, required this.isMock});

  final int valueKmh;
  final String source;
  final bool isMock;

  static SpeedDemo? tryParse(Object? value) {
    final json = _mapOrNull(value);
    final speed = json?['value_kmh'];
    if (json == null ||
        speed is! int ||
        !const {40, 43}.contains(speed) ||
        json['source'] != 'mock' ||
        json['is_mock'] != true) {
      return null;
    }
    return SpeedDemo(
      valueKmh: speed,
      source: 'mock',
      isMock: true,
    );
  }
}

class CurrentWeather {
  const CurrentWeather({
    required this.condition,
    required this.temperatureC,
    required this.precipitationMm,
    required this.observedAt,
  });

  final String condition;
  final double temperatureC;
  final double precipitationMm;
  final DateTime observedAt;

  static CurrentWeather? tryParse(
    Object? value, {
    required DateTime reportCreatedAt,
  }) {
    final context = _mapOrNull(value);
    final gps = _mapOrNull(context?['gps']);
    final weather = _mapOrNull(context?['weather']);
    final lat = gps?['lat'];
    final lon = gps?['lon'];
    final condition = weather?['condition'];
    final temperature = weather?['temperature_c'];
    final precipitation = weather?['precipitation_mm'];
    final observedAtRaw = weather?['observed_at'];
    final observedAt = observedAtRaw is String && observedAtRaw.endsWith('Z')
        ? DateTime.tryParse(observedAtRaw)?.toUtc()
        : null;
    if (context == null ||
        context['kind'] != 'current_weather' ||
        context['provider'] != 'real' ||
        context['source'] != 'open_meteo' ||
        lat is! num ||
        !lat.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon is! num ||
        !lon.isFinite ||
        lon < -180 ||
        lon > 180 ||
        condition is! String ||
        condition.trim().isEmpty ||
        condition.length > 64 ||
        !RegExp(r'[가-힣]').hasMatch(condition) ||
        temperature is! num ||
        !temperature.isFinite ||
        temperature < -100 ||
        temperature > 100 ||
        precipitation is! num ||
        !precipitation.isFinite ||
        precipitation < 0 ||
        precipitation > 10000 ||
        observedAt == null) {
      return null;
    }
    final reportAge = reportCreatedAt.difference(observedAt);
    final currentAge = DateTime.now().toUtc().difference(observedAt);
    if (reportAge < const Duration(minutes: -15) ||
        reportAge > const Duration(hours: 2) ||
        currentAge < const Duration(minutes: -15) ||
        currentAge > const Duration(hours: 2)) {
      return null;
    }
    return CurrentWeather(
      condition: condition.trim(),
      temperatureC: temperature.toDouble(),
      precipitationMm: precipitation.toDouble(),
      observedAt: observedAt,
    );
  }
}

class ModelAnalysisReport {
  const ModelAnalysisReport({
    required this.status,
    required this.rateB,
    required this.rateA,
    required this.text,
    required this.lawAvailable,
    required this.reason,
    required this.caseId,
    required this.createdAt,
    required this.analyzedPlace,
    required this.syntheticContext,
    required this.road,
    required this.speedDemo,
    required this.analysis,
    required this.report,
  });

  final ModelReportStatus status;
  final int? rateB;
  final int? rateA;
  final String text;
  final bool lawAvailable;
  final String? reason;
  final String caseId;
  final DateTime createdAt;
  final int? analyzedPlace;
  final SyntheticDemoContext? syntheticContext;
  final CaseRoadSelection road;
  final SpeedDemo? speedDemo;
  final Map<String, dynamic> analysis;
  final Map<String, dynamic> report;

  bool get hasRates => rateB != null && rateA != null;

  CurrentWeather? get currentWeather => CurrentWeather.tryParse(
        analysis['context'],
        reportCreatedAt: createdAt,
      );

  bool get gpsIsAssumed {
    final provenance = _mapOrNull(analysis['provenance']);
    final modelInput = _mapOrNull(analysis['model_input']);
    return provenance?['gps_is_assumed'] == true ||
        modelInput?['gps_is_assumed'] == true;
  }

  factory ModelAnalysisReport.fromReport(
    Map<String, dynamic> report, {
    String? expectedCaseId,
  }) {
    final caseId = report['case_id'];
    final createdAtRaw = report['created_at'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)?.toUtc()
        : null;
    final analysis = _mapOrNull(report['analysis']);
    final providers = _mapOrNull(analysis?['providers']);
    final model = _mapOrNull(analysis?['model']);
    final prediction = _mapOrNull(model?['prediction']);
    final statusValue = analysis?['status'];
    final validProviders = providers != null &&
        const ['model', 'law', 'context', 'llm'].every(
          (name) => _providerStates.contains(providers[name]),
        );
    if (caseId is! String ||
        !_backendCaseIdPattern.hasMatch(caseId) ||
        expectedCaseId != null && caseId != expectedCaseId ||
        createdAt == null ||
        analysis == null ||
        providers == null ||
        model == null ||
        !_reportStatuses.contains(statusValue) ||
        statusValue == 'complete' && prediction == null ||
        !validProviders) {
      throw const ModelAnalysisException('분석 보고서 응답 형식이 올바르지 않습니다.');
    }
    final status = switch (statusValue) {
      'complete' => ModelReportStatus.complete,
      'unavailable' => ModelReportStatus.unavailable,
      _ => ModelReportStatus.incomplete,
    };
    final rateB = prediction?['rateB'];
    final rateA = prediction?['rateA'];
    final validRates = status == ModelReportStatus.complete &&
        providers['model'] == 'real' &&
        prediction?['ego_party'] == 'B' &&
        rateB is int &&
        rateA is int &&
        rateB >= 0 &&
        rateB <= 100 &&
        rateA >= 0 &&
        rateA <= 100 &&
        rateB + rateA == 100;
    final modelInput = _mapOrNull(analysis['model_input']);
    final inputPlace = modelInput?['place'];
    final predictionPlace = prediction?['place_used'];
    final analyzedPlace = inputPlace is int &&
            inputPlace >= 0 &&
            inputPlace <= 7
        ? inputPlace
        : predictionPlace is int && predictionPlace >= 0 && predictionPlace <= 7
            ? predictionPlace
            : null;

    return ModelAnalysisReport(
      status: status,
      rateB: validRates ? rateB : null,
      rateA: validRates ? rateA : null,
      text: report['text'] is String ? report['text'] as String : '',
      lawAvailable: providers['law'] == 'real',
      reason: model['reason'] is String ? model['reason'] as String : null,
      caseId: caseId,
      createdAt: createdAt,
      analyzedPlace: analyzedPlace,
      syntheticContext: SyntheticDemoContext.tryParse(analysis['context']),
      road: CaseRoadSelection.fromRoad({
        ...?_mapOrNull(analysis['road']),
        'model_input': analysis['model_input'],
      }),
      speedDemo: SpeedDemo.tryParse(analysis['speed_demo']),
      analysis: analysis,
      report: report,
    );
  }
}

class ModelAnalysisException implements Exception {
  const ModelAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AnalysisJobTimeoutException extends ModelAnalysisException {
  const AnalysisJobTimeoutException(this.jobId)
      : super('모델 분석 대기 시간이 초과되었습니다.');

  final String jobId;
}

class MissingCaseMappingException extends ModelAnalysisException {
  const MissingCaseMappingException(super.message);
}

class LatestRequestTracker {
  int _latest = 0;

  int begin() => ++_latest;

  bool isLatest(int request) => request == _latest;
}

class ModelAnalysisService {
  ModelAnalysisService({
    required Dio dio,
    required AccessTokenProvider accessToken,
    this.pollInterval = const Duration(seconds: 1),
    this.maxPollAttempts = 120,
    this.maxPollDuration = const Duration(minutes: 2),
  })  : _dio = dio,
        _accessToken = accessToken;

  final Dio _dio;
  final AccessTokenProvider _accessToken;
  final Duration pollInterval;
  final int maxPollAttempts;
  final Duration maxPollDuration;

  static bool isBackendCaseId(String value) =>
      _backendCaseIdPattern.hasMatch(value);

  Future<String> resolveCaseId({
    required String accidentId,
    required String? registeredDeviceId,
    required String? selectedHardwareEventId,
  }) async {
    if (isBackendCaseId(accidentId)) return accidentId;
    if (registeredDeviceId == null || registeredDeviceId.isEmpty) {
      throw const MissingCaseMappingException(
        '등록된 블랙박스가 없습니다. 기기를 등록한 뒤 다시 시도해 주세요.',
      );
    }
    if (selectedHardwareEventId == null || selectedHardwareEventId.isEmpty) {
      throw const MissingCaseMappingException(
        '선택된 블랙박스 사고 영상이 없습니다. 사고 영상을 선택한 뒤 다시 시도해 주세요.',
      );
    }

    final response = await _authorizedGet(
      '/api/v1/cases/by-event',
      queryParameters: {
        'device_id': registeredDeviceId,
        'event_id': selectedHardwareEventId,
      },
    );
    final caseData = _map(_data(response)['case']);
    final caseId = caseData['id'];
    if (caseId is! String || !_backendCaseIdPattern.hasMatch(caseId)) {
      throw const MissingCaseMappingException(
        '선택한 사고 영상과 연결된 분석 케이스를 찾지 못했습니다.',
      );
    }
    return caseId;
  }

  Future<CaseRoadSelection> loadRoad(String caseId) async {
    final response = await _authorizedGet('/api/v1/cases/$caseId/road');
    final road = _map(_data(response)['road']);
    return CaseRoadSelection.fromRoad(road);
  }

  Future<ModelAnalysisReport> requestAnalysis({
    required String caseId,
    int? place,
    String? otherAction,
    Map<String, bool>? facts,
    List<String>? keywords,
    VehicleMovements? movements,
  }) async {
    final body = <String, dynamic>{};
    if (place != null) {
      body['road'] = {
        'place': place,
        'other_action': place == 1 || place == 6 ? otherAction : null,
      };
    }
    if (facts != null) body['facts'] = facts;
    if (keywords != null) body['keywords'] = keywords;
    final movementJson = movements?.toJson();
    if (movementJson != null) body['movements'] = movementJson;

    final response = await _authorizedPost(
      '/api/v1/cases/$caseId/analysis',
      data: body,
    );
    final job = _map(_data(response)['job']);
    final jobId = job['id'];
    if (jobId is! String || jobId.isEmpty) {
      throw const ModelAnalysisException('분석 작업 ID를 받지 못했습니다.');
    }
    return _pollJob(caseId, jobId);
  }

  Future<ModelAnalysisReport> loadReport(
    String caseId,
    String reportId,
  ) async {
    String? cursor;
    do {
      final response = await _authorizedGet(
        '/api/v1/cases/$caseId/reports',
        queryParameters: {
          'limit': 100,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final data = _data(response);
      final reports = data['reports'];
      if (reports is! List) {
        throw const ModelAnalysisException('분석 보고서 목록 형식이 올바르지 않습니다.');
      }
      for (final item in reports) {
        final report = _map(item);
        if (report['id'] == reportId) {
          return ModelAnalysisReport.fromReport(
            report,
            expectedCaseId: caseId,
          );
        }
      }
      final next = data['next_cursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
    } while (cursor != null);
    throw const ModelAnalysisException('요청한 분석 보고서를 찾지 못했습니다.');
  }

  Future<ModelAnalysisReport> loadJob(
    String caseId,
    String jobId, {
    String? expectedReportId,
  }) =>
      _pollJob(
        caseId,
        jobId,
        expectedReportId: expectedReportId,
      );

  Future<ModelAnalysisReport> _pollJob(
    String caseId,
    String jobId, {
    String? expectedReportId,
  }) async {
    final stopwatch = Stopwatch()..start();
    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      if (stopwatch.elapsed >= maxPollDuration) {
        throw AnalysisJobTimeoutException(jobId);
      }
      if (attempt > 0 && pollInterval > Duration.zero) {
        await Future<void>.delayed(pollInterval);
      }
      final response =
          await _authorizedGet('/api/v1/cases/$caseId/jobs/$jobId');
      final data = _data(response);
      final job = _map(data['job']);
      if (job['id'] != jobId) {
        throw const ModelAnalysisException('요청한 분석 작업과 응답이 일치하지 않습니다.');
      }
      if (job['case_id'] != caseId) {
        throw const ModelAnalysisException('분석 작업이 요청한 사고 케이스와 일치하지 않습니다.');
      }
      if (job['kind'] != 'analysis') {
        throw const ModelAnalysisException('요청한 작업이 분석 작업이 아닙니다.');
      }
      final status = job['status'];
      if (status == 'done') {
        final report = _mapOrNull(data['report']);
        if (report == null) {
          throw const ModelAnalysisException('분석은 완료됐지만 결과 보고서가 없습니다.');
        }
        if (expectedReportId != null && report['id'] != expectedReportId) {
          throw const ModelAnalysisException('요청한 분석 작업과 결과 보고서가 일치하지 않습니다.');
        }
        return ModelAnalysisReport.fromReport(
          report,
          expectedCaseId: caseId,
        );
      }
      if (status == 'failed' || status == 'dead') {
        final code = job['error_code'];
        throw ModelAnalysisException(
          code == 'inputs_changed'
              ? '분석 중 입력이 변경되었습니다. 다시 분석해 주세요.'
              : '모델 분석 작업이 완료되지 못했습니다.',
        );
      }
      if (status is! String || status.isEmpty) {
        throw const ModelAnalysisException('분석 작업 상태를 확인할 수 없습니다.');
      }
      if (stopwatch.elapsed >= maxPollDuration) {
        throw AnalysisJobTimeoutException(jobId);
      }
    }
    throw AnalysisJobTimeoutException(jobId);
  }

  Future<Response<dynamic>> _authorizedGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final token = await _requiredToken();
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (error) {
      throw ModelAnalysisException(_apiMessage(error));
    }
  }

  Future<Response<dynamic>> _authorizedPost(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final token = await _requiredToken();
    try {
      return await _dio.post(
        path,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (error) {
      throw ModelAnalysisException(_apiMessage(error));
    }
  }

  Future<String> _requiredToken() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ModelAnalysisException('로그인이 필요합니다. 다시 로그인해 주세요.');
    }
    return token;
  }

  static String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final apiError = data['error'];
      if (apiError is Map && apiError['message'] is String) {
        return apiError['message'] as String;
      }
    }
    return '분석 서버에 연결하지 못했습니다.';
  }

  static Map<String, dynamic> _data(Response<dynamic> response) {
    final envelope = _map(response.data);
    final data = _mapOrNull(envelope['data']);
    if (data == null) {
      throw const ModelAnalysisException('분석 서버 응답 형식이 올바르지 않습니다.');
    }
    return data;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
