# Eloq

Eloq is a Flutter app for practicing spoken English with an AI conversation partner. This repo currently contains the first minimalist MVP pass from `eloq_codex_spec.md`.

## What is built

- Dark, minimalist Flutter app shell with onboarding, home, topics, conversation, progress, vocabulary, and settings screens.
- Free-tier conversation flow with tap-to-record UI, typed testing input, Groq Whisper transcription wiring, rotating LLM provider router, corrections parsing, and device TTS.
- Local demo fallback when API keys are not configured.
- Hive-backed progress/settings storage plus secure storage for API keys.
- Android mic/network permissions.
- GitHub Actions Android APK release workflow.

## Run

```bash
flutter pub get
flutter run
```

For a browser preview:

```bash
flutter build web --web-renderer html --pwa-strategy=none
python -m http.server 5555 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:5555`.

## API keys

Add keys in Settings. Groq is the key one for the current MVP because it powers Whisper transcription and the primary chat provider. Other providers are already represented in the router for fallback capacity.
