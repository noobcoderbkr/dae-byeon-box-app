import 'dart:io';

import 'package:blackbox_driver_care/services/audio_recording_service.dart';
import 'package:blackbox_driver_care/services/local_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('blackbox-local-files');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('account cleanup removes only allowlisted app-owned files', () async {
    final owned = [
      'blackbox_$caseA.mp4',
      'blackbox_source_event_safeid.mp4',
      'blackbox_demo.mp4',
      'blackbox_$caseA.mp4.part_123_1',
      'accident_case_aaa_123.m4a',
      'accident_case_aaa_123.m4a.sha256.txt',
      'DriveGuard_owner_${caseA}_report.pdf',
    ];
    final unrelated = [
      'family-video.mp4',
      'accident_notes.txt',
      'tax-return.pdf',
      'blackbox_notes.txt',
      'my_blackbox_notes.mp4',
      'blackbox-trip.mp4',
    ];
    for (final name in [...owned, ...unrelated]) {
      await File('${directory.path}/$name').writeAsString(name);
    }

    final deleted = await LocalAppFiles.cleanupAccount(directory);

    expect(deleted.map((file) => file.path.split('/').last),
        unorderedEquals(owned));
    for (final name in owned) {
      expect(File('${directory.path}/$name').existsSync(), isFalse);
    }
    for (final name in unrelated) {
      expect(File('${directory.path}/$name').existsSync(), isTrue);
    }
  });

  test('case cleanup removes only files tagged for the exact case', () async {
    final files = [
      'blackbox_$caseA.mp4',
      'blackbox_$collidingCase.mp4',
      'blackbox_source_event_safeid.mp4',
      'blackbox_$caseA.mp4.part_123_1',
      'accident_${caseA}_123.m4a',
      'accident_${collidingCase}_123.m4a',
      'accident_case_aaa_legacy.m4a',
      'DriveGuard_owner_${caseA}_report.pdf',
      'DriveGuard_owner_${collidingCase}_report.pdf',
    ];
    for (final name in files) {
      await File('${directory.path}/$name').writeAsString(name);
    }

    await LocalAppFiles.cleanupCase(directory, caseA);

    expect(File('${directory.path}/blackbox_$caseA.mp4').existsSync(), isFalse);
    expect(
        File('${directory.path}/blackbox_$caseA.mp4.part_123_1').existsSync(),
        isFalse);
    expect(
        File('${directory.path}/blackbox_source_event_safeid.mp4').existsSync(),
        isTrue);
    expect(
      File('${directory.path}/accident_${caseA}_123.m4a').existsSync(),
      isFalse,
    );
    expect(
      File('${directory.path}/DriveGuard_owner_${caseA}_report.pdf')
          .existsSync(),
      isTrue,
    );
    expect(
      File('${directory.path}/blackbox_$collidingCase.mp4').existsSync(),
      isTrue,
    );
    expect(
      File('${directory.path}/accident_${collidingCase}_123.m4a').existsSync(),
      isTrue,
    );
    expect(
      File('${directory.path}/accident_case_aaa_legacy.m4a').existsSync(),
      isTrue,
    );
    expect(
      File('${directory.path}/DriveGuard_owner_${collidingCase}_report.pdf')
          .existsSync(),
      isTrue,
    );
  });

  test('audio recording names retain the complete backend case id', () {
    final name = AudioRecordingNotifier.recordingFileName(caseA, 123);

    expect(name, 'accident_${caseA}_123.m4a');
  });

  test('cached photo is case-scoped and account cleanup preserves its source',
      () async {
    final camera = await Directory.systemTemp.createTemp('task4-camera-');
    addTearDown(() => camera.delete(recursive: true));
    final source =
        await File('${camera.path}/camera.jpg').writeAsBytes([1, 2, 3, 4]);
    final cached = await LocalAppFiles.cachePhoto(
      directory,
      caseId: caseA,
      sourcePath: source.path,
      mime: 'image/jpeg',
    );
    expect(cached.path, startsWith('${directory.path}/evidence_${caseA}_'));
    expect(await cached.readAsBytes(), [1, 2, 3, 4]);
    final foreign =
        await File('${directory.path}/evidence_${collidingCase}_123.png')
            .writeAsBytes([5]);
    await LocalAppFiles.cleanupCase(directory, caseA);
    expect(cached.existsSync(), isFalse);
    expect(foreign.existsSync(), isTrue);
    expect(source.existsSync(), isTrue);
    await LocalAppFiles.cleanupAccount(directory);
    expect(foreign.existsSync(), isFalse);
    expect(source.existsSync(), isTrue);
  });

  test('account cleanup propagates file deletion failures', () async {
    final file =
        await File('${directory.path}/blackbox_$caseA.mp4').writeAsBytes([1]);
    final result = await Process.run('chmod', ['500', directory.path]);
    expect(result.exitCode, 0);
    try {
      await expectLater(LocalAppFiles.cleanupAccount(directory),
          throwsA(isA<FileSystemException>()));
      expect(file.existsSync(), isTrue);
    } finally {
      await Process.run('chmod', ['700', directory.path]);
    }
  }, skip: Platform.isWindows);

  test('report listing isolates previous users and hides unscoped legacy PDFs',
      () async {
    final ownerA = LocalAppFiles.ownerScope('first@example.com');
    final ownerB = LocalAppFiles.ownerScope('second@example.com');
    final visible = LocalAppFiles.scopedPdfName(
      ownerScope: ownerA,
      caseId: caseA,
      suffix: 'report',
    );
    final hidden = LocalAppFiles.scopedPdfName(
      ownerScope: ownerB,
      caseId: caseB,
      suffix: 'report',
    );
    for (final name in [visible, hidden, 'DriveGuard_legacy.pdf']) {
      await File('${directory.path}/$name').writeAsString(name);
    }

    final listed = await LocalAppFiles.listOwnedPdfs(directory, ownerA);

    expect(listed.map((file) => file.path.split('/').last), [visible]);
  });
}

const caseA = 'case_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const caseB = 'case_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const collidingCase = 'case_aaabbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
