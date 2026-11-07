import 'package:blackbox_driver_care/main.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(const {});
  });

  testWidgets('BlackboxApp boots the real app shell at 320px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: BlackboxApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'DriveGuard AI');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(find.text('DRIVEGUARD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
