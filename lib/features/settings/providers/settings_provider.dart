import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_settings.dart';
import '../../../models/user_progress.dart';
import '../../../services/storage_service.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage) : super(const AppSettings()) {
    Future.microtask(load);
  }

  final StorageService _storage;

  Future<void> load() async {
    state = await _storage.readSettings();
  }

  Future<void> save(AppSettings settings) async {
    state = settings;
    await _storage.saveSettings(settings);
  }

  Future<void> update(AppSettings Function(AppSettings current) transform) async {
    await save(transform(state));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(storageServiceProvider));
});

class ProgressNotifier extends StateNotifier<UserProgress> {
  ProgressNotifier(this._storage) : super(const UserProgress()) {
    Future.microtask(load);
  }

  final StorageService _storage;

  Future<void> load() async {
    state = await _storage.readProgress();
  }

  Future<void> addMessageXp({int corrections = 0}) async {
    final next = state.copyWith(
      xp: state.xp + 10 + (corrections * 5),
      errorsCorrected: state.errorsCorrected + corrections,
    );
    state = next;
    await _storage.saveProgress(next);
  }

  Future<void> completeConversation() async {
    final next = state.copyWith(
      xp: state.xp + 50,
      totalConversations: state.totalConversations + 1,
      minutesPracticed: state.minutesPracticed + 5,
      streak: state.streak == 0 ? 1 : state.streak,
    );
    state = next;
    await _storage.saveProgress(next);
  }
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, UserProgress>((ref) {
  return ProgressNotifier(ref.watch(storageServiceProvider));
});
