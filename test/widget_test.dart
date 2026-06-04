import 'dart:io';

import 'package:eloq/app.dart';
import 'package:eloq/features/settings/providers/settings_provider.dart';
import 'package:eloq/models/app_settings.dart';
import 'package:eloq/services/storage_service.dart';
import 'package:flutter/material.dart';
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

  testWidgets('Settings edits stay on settings and save keys', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = _TestSettingsNotifier(
      const AppSettings(
        hasCompletedOnboarding: true,
        isLoaded: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
        ],
        child: const EloqApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('API connections'));
    await tester.pumpAndSettle();

    for (var i = 0;
        i < 4 && find.text('Groq API key (required)').evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
    }

    final groqField = find.ancestor(
      of: find.text('Groq API key (required)'),
      matching: find.byType(TextField),
    );
    await tester.enterText(groqField, 'gsk_test_key');
    await tester.pump();

    expect(find.text('Learn English\nwith AI.'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Save settings'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Save settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings saved'), findsOneWidget);
    expect(notifier.state.groqApiKey, 'gsk_test_key');
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(AppSettings initial) : super(StorageService()) {
    state = initial;
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> save(AppSettings settings) async {
    state = settings.copyWith(isLoaded: true);
  }
}
