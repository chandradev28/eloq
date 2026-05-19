import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/api_usage.dart';
import '../../../models/app_settings.dart';
import '../../../models/conversation_session.dart';
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
    final next = settings.copyWith(isLoaded: true);
    state = next;
    await _storage.saveSettings(next);
  }

  Future<void> update(
      AppSettings Function(AppSettings current) transform) async {
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
    state = (await _storage.readProgress()).normalizedForToday();
  }

  Future<void> addMessageXp({int corrections = 0}) async {
    final current = state.normalizedForToday();
    final next = current.copyWith(
      xp: current.xp + 10 + (corrections * 5),
      errorsCorrected: current.errorsCorrected + corrections,
    );
    state = next;
    await _storage.saveProgress(next);
  }

  Future<void> completeConversation({required int minutesPracticed}) async {
    final current = state.normalizedForToday();
    final next = current.copyWith(
      totalConversations: current.totalConversations + 1,
      minutesPracticed: current.minutesPracticed + minutesPracticed,
      todayMinutesPracticed: current.todayMinutesPracticed + minutesPracticed,
      todayDateKey: UserProgress.todayKey(),
      streak: current.streak == 0 ? 1 : current.streak,
    );
    state = next;
    await _storage.saveProgress(next);
  }
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, UserProgress>((ref) {
  return ProgressNotifier(ref.watch(storageServiceProvider));
});

class UsageNotifier extends StateNotifier<ApiUsage> {
  UsageNotifier(this._storage) : super(ApiUsage(dateKey: ApiUsage.todayKey())) {
    Future.microtask(load);
  }

  final StorageService _storage;

  Future<void> load() async {
    state = (await _storage.readUsage()).normalizedForToday();
  }

  Future<void> trackChat({
    required String provider,
    required String model,
    required int totalTokens,
    int promptTokens = 0,
    int completionTokens = 0,
    bool isEstimated = false,
  }) async {
    state = state.normalizedForToday().increment(
          '$provider:$model',
          requests: 1,
          promptTokens: isEstimated ? 0 : promptTokens,
          completionTokens: isEstimated ? 0 : completionTokens,
          totalTokens: isEstimated ? 0 : totalTokens,
          estimatedTokens: isEstimated ? totalTokens : 0,
        );
    await _storage.saveUsage(state);
  }

  Future<void> trackAudio({
    required String provider,
    required String model,
    required int seconds,
  }) async {
    state = state.normalizedForToday().increment(
          '$provider:$model',
          requests: 1,
          audioSeconds: seconds,
        );
    await _storage.saveUsage(state);
  }
}

final usageProvider = StateNotifierProvider<UsageNotifier, ApiUsage>((ref) {
  return UsageNotifier(ref.watch(storageServiceProvider));
});

class HistoryNotifier extends StateNotifier<List<ConversationSession>> {
  HistoryNotifier(this._storage) : super(const []) {
    Future.microtask(load);
  }

  final StorageService _storage;

  Future<void> load() async {
    state = (await _storage.readSessions())
        .where((session) => session.provider.toLowerCase() != 'handsfree')
        .toList();
  }

  Future<void> upsert(ConversationSession session) async {
    if (session.provider.toLowerCase() == 'handsfree') {
      return;
    }
    await _storage.saveSession(session);
    final remaining = state.where((item) => item.id != session.id).toList();
    state = [session, ...remaining]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> delete(String sessionId) async {
    await _storage.deleteSession(sessionId);
    state = state.where((item) => item.id != sessionId).toList();
  }

  Future<void> clear() async {
    await _storage.clearHistory();
    state = const [];
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<ConversationSession>>((ref) {
  return HistoryNotifier(ref.watch(storageServiceProvider));
});
