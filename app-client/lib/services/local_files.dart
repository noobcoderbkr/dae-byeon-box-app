import 'dart:convert';
import 'dart:io' if (dart.library.html) '../utils/io_web_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

final RegExp _caseIdPattern = RegExp(r'^case_[0-9a-f]{32}$');
final RegExp _blackboxFilePattern =
    RegExp(r'^blackbox_case_[0-9a-f]{32}\.mp4(?:\.part_[0-9]+_[0-9]+)?$');
final RegExp _legacyBlackboxFilePattern =
    RegExp(r'^blackbox_[A-Za-z0-9_]+\.mp4$');
final RegExp _audioFilePattern = RegExp(
  r'^accident_[A-Za-z0-9_-]+_[0-9]+\.m4a(?:\.sha256\.txt)?$',
);
final RegExp _photoFilePattern =
    RegExp(r'^evidence_case_[0-9a-f]{32}_[0-9]+\.(?:jpg|png)$');

class LocalAppFiles {
  const LocalAppFiles._();

  static int _accountCleanupGeneration = 0;
  static int get accountCleanupGeneration => _accountCleanupGeneration;

  static Future<File> cachePhoto(
    Directory directory, {
    required String caseId,
    required String sourcePath,
    required String mime,
  }) async {
    _requireCaseId(caseId);
    final extension = switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      _ => throw ArgumentError.value(mime, 'mime', 'is invalid'),
    };
    final generation = _accountCleanupGeneration;
    final path = '${directory.path}/evidence_${caseId}_'
        '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final cached = await File(sourcePath).copy(path);
    if (generation != _accountCleanupGeneration) {
      await _delete(cached);
      throw const FileSystemException('Account changed while caching photo');
    }
    return cached;
  }

  static String ownerScope(String identity) {
    final normalized = identity.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(identity, 'identity', 'must not be empty');
    }
    return sha256.convert(utf8.encode(normalized)).toString().substring(0, 16);
  }

  static String scopedPdfName({
    required String ownerScope,
    required String caseId,
    required String suffix,
  }) {
    _requireOwnerScope(ownerScope);
    _requireCaseId(caseId);
    final safeSuffix = suffix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (safeSuffix.isEmpty) {
      throw ArgumentError.value(
          suffix, 'suffix', 'must contain a safe character');
    }
    return 'DriveGuard_${ownerScope}_${caseId}_$safeSuffix.pdf';
  }

  static Future<List<File>> listOwnedPdfs(
    Directory directory,
    String ownerScope,
  ) async {
    _requireOwnerScope(ownerScope);
    if (!await directory.exists()) return const [];
    final prefix = 'DriveGuard_${ownerScope}_case_';
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      if (name.startsWith(prefix) && name.toLowerCase().endsWith('.pdf')) {
        files.add(entity);
      }
    }
    return files;
  }

  static Future<List<File>> cleanupCase(
    Directory directory,
    String caseId,
  ) async {
    _requireCaseId(caseId);
    if (!await directory.exists()) return const [];
    final audioPrefix = 'accident_${caseId}_';
    final deleted = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      final belongsToCase = _blackboxFilePattern.hasMatch(name) &&
              (name == 'blackbox_$caseId.mp4' ||
                  name.startsWith('blackbox_$caseId.mp4.part_')) ||
          _audioFilePattern.hasMatch(name) && name.startsWith(audioPrefix) ||
          _photoFilePattern.hasMatch(name) &&
              name.startsWith('evidence_${caseId}_');
      if (belongsToCase && await _delete(entity)) deleted.add(entity);
    }
    return deleted;
  }

  static Future<List<File>> cleanupAccount(Directory directory) async {
    ++_accountCleanupGeneration;
    if (!await directory.exists()) return const [];
    final deleted = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      final appOwned = _blackboxFilePattern.hasMatch(name) ||
          _legacyBlackboxFilePattern.hasMatch(name) ||
          _audioFilePattern.hasMatch(name) ||
          _photoFilePattern.hasMatch(name) ||
          name.startsWith('DriveGuard') && name.toLowerCase().endsWith('.pdf');
      if (appOwned && await _delete(entity)) deleted.add(entity);
    }
    return deleted;
  }

  static Future<bool> _delete(File file) async {
    try {
      await file.delete();
      return true;
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return false;
      rethrow;
    }
  }

  static void _requireOwnerScope(String value) {
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'ownerScope', 'is invalid');
    }
  }

  static void _requireCaseId(String value) {
    if (!_caseIdPattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'caseId', 'is invalid');
    }
  }
}

Future<List<File>> cleanupAllAppOwnedLocalFiles() async {
  if (kIsWeb) return const []; // 웹: 로컬 파일 미사용
  ++LocalAppFiles._accountCleanupGeneration;
  final dynamic directory = await getApplicationDocumentsDirectory();
  return LocalAppFiles.cleanupAccount(directory);
}

Future<File> cacheLocalCasePhoto({
  required String caseId,
  required String sourcePath,
  required String mime,
}) async {
  final generation = LocalAppFiles.accountCleanupGeneration;
  final dynamic directory = await getApplicationDocumentsDirectory();
  if (generation != LocalAppFiles.accountCleanupGeneration) {
    throw const FileSystemException(
        'Account changed while locating photo cache');
  }
  return LocalAppFiles.cachePhoto(
    directory,
    caseId: caseId,
    sourcePath: sourcePath,
    mime: mime,
  );
}

Future<List<File>> cleanupLocalCaseFiles(String caseId) async {
  if (kIsWeb) return const []; // 웹: 로컬 파일 미사용
  final dynamic directory = await getApplicationDocumentsDirectory();
  return LocalAppFiles.cleanupCase(directory, caseId);
}

String _basename(String path) => path.split(Platform.pathSeparator).last;
