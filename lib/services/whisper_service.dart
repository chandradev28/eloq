import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WhisperService {
  WhisperService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
            ));

  final Dio _dio;

  Future<String> transcribe({
    required String apiKey,
    required String filePath,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Groq API key is required for Whisper transcription.');
    }

    final form = FormData.fromMap({
      'model': 'whisper-large-v3-turbo',
      'language': 'en',
      'response_format': 'json',
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio
        .post<Map<String, dynamic>>(
          'https://api.groq.com/openai/v1/audio/transcriptions',
          options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
          data: form,
        )
        .timeout(const Duration(seconds: 15));

    return response.data?['text']?.toString().trim() ?? '';
  }
}

final whisperServiceProvider =
    Provider<WhisperService>((ref) => WhisperService());
