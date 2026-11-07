import 'dart:async';

import 'package:blackbox_driver_care/services/notification_service.dart';
import 'package:blackbox_driver_care/services/push_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notifications =
      MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
  });

  test('accident notification asks whether the driver had an accident',
      () async {
    await NotificationService.showImpactAlert(
      caseId: caseA,
      gForce: 3.1,
    );

    final show = calls.singleWhere((call) => call.method == 'show');
    final arguments = Map<String, dynamic>.from(show.arguments as Map);
    expect(arguments['title'], '사고가 나셨습니까?');
    expect(arguments['body'], isNot(contains('자동으로 신고')));
    expect(
      NotificationService.accidentCaseIdFromPayload(arguments['payload']),
      caseA,
    );
  });

  test('accident notification leaves unknown G-force out of its copy',
      () async {
    await NotificationService.showImpactAlert(caseId: caseA);

    final show = calls.singleWhere((call) => call.method == 'show');
    final arguments = Map<String, dynamic>.from(show.arguments as Map);
    expect(arguments['body'], isNot(contains('2.5')));
    expect(arguments['body'], isNot(contains('G-Force')));
  });

  test('push dispatcher separates receipt, tap, and analysis routing', () {
    final received = <String>[];
    final opened = <String>[];
    final analysis = <String>[];
    final dispatcher = PushEventDispatcher(
      onAccidentReceived: (push) => received.add(push.caseId!),
      onAccidentOpened: (push) => opened.add(push.caseId!),
      onAnalysis: (event) => analysis.add(event.jobId!),
    );

    dispatcher.dispatch({
      'type': 'accident',
      'case_id': caseA,
    });
    dispatcher.dispatch({
      'type': 'accident',
      'case_id': caseA,
    }, opened: true);
    dispatcher.dispatch({
      'type': 'analysis_ready',
      'case_id': caseA,
      'job_id': 'job_exact',
      'report_id': 'report_exact',
    }, opened: true);

    expect(received, [caseA]);
    expect(opened, [caseA]);
    expect(analysis, ['job_exact']);
  });

  test('a later explicit tap reopens the same owned accident', () async {
    final validated = <String>[];
    final opened = <String>[];
    final router = AccidentPushRouter(
      validateOwnedCase: (caseId) async {
        validated.add(caseId);
        return true;
      },
      authGeneration: () => 4,
      canCollect: () => true,
      onOpen: (push) => opened.add(push.caseId!),
    );
    const push = AccidentPush(caseId: caseA);

    expect(await router.handle(push), isTrue);
    expect(await router.handle(push), isTrue);
    expect(validated, [caseA, caseA]);
    expect(opened, [caseA, caseA]);
  });

  test('accident router rejects malformed and non-owned cases', () async {
    var validations = 0;
    final router = AccidentPushRouter(
      validateOwnedCase: (caseId) async {
        validations++;
        return false;
      },
      authGeneration: () => 1,
      canCollect: () => true,
      onOpen: (_) => fail('rejected pushes must not navigate'),
    );

    expect(
      await router.handle(const AccidentPush(caseId: 'case_demo')),
      isFalse,
    );
    expect(await router.handle(const AccidentPush(caseId: caseA)), isFalse);
    expect(validations, 1);
  });

  test('accident router fences account changes and stale completions',
      () async {
    var generation = 8;
    final validations = <String, Completer<bool>>{};
    final opened = <String>[];
    final router = AccidentPushRouter(
      validateOwnedCase: (caseId) {
        final validation = Completer<bool>();
        validations[caseId] = validation;
        return validation.future;
      },
      authGeneration: () => generation,
      canCollect: () => true,
      onOpen: (push) => opened.add(push.caseId!),
    );

    final stale = router.handle(const AccidentPush(caseId: caseA));
    await Future<void>.delayed(Duration.zero);
    final latest = router.handle(const AccidentPush(caseId: caseB));
    await Future<void>.delayed(Duration.zero);
    validations[caseB]!.complete(true);
    expect(await latest, isTrue);
    validations[caseA]!.complete(true);
    expect(await stale, isFalse);

    final oldAccount = router.handle(const AccidentPush(caseId: caseC));
    await Future<void>.delayed(Duration.zero);
    generation++;
    validations[caseC]!.complete(true);
    expect(await oldAccount, isFalse);
    expect(opened, [caseB]);
  });

  test('accident router requires consent before and after validation',
      () async {
    var canCollect = false;
    var validations = 0;
    final delayed = Completer<bool>();
    final router = AccidentPushRouter(
      validateOwnedCase: (_) {
        validations++;
        return delayed.future;
      },
      authGeneration: () => 2,
      canCollect: () => canCollect,
      onOpen: (_) => fail('revoked consent must not navigate'),
    );

    expect(await router.handle(const AccidentPush(caseId: caseA)), isFalse);
    expect(validations, 0);

    canCollect = true;
    final pending = router.handle(const AccidentPush(caseId: caseA));
    await Future<void>.delayed(Duration.zero);
    canCollect = false;
    delayed.complete(true);
    expect(await pending, isFalse);
  });
}

const caseA = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const caseB = 'case_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const caseC = 'case_cccccccccccccccccccccccccccccccc';
