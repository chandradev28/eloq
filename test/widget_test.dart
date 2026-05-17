import 'dart:io';

import 'package:eloq/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final directory = await Directory.systemTemp.createTemp('eloq_test');
    Hive.init(directory.path);
  });

  testWidgets('Eloq starts at onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EloqApp()));
    await tester.pumpAndSettle();

    expect(find.text('Set up Eloq'), findsOneWidget);
    expect(find.text('Groq API key'), findsOneWidget);
  });
}
