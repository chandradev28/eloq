import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../models/user_progress.dart';

class StorageService {
  StorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _settingsBoxName = 'eloq_settings';
  static const _progressBoxName = 'eloq_progress';
  static const _settingsKey = 'settings';
  static const _progressKey = 'progress';

  final FlutterSecureStorage _secureStorage;

  Future<AppSettings> readSettings() async {
    try {
      final box = await Hive.openBox(_settingsBoxName);
      final stored = box.get(_settingsKey);
      final base = stored is Map ? AppSettings.fromJson(stored) : const AppSettings();

      return base.copyWith(
        groqApiKey: await _secureStorage.read(key: 'groqApiKey') ?? '',
        cerebrasApiKey: await _secureStorage.read(key: 'cerebrasApiKey') ?? '',
        sambanovaApiKey: await _secureStorage.read(key: 'sambanovaApiKey') ?? '',
        geminiApiKey: await _secureStorage.read(key: 'geminiApiKey') ?? '',
        openRouterApiKey: await _secureStorage.read(key: 'openRouterApiKey') ?? '',
        xaiApiKey: await _secureStorage.read(key: 'xaiApiKey') ?? '',
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_settingsKey, settings.toJson());
    await _writeSecret('groqApiKey', settings.groqApiKey);
    await _writeSecret('cerebrasApiKey', settings.cerebrasApiKey);
    await _writeSecret('sambanovaApiKey', settings.sambanovaApiKey);
    await _writeSecret('geminiApiKey', settings.geminiApiKey);
    await _writeSecret('openRouterApiKey', settings.openRouterApiKey);
    await _writeSecret('xaiApiKey', settings.xaiApiKey);
  }

  Future<UserProgress> readProgress() async {
    try {
      final box = await Hive.openBox(_progressBoxName);
      final stored = box.get(_progressKey);
      return stored is Map ? UserProgress.fromJson(stored) : const UserProgress();
    } catch (_) {
      return const UserProgress();
    }
  }

  Future<void> saveProgress(UserProgress progress) async {
    final box = await Hive.openBox(_progressBoxName);
    await box.put(_progressKey, progress.toJson());
  }

  Future<void> clearHistory() async {
    final box = await Hive.openBox('eloq_history');
    await box.clear();
  }

  Future<void> _writeSecret(String key, String value) async {
    if (value.trim().isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value.trim());
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
