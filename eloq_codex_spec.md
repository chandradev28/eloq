# ELOQ — Full App Specification for Codex

> **One-line summary:** A Flutter mobile app for practicing English speaking through voice conversations with AI. Uses Groq, Gemini, OpenRouter, and DeepSeek for AI responses, Groq Whisper for STT, and device-native TTS for voice output. Optional premium voice capabilities can be added through xAI.

---

## Tech Stack

| Layer | Technology | Package/Version |
|-------|-----------|-----------------|
| Framework | Flutter 3.x (Dart) | Latest stable |
| State Management | Riverpod | `flutter_riverpod` |
| HTTP Client | Dio | `dio` |
| WebSocket | For xAI Voice Agent | `web_socket_channel` |
| Speech-to-Text (Free) | Device native + Groq Whisper | `speech_to_text` + `record` + Groq REST API |
| Speech-to-Text (Premium) | xAI Grok STT | xAI REST API |
| Text-to-Speech (Free) | Device native TTS | `flutter_tts` |
| Text-to-Speech (Premium) | xAI Grok TTS (80+ voices, custom clones, speech tags) | xAI REST API |
| Voice Agent (Premium) | xAI Grok Voice Think Fast 1.0 — real-time speech-to-speech | xAI WebSocket API |
| Local Storage | Hive | `hive`, `hive_flutter` |
| Audio Recording | Record package | `record` |
| Audio Visualization | Custom Canvas | `CustomPainter` |
| Routing | GoRouter | `go_router` |
| Animations | Flutter built-in + Rive (optional) | `flutter_animate` |
| Icons | Lucide | `lucide_icons` |
| Google Fonts | Inter, Space Grotesk | `google_fonts` |
| Secure Storage | For API keys | `flutter_secure_storage` |
| UUID | Conversation IDs | `uuid` |
| Intl | Date formatting | `intl` |

---

## Architecture

```
lib/
├── main.dart                      # App entry, theme, router setup
├── app.dart                       # MaterialApp wrapper
│
├── core/
│   ├── theme/
│   │   ├── app_theme.dart         # ThemeData: dark theme, colors, typography
│   │   ├── app_colors.dart        # Color constants
│   │   └── app_text_styles.dart   # Text style definitions
│   ├── router/
│   │   └── app_router.dart        # GoRouter config with all routes
│   ├── constants/
│   │   ├── app_constants.dart     # App-wide constants
│   │   ├── topics.dart            # Conversation topic definitions
│   │   └── prompts.dart           # AI system prompts for each mode/topic
│   └── utils/
│       ├── api_client.dart        # Dio instance, interceptors, error handling
│       └── helpers.dart           # Utility functions
│
├── features/
│   ├── onboarding/
│   │   ├── screens/
│   │   │   └── onboarding_screen.dart    # Welcome → API key setup → level assessment
│   │   └── providers/
│   │       └── onboarding_provider.dart
│   │
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart          # Dashboard: streak, XP, quick start, topics
│   │   ├── widgets/
│   │   │   ├── streak_card.dart          # Daily streak display
│   │   │   ├── xp_progress_card.dart     # XP + level progress bar
│   │   │   ├── quick_start_button.dart   # Big "Start Talking" button
│   │   │   └── topic_grid.dart           # Topic selection grid
│   │   └── providers/
│   │       └── home_provider.dart
│   │
│   ├── conversation/
│   │   ├── screens/
│   │   │   └── conversation_screen.dart  # THE MAIN SCREEN — voice chat with AI
│   │   ├── widgets/
│   │   │   ├── mic_button.dart           # Pulsing mic button with hold-to-record
│   │   │   ├── audio_visualizer.dart     # Real-time waveform CustomPainter
│   │   │   ├── chat_bubble.dart          # Message bubble (user & AI)
│   │   │   ├── grammar_feedback.dart     # Inline grammar correction card
│   │   │   ├── typing_indicator.dart     # AI "thinking" animation
│   │   │   └── voice_controls.dart       # Speed slider, repeat button, stop button
│   │   ├── providers/
│   │   │   ├── conversation_provider.dart # Manages conversation state
│   │   │   └── audio_provider.dart        # Manages recording & playback state
│   │   └── models/
│   │       └── message.dart              # Message model (text, role, corrections, timestamp)
│   │
│   ├── topics/
│   │   ├── screens/
│   │   │   └── topics_screen.dart        # Full topic browser with categories
│   │   └── models/
│   │       └── topic.dart                # Topic model (name, icon, description, difficulty, prompt)
│   │
│   ├── progress/
│   │   ├── screens/
│   │   │   └── progress_screen.dart      # Stats dashboard: XP chart, streaks, words learned
│   │   ├── widgets/
│   │   │   ├── stat_card.dart            # Individual stat display
│   │   │   ├── streak_calendar.dart      # GitHub-style activity calendar
│   │   │   └── level_progress.dart       # Level progress visualization
│   │   └── providers/
│   │       └── progress_provider.dart
│   │
│   ├── vocabulary/
│   │   ├── screens/
│   │   │   └── vocabulary_screen.dart    # Saved words list with definitions
│   │   ├── widgets/
│   │   │   └── word_card.dart            # Individual vocabulary word card
│   │   └── models/
│   │       └── word.dart                 # Word model (word, definition, example, dateAdded)
│   │
│   ├── history/
│   │   ├── screens/
│   │   │   └── history_screen.dart       # Past conversations list
│   │   └── providers/
│   │       └── history_provider.dart
│   │
│   └── settings/
│       ├── screens/
│       │   └── settings_screen.dart      # API keys, voice selection, speed, level
│       └── providers/
│           └── settings_provider.dart
│
├── services/
│   ├── llm_router_service.dart    # CORE: Multi-provider LLM router with auto-fallback
│   ├── groq_service.dart          # Groq API: Llama 3.3 70B (OpenAI-compatible)
│   ├── gemini_service.dart        # Gemini API: Gemini 2.0 Flash (Google format)
│   ├── openrouter_service.dart    # OpenRouter API: Any free model (OpenAI-compatible)
│   ├── whisper_service.dart       # Groq API: Whisper transcription
│   ├── xai_service.dart           # xAI API: Voice Agent (WebSocket), TTS, STT
│   ├── stt_service.dart           # Unified STT: tries Whisper first, falls back to native
│   ├── tts_service.dart           # Unified TTS: uses xAI if premium, else flutter_tts
│   ├── voice_agent_service.dart   # xAI Voice Agent WebSocket manager (premium mode)
│   ├── audio_recorder_service.dart # Record audio from mic, return file/bytes
│   └── storage_service.dart       # Hive CRUD for all data models
│
└── models/
    ├── conversation.dart          # Conversation model (id, topic, messages[], date)
    ├── user_progress.dart         # UserProgress model (xp, level, streak, wordsLearned)
    ├── app_settings.dart          # Settings model (apiKeys map, voiceMode, voiceName, speed, difficulty)
    └── grammar_correction.dart    # GrammarCorrection model (original, corrected, explanation)
```

---

## Screens & UX Flow

### 1. Onboarding (first launch only)
```
Welcome Screen → "Learn English by Speaking"
   ↓ [Get Started]
API Key Setup → Input field for Groq API key (REQUIRED)
   → Link to console.groq.com with instructions
   → "Paste your free API key here"
   → [Validate & Continue] → hits Groq API to verify key works
   ↓
Optional: xAI API Key → Input field for xAI key (OPTIONAL)
   → "Want premium voices? Add your xAI key (free $25 trial credits)"
   → Link to console.x.ai
   → [Skip] or [Add & Continue]
   ↓
Level Selection → "What's your English level?"
   → Beginner / Intermediate / Advanced (3 big cards)
   ↓
Done → Navigate to Home
```

### 2. Home Screen (Dashboard)
```
┌─────────────────────────────┐
│  🔥 7 Day Streak    ⭐ 1,250 XP │
│  Level: Conversationalist (4/10)  │
│  ═══════════════░░░░ 65%          │
├─────────────────────────────┤
│                                   │
│    [ 🎤 START TALKING ]           │  ← Big prominent button
│    (Tap to begin free conversation)│
│                                   │
├─────────────────────────────┤
│  Choose a Topic:                  │
│  ┌──────┐ ┌──────┐ ┌──────┐     │
│  │ 🍽️   │ │ 💼   │ │ ✈️   │     │
│  │Dining│ │ Job  │ │Travel│     │
│  └──────┘ └──────┘ └──────┘     │
│  ┌──────┐ ┌──────┐ ┌──────┐     │
│  │ 🏥   │ │ 🛒   │ │ 💬   │     │
│  │Doctor│ │ Shop │ │Casual│     │
│  └──────┘ └──────┘ └──────┘     │
├─────────────────────────────┤
│  Recent Conversations:           │
│  > Coffee shop roleplay - 5m ago │
│  > Job interview prep - yesterday│
└─────────────────────────────┘
Bottom Nav: [Home] [Topics] [Progress] [Vocab] [Settings]
```

### 3. Conversation Screen (THE CORE)
```
┌─────────────────────────────┐
│ ← Back        "Restaurant"    ⚙️ │
├─────────────────────────────┤
│                                   │
│  ┌─────────────────────────┐     │
│  │ 🤖 AI:                   │     │
│  │ "Welcome! I'll be your   │     │
│  │  waiter today. What can  │     │
│  │  I get you?"             │     │
│  │         [🔊 Replay] [🐌⟷🐇]│     │
│  └─────────────────────────┘     │
│                                   │
│  ┌─────────────────────────┐     │
│  │ 👤 You:                   │     │
│  │ "I want to order a       │     │
│  │  coffee and a cake"      │     │
│  └─────────────────────────┘     │
│                                   │
│  ┌─ 💡 Grammar Tip ─────────┐    │
│  │ "I'd like to order" sounds│    │
│  │ more polite than "I want" │    │
│  │ in a restaurant setting.  │    │
│  └───────────────────────────┘    │
│                                   │
│          ╭─────────╮              │
│          │ ┌─────┐ │              │
│          │ │ 🎤  │ │  ← Audio    │
│          │ └─────┘ │   waveform  │
│          │ Hold to  │   ring     │
│          │  speak   │   animates │
│          ╰─────────╯   while     │
│                        recording │
└─────────────────────────────┘
```

**Mic Button Behavior:**
- **Tap once** → starts recording, tap again to stop & send
- While recording: waveform animation around mic button, screen tints slightly purple
- After recording stops: "Transcribing..." indicator → "AI is thinking..." indicator → AI response appears + speaks

### 4. Progress Screen
- GitHub-style streak calendar (green squares)
- XP progress bar with level name
- Stats: total conversations, total minutes practiced, words learned, errors corrected
- Weekly comparison chart

### 5. Vocabulary Screen
- List of saved words from conversations
- Each card: word, definition, example sentence, date learned
- Tap to hear pronunciation
- Search/filter

### 6. Settings Screen
- **Voice Mode Toggle**: Free Mode / Premium Mode (xAI)
- **API Keys Section** (expandable, each with masked input + test button):
  - Groq API Key — REQUIRED (used for LLM + Whisper STT)
  - Gemini API Key — recommended
  - OpenRouter API Key — optional
  - xAI API Key — optional (enables premium voice mode)
- **Provider Status**: show green/yellow/red dot per provider (connected/rate-limited/not set)
- Difficulty level selector
- **If Free Mode**: AI Voice picker from available device voices
- **If Premium Mode**: AI Voice picker from xAI's 80+ voices (American, British, etc.) + custom cloned voices
- AI Speaking speed: slider (0.5x to 2.0x)
- AI Accent preference: US / UK / AU
- **xAI Credits remaining** indicator (when premium mode is active)
- Clear conversation history
- Export progress data
- About / version

---

## AI System Prompt

The AI must receive this system prompt with every conversation request:

```
You are Eloq, a friendly and patient English language tutor having a voice conversation with a student.

STUDENT LEVEL: {beginner|intermediate|advanced}
CONVERSATION TOPIC: {topic_name}
TOPIC CONTEXT: {topic_description}

RULES:
1. Respond naturally as a conversation partner, staying in character for the topic/scenario.
2. Keep responses concise (2-4 sentences max) since this is a SPOKEN conversation — long responses feel unnatural.
3. After responding in-character, if the student made any grammar, vocabulary, or phrasing errors, add corrections in this EXACT JSON format at the end of your response:

|||CORRECTIONS|||
[{"original": "what the student said wrong", "corrected": "the correct way to say it", "explanation": "brief explanation why"}]
|||END|||

4. If no errors were found, do NOT include the corrections block.
5. Adjust your vocabulary complexity to match the student's level:
   - Beginner: Simple words, short sentences, speak slowly
   - Intermediate: Normal vocabulary, natural phrasing
   - Advanced: Rich vocabulary, idioms, complex structures
6. Occasionally introduce new vocabulary relevant to the topic and naturally explain it.
7. Be encouraging. Praise good usage. Never be condescending.
8. If the student's message is unclear or garbled (likely a transcription error), politely ask them to repeat.
9. Stay in the conversation topic/scenario. Guide the conversation forward with questions.
10. NEVER use markdown formatting — this is spoken conversation, plain text only.
```

**The app parses the `|||CORRECTIONS|||` block, strips it from the displayed/spoken text, and renders corrections as a separate Grammar Tip card below the AI message.**

---

## API Integration Details

### Multi-Provider LLM Router (CORE FEATURE)

The app uses `llm_router_service.dart` to automatically rotate between free LLM providers. All providers except Gemini use OpenAI-compatible format, so the same message payload works — just swap `base_url`, `api_key`, and `model`.

**Fallback Chain (in order):**
```
1. Groq        → fastest, try first
2. Gemini      → reliable alternative and native audio
3. OpenRouter  → available community models
4. DeepSeek    → optional text provider
```

If provider N returns 429 (rate limited) or 5xx (error), immediately try provider N+1. Track which providers are currently rate-limited and skip them for a cooldown period (default: 60 seconds).

### Provider 1: Groq (Primary)
```
Base URL: https://api.groq.com/openai/v1
Model: llama-3.3-70b-versatile
Free Limits: ~6,000 req/day, 300K tokens/day
Auth: Bearer {GROQ_API_KEY}
```

### Provider 2: Google Gemini (different API format)
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}
Headers:
  Content-Type: application/json
Body:
{
  "contents": [{"parts": [{"text": "{full_conversation_with_system_prompt}"}]}],
  "generationConfig": {"temperature": 0.7, "maxOutputTokens": 300}
}
Free Limits: 15 RPM, 1M tokens/day
```

### Provider 3: OpenRouter
```
Base URL: https://openrouter.ai/api/v1
Model: openrouter/free (auto-selects best available free model)
  OR: qwen/qwen3.6-plus-preview:free
  OR: deepseek/deepseek-v4-flash:free
Free Limits: 50-200 req/day (unfunded), 1000 req/day ($10 credit)
Auth: Bearer {OPENROUTER_API_KEY}
Extra Header: HTTP-Referer: https://eloq.app
```

### OpenAI-Compatible Payload (used by Groq, OpenRouter, and DeepSeek)
```json
POST {base_url}/chat/completions
Headers:
  Authorization: Bearer {API_KEY}
  Content-Type: application/json
Body:
{
  "model": "{model_name}",
  "messages": [
    {"role": "system", "content": "{system_prompt}"},
    {"role": "user", "content": "previous user message"},
    {"role": "assistant", "content": "previous ai response (without corrections block)"},
    {"role": "user", "content": "current user message"}
  ],
  "temperature": 0.7,
  "max_tokens": 300,
  "stream": false
}
```

### Groq Whisper (Speech-to-Text)
```
POST https://api.groq.com/openai/v1/audio/transcriptions
Headers:
  Authorization: Bearer {GROQ_API_KEY}
Content-Type: multipart/form-data
Body:
  file: {audio_file.wav}
  model: "whisper-large-v3-turbo"
  language: "en"
  response_format: "json"
```

### API Keys Required (ALL free, NO credit card)
| Provider | Signup URL | Time | Required? |
|----------|-----------|------|----------|
| Groq | console.groq.com | 30s | ✅ Required (also for Whisper STT) |
| Gemini | aistudio.google.com | 30s | 🟡 Recommended |
| OpenRouter | openrouter.ai | 30s | 🟡 Optional |
| xAI | console.x.ai | 30s | 🟡 Optional (premium voice) |

> Groq is the minimum key for standard voice transcription. Additional supported providers can extend chat capacity.

### Combined Free Limits (if user adds ALL keys)
| Resource | Daily Free Total |
|----------|------------------|
| LLM Requests | ~7,200+ requests/day |
| LLM Tokens | ~2.3M+ tokens/day |
| Speech-to-Text | ~8 hours of audio/day |
| **Effective daily practice time** | **Unlimited for any normal user** |

---

## xAI Voice Agent Integration (Premium Tier)

The app supports TWO voice modes. The user can switch between them in Settings:

### Mode 1: Free Tier (Default)
```
User speaks → mic records audio → Groq Whisper STT → text
  → Groq Llama 3.3 70B generates response → text
  → flutter_tts speaks response → user hears device TTS voice
Cost: $0 forever
```

### Mode 2: Premium Tier (xAI Grok Voice)
```
User speaks → audio streams via WebSocket to xAI Voice Agent
  → Grok Voice Think Fast 1.0 processes speech-to-speech
  → AI audio response streams back in real-time
  → User hears high-quality xAI voice (80+ options)
Cost: $0.05/min ($3/hr) — uses trial credits first ($25-$150 free on signup)
```

**Auto-fallback:** If xAI credits run out or API errors occur, the app automatically switches to Free Tier and notifies the user.

### xAI Voice Agent WebSocket API
```
Endpoint: wss://api.x.ai/v1/realtime
Auth: Bearer {XAI_API_KEY} (passed as query param or in first message)

Session Config (sent on connect):
{
  "type": "session.update",
  "session": {
    "model": "grok-voice-think-fast-1.0",
    "voice": "alloy",               // or any of 80+ voice IDs
    "instructions": "{system_prompt}",
    "input_audio_format": "pcm16",
    "output_audio_format": "pcm16",
    "turn_detection": {
      "type": "server_vad",          // server-side voice activity detection
      "threshold": 0.5,
      "silence_duration_ms": 800
    }
  }
}

Sending audio: stream raw PCM16 audio chunks as binary WebSocket frames
Receiving: audio response chunks + transcript text events
```

### xAI TTS API (Alternative to Voice Agent for more control)
```
POST https://api.x.ai/v1/audio/speech
Headers:
  Authorization: Bearer {XAI_API_KEY}
  Content-Type: application/json
Body:
{
  "model": "grok-2.5-tts",
  "input": "Hello! Welcome to the restaurant. What can I get for you today?",
  "voice": "alloy",
  "response_format": "mp3",
  "speech_tags": true          // enables [laugh], <whisper>, etc.
}
Response: audio/mp3 binary stream
```

### xAI STT API
```
POST https://api.x.ai/v1/audio/transcriptions
Headers:
  Authorization: Bearer {XAI_API_KEY}
Content-Type: multipart/form-data
Body:
  file: {audio_file.wav}
  model: "grok-2.5-stt"
  language: "en"
  response_format: "json"
```

### xAI Voice Library (80+ voices)
The app should fetch available voices on first launch (when xAI key is set):
```
GET https://api.x.ai/v1/audio/voices
Headers:
  Authorization: Bearer {XAI_API_KEY}
Response: list of voice objects with id, name, accent, gender, preview_url
```

### xAI Custom Voice Cloning
Custom voice creation is done via xAI Console (not in-app). The app can USE custom voices once created:
- User creates custom voice at console.x.ai (records 30-60 seconds, voice ready in <2 minutes)
- Custom voice appears in the voice list API response
- App lets user select it like any other voice
- Two-stage verification (phrase reading + speaker embedding match) handled by xAI Console
- Up to 30 custom voices per account
- Note: Currently US-only for custom voice creation, and primarily enterprise-gated for programmatic creation

### xAI Pricing (for reference in Settings screen)
| Service | Cost |
|---------|------|
| Voice Agent (real-time speech-to-speech) | $0.05/min |
| TTS (text-to-speech) | $15/1M characters |
| STT (speech-to-text) | $0.10/hr (batch), $0.20/hr (streaming) |
| Chat models (Grok 4.1 Fast) | $0.20/1M input, $0.50/1M output |
| Trial credits on signup | $25-$150 free (one-time) |

---

## Conversation Topics (ship with these 15)

| # | Topic | Icon | Description | Scenario Prompt |
|---|-------|------|-------------|-----------------|
| 1 | Restaurant | 🍽️ | Ordering food, talking to waiter | "You are a waiter at a restaurant. Greet the customer and take their order." |
| 2 | Job Interview | 💼 | Answering interview questions | "You are a hiring manager interviewing the student for a junior position. Ask common interview questions." |
| 3 | Airport & Travel | ✈️ | Check-in, directions, customs | "You are an airport staff member helping a traveler check in for their flight." |
| 4 | Doctor Visit | 🏥 | Describing symptoms, understanding advice | "You are a doctor. The patient has come in with a complaint. Ask about their symptoms." |
| 5 | Shopping | 🛒 | Buying clothes, asking prices, returns | "You are a shop assistant in a clothing store. Help the customer find what they need." |
| 6 | Casual Chat | 💬 | General everyday conversation | "Have a casual, friendly conversation about daily life, hobbies, and interests." |
| 7 | Hotel Check-in | 🏨 | Booking, check-in, room issues | "You are a hotel receptionist. Help the guest check in." |
| 8 | Phone Call | 📞 | Making appointments, customer service | "You are a receptionist at a dental clinic. The student is calling to book an appointment." |
| 9 | Giving Directions | 🗺️ | Asking for and giving directions | "A tourist asks you for directions to the nearest train station. Help them." |
| 10 | Small Talk | ☕ | Weather, weekend plans, compliments | "You meet the student at a coffee shop. Make small talk." |
| 11 | Storytelling | 📖 | Narrating events, past tense practice | "Ask the student to tell you about their last vacation or a memorable experience." |
| 12 | Debate & Opinions | 🎯 | Expressing and defending views | "Discuss whether social media is good or bad for society. Present your view and ask for theirs." |
| 13 | Emergency | 🚨 | Calling for help, reporting incidents | "You are a 911 operator. The student needs to report an emergency." |
| 14 | Meeting New People | 🤝 | Introductions, getting to know someone | "You just met the student at a party. Introduce yourself and get to know them." |
| 15 | Free Talk | 🎤 | No scenario, open conversation | "Have an open conversation about anything the student wants to talk about. Be a good listener." |

---

## Gamification System

```dart
// XP rewards
const XP_PER_MESSAGE_SENT = 10;
const XP_PER_CORRECTION_RECEIVED = 5;    // learning from mistakes
const XP_PER_NEW_WORD_SAVED = 15;
const XP_PER_CONVERSATION_COMPLETED = 50; // >5 exchanges in one session
const XP_PER_STREAK_DAY = 25;

// Levels (10 total)
const LEVELS = [
  { name: "Beginner", xpRequired: 0 },
  { name: "Tourist", xpRequired: 200 },
  { name: "Explorer", xpRequired: 500 },
  { name: "Conversationalist", xpRequired: 1000 },
  { name: "Communicator", xpRequired: 2000 },
  { name: "Storyteller", xpRequired: 4000 },
  { name: "Debater", xpRequired: 7000 },
  { name: "Articulate", xpRequired: 11000 },
  { name: "Eloquent", xpRequired: 16000 },
  { name: "Native Speaker", xpRequired: 25000 },
];
```

---

## Design System

**Theme: Dark mode only.**

```dart
// Colors
static const bgPrimary = Color(0xFF0A0A0F);
static const bgSecondary = Color(0xFF12121A);
static const bgCard = Color(0xFF1A1A2E);
static const accentPurple = Color(0xFF6C5CE7);
static const accentTeal = Color(0xFF00CEC9);
static const accentGreen = Color(0xFF00B894);
static const accentYellow = Color(0xFFFDCB6E);
static const accentRed = Color(0xFFE17055);
static const textPrimary = Color(0xFFF5F5F7);
static const textSecondary = Color(0xFF8B8B9E);

// Card style: rounded corners (16px), subtle border (1px white 5% opacity), slight elevation
// Mic button: 80px diameter, gradient purple→teal, glow shadow animation while recording
// Chat bubbles: user = purple bg, AI = dark card bg
// Grammar tips: yellow-tinted card with left border accent
// Bottom nav: 5 items, frosted glass background

// Fonts
// Headings: Space Grotesk (bold)
// Body: Inter (regular, medium)

// Animations
// Mic button: pulsing glow when recording
// Waveform: real-time audio amplitude visualization in a ring around mic
// Page transitions: slide + fade
// Chat bubbles: slide up + fade in
// Grammar tips: expand from top
// XP gain: floating "+10 XP" text animation
```

---

## Build & CI/CD (GitHub Actions)

Create `.github/workflows/build.yml`:
```yaml
name: Build Android APK
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: eloq-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
```

Users download APK from GitHub Releases → install on Android. Free forever.

---

## Priority Order for Implementation

1. **Phase 1 (Core MVP):** Onboarding → Home → Conversation Screen (mic, STT, AI, TTS) → Settings — FREE TIER ONLY
2. **Phase 2 (Content):** Topics screen, all 15 topic prompts, topic-specific conversations
3. **Phase 3 (Gamification):** XP system, streaks, levels, progress screen
4. **Phase 4 (Premium Voice):** xAI Voice Agent WebSocket integration, xAI TTS/STT, voice library picker, auto-fallback logic
5. **Phase 5 (Polish):** Vocabulary bank, conversation history, audio visualizer, animations
6. **Phase 6 (Ship):** GitHub Actions CI/CD, README, APK release
