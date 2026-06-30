# BetterAsk Voice

**Speak a messy thought. Get a clean, well-formed prompt.**

BetterAsk Voice is an iOS app that records your voice, transcribes it (on-device
by default), and rewrites the rambling transcript into a tidy prompt you can
paste into Claude, ChatGPT, Cursor, or any coding agent.

It's the **voice-native sibling of the [BetterAsk browser extension](https://github.com/unevil-warden/unevil/tree/main/betterask)**:
the extension fixes vague prompts you *type* on AI sites; this app fixes vague
prompts you *speak* on your phone. Same philosophy — privacy-first, no backend,
never put words in your mouth.

> **Status:** personal portfolio project / MVP. It builds and runs in Xcode and
> is structured to be App-Store-submittable, but it is not a finished, marketed
> product. See [Honest limitations](#honest-limitations).

---

## What it does

```
record  →  transcribe  →  "worth refining?" gate  →  refine with Claude  →  raw + refined shown  →  copy / share
   │                                                          │
   └─ audio discarded after transcription          no key / already clean / failure → fall back to the raw transcript
```

This is a SwiftUI port of a [voice-to-prompt pipeline spec](#origin) originally
written as a Python CLI. The mapping:

| Reference pipeline (Python CLI) | This app (SwiftUI) |
| --- | --- |
| `local-whisper` / `faster-whisper` | On-device Apple Speech (`SFSpeechRecognizer`, on-device only) |
| `openai-audio-api` | `OpenAITranscriber` (opt-in cloud) |
| Anthropic refiner | `AnthropicRefiner` (Messages REST API, no SDK) |
| `should_refine()` gate | `RefineGate.shouldRefine(_:)` |
| `VoicePromptResult` dataclass | `VoicePromptResult` struct |
| Fallback ladder | `VoicePipeline.refine(rawTranscript:)` |
| CLI `--json-out` | Share / copy + optional on-device history |

---

## Build & run

This repo intentionally **does not commit an `.xcodeproj`** — it's machine
generated and fragile in version control. The project is defined in
[`project.yml`](project.yml) and generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen          # one-time
cd betterask
xcodegen generate              # writes BetterAskVoice.xcodeproj
open BetterAskVoice.xcodeproj
```

In Xcode: pick an iOS Simulator (or your device), then **⌘R** to run, **⌘U** to
test. You'll need to set your own signing team in the target's *Signing &
Capabilities* tab to run on a physical device.

> Prefer not to use XcodeGen? You can recreate the same targets by hand, or use
> [Tuist](https://tuist.io). The source of truth for targets, Info.plist keys,
> and build settings is `project.yml`.

Requirements: **iOS 17+**, Xcode 15+.

### First run

1. Grant microphone + speech-recognition permission when prompted.
2. (Optional) Paste your **Anthropic API key** in onboarding or Settings —
   [get one here](https://console.anthropic.com/settings/keys). Without a key,
   the app still works; it just shows the raw transcript instead of a refined
   prompt.
3. Tap the mic, say something rambly, tap stop. You'll see the raw transcript
   and the refined prompt, with Copy / Share.

---

## Providers

| | Transcription: On-device | Transcription: OpenAI (cloud) | Refinement: Claude |
| --- | --- | --- | --- |
| Privacy | Audio stays on device | Audio sent to OpenAI | Transcript sent to Anthropic |
| Setup | None | OpenAI API key | Anthropic API key |
| Default | ✅ | — | ✅ when a key is set |
| Configurable model | — | `whisper-1` / `gpt-4o-transcribe` / `gpt-4o-mini-transcribe` | `claude-haiku-4-5-20251001` (default) |

All providers sit behind small protocols (`Transcriber`, `PromptRefiner`), so a
future on-device LLM refiner (e.g. Apple Foundation Models) can slot in without
touching the pipeline.

---

## Intent modes — refining without inventing

The original spec said *never add anything*. That keeps high-stakes prompts
(code, SQL) safe, but can leave a vague request still vague. BetterAsk Voice
threads the needle: **the model may add clarifying content, but never silently.**
Anything it adds beyond what you said appears in a separate, **labeled,
deletable "Assumptions" block** — never woven into the prompt body.

- **Faithful** (default): clean up exactly what you said. If intent is unclear,
  it surfaces its best guess as a labeled assumption instead of guessing silently.
- **Enhance**: additionally adds clarifying structure to under-specified prompts —
  additions still land in the assumptions block.

You always see what was added, can delete any of it, and choose whether to
include it when copying.

---

## Privacy

Privacy depends on provider choice.

- **On-device transcription** keeps your audio on this iPhone.
- **OpenAI transcription** sends your audio to OpenAI (clearly flagged in the UI).
- **Claude refinement** sends the raw transcript to Anthropic.

By default:

- Raw **audio is never saved** — the temporary recording is deleted right after
  transcription.
- **Nothing is written to disk** unless you turn on *Save transcripts* in
  Settings (opt-in). When on, refined results are stored locally and never leave
  the device; you can delete them anytime.
- API keys live **only in the iOS Keychain** — never in UserDefaults, the app
  bundle, logs, or this repo.

---

## Failure behavior

You are never blocked from using the raw transcript. The pipeline emits a
`warnings` entry for each fallback:

| Situation | Behavior | Warning |
| --- | --- | --- |
| Empty / silent recording | User-facing error, no API call | — (throws) |
| No Anthropic key | Shows raw transcript as the prompt | `refinement_unavailable_used_raw_transcript` |
| Transcript already clean | Skips the model call | `refinement_skipped_clean_transcript` |
| Refinement fails / times out | Falls back to raw transcript | `refinement_failed_used_raw_transcript` |
| Refinement returns empty | Falls back to raw transcript | `refinement_returned_empty_used_raw_transcript` |

---

## Tests

`BetterAskVoiceTests` covers the logic that matters and runs **without a key or
network** (⌘U):

- `RefineGateTests` — the gate's clean/short vs. long/filler/run-on/repetition decisions.
- `PipelineFallbackTests` — every rung of the fallback ladder, using stub refiners.
- `RefinerPromptTests` — both system prompts carry their invariants (preserve
  intent, don't answer, additions only in the labeled block).
- `IntentParsingTests` — splitting a model reply into prompt + assumptions.

---

## Project structure

```
project.yml                         XcodeGen project definition
BetterAskVoice/
  App/                              @main entry, settings store, AppConfig
  Models/                           VoicePromptResult, opt-in TranscriptLog
  Pipeline/                         RefineGate (gate), Pipeline (orchestration + fallback)
  Transcription/                    Transcriber protocol, AudioRecorder, on-device + OpenAI providers
  Refinement/                       PromptRefiner protocol, RefinePrompt (system prompts), AnthropicRefiner
  Security/                         KeychainStore
  Views/                            RecordView + view model, SettingsView, OnboardingView
  Resources/                        Info.plist, Assets.xcassets
BetterAskVoiceTests/                XCTest logic tests
```

---

## App Store notes

This repo is App-Store-*ready* (correct permission strings, opt-in data, no
bundled secrets) but ships no submission assets (screenshots, privacy nutrition
labels, marketing). Two honest caveats if you do submit:

- **API-key requirement.** Apps that require a user-supplied third-party API key
  can draw [Guideline 2.1](https://developer.apple.com/app-store/review/guidelines/)
  scrutiny. Mitigation here: the app is fully usable *without* a key (raw
  transcript), onboarding explains the key, and there's a "how to get a key" link.
- **Signing.** Set your own development team before archiving.

---

## Honest limitations

- On-device `SFSpeechRecognizer` is convenient and private, but less accurate
  than large cloud models; it can mishear names, product names, and code terms.
- The refiner cleans wording but cannot know your true intent beyond the
  transcript — review the raw vs. refined panes before sending anywhere
  high-stakes.
- API latency is variable; it is not promised, only measured by you.
- This is a portfolio MVP, not a polished commercial app. The voice-dictation
  space is crowded (superwhisper, Wispr Flow, Aqua Voice, …); the point here is
  a clean, private, BetterAsk-branded take on voice → *prompt*, not market
  domination.

---

## Origin

Built from an internal spec, *Whisper + Prompt Refinement Pipeline*, which
described this flow as a Python CLI. This app reimplements that pipeline
natively for iOS, swaps Whisper for Apple's on-device Speech framework, and adds
the labeled-assumptions intent model.
