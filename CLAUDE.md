# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**parrot** — a minimal macOS dictation daemon. Hold `fn`, speak, release; on-device Whisper transcription (WhisperKit/CoreML/ANE) types the result at the cursor. macOS 14+, Apple Silicon only. Single SPM executable target, no `.app` bundle, no tests.

## Commands

```sh
swift build                    # debug build
swift build -c release         # release build → .build/release/parrot
swift run parrot -- --help     # run from source
.build/release/parrot doctor   # check mic/accessibility/fn-key state
```

There is no test suite, linter, or formatter configured. The debugging tools below are the substitute — use them to verify changes end-to-end.

## Debugging & diagnostics

**`parrot doctor`** — run first whenever anything doesn't work, and after switching terminals. Three checks, each with remediation text (`Doctor.swift`):
1. *microphone* — `AVCaptureDevice` auth status
2. *accessibility* — `AXIsProcessTrusted()`; on failure it names the exact parent app that needs the grant
3. *fn key mapping* — reads `defaults read com.apple.HIToolbox AppleFnUsageType`; must be 0 ("Do Nothing") or the system emoji/dictation action fires alongside the hotkey

Exit code is nonzero on hard failures; warnings (e.g. mic not-yet-prompted) don't block `run`.

**Foreground run is the primary debug loop.** `swift run parrot` logs every stage to stderr: `● recording` on fn-down, `○ captured 3.20s · rms 0.081` on release (duration + RMS — rms ≈ 0.000 means the mic captured silence), then `→ 0.42s · <transcript>` (transcription latency + text) before injection. Most bugs are localizable just by seeing which line is wrong or missing.

**Flags on `run`:**
- `--debug-hotkey` — log every CGEventTap event (type, keycode, flags in hex) to stderr. Use when fn press/release isn't detected, or to find the flags mask for a different hotkey.
- `--dump-wav` — write each capture to `/tmp/parrot-last.wav`. Use when transcripts are empty/garbage to determine whether the problem is audio capture or transcription; play the file back to check.
- `--skip-doctor` — bypass startup permission checks (they hard-block `run` otherwise).
- `--no-overlay` — disable the pill; isolates UI-layer issues.
- `--model <id>` — override the default model (see `parrot models list`).

**`parrot setup`** — interactive first-run permission walkthrough. After granting accessibility it must be re-run in a fresh process; macOS only picks up the grant on relaunch.

**Known limitation:** if macOS disables the event tap (`tapDisabledByTimeout`), parrot does not re-enable it — restart the process (see `hotkeyCallback` in `HotkeyMonitor.swift`).

## Architecture

Everything is one module in `Sources/parrot/`. The pipeline, wired together in `Parrot.swift` (`Run.run()`):

```
HotkeyMonitor (CGEventTap, fn hold) → AudioCapture (AVAudioEngine, 16kHz mono Float32)
  → WhisperKitTranscriber (protocol: Transcriber) → TextInjector (CGEvent unicode posting)
```

UI side-channels driven from the same event closure: `RecordingOverlay` (borderless click-through NSWindow pill at screen bottom) and `MenuBarController` (NSStatusItem). The process runs as an `.accessory` NSApplication — `NSApp.run()` drives everything.

Other pieces:
- `ModelRegistry.swift` — model list hard-coded in source (deliberately not JSON, keeps the binary self-contained). Adding a model = one entry; adding an engine = new `Transcriber` conformance.
- `Doctor.swift` — permission checks (mic, accessibility, fn-key system mapping) with remediation text; `run` refuses to start unless all pass.
- `Setup.swift` / `Install.swift` — one-time permission+model setup; LaunchAgent install/uninstall.
- Models download to `~/Library/Application Support/parrot/models/` on first use (WhisperKit handles the download during `warmUp()`).

Concurrency pattern: CLI subcommands are synchronous `ParsableCommand`s that bridge to async work with `DispatchSemaphore` + `Task.detached` (see model warmup). UI mutations use `MainActor.assumeIsolated` / `MainActor.run`. Status/progress output goes to **stderr**, never stdout.

## Gotchas

- **Docs drift.** `docs/architecture.md` and `.plan/plan.md` are the original design docs and are partly aspirational/stale: they say "no menubar" (there is one), and describe a TOML config, `--hotkey` flag, Parakeet engine, and JSON model registry that were never built or were built differently. The Swift source is the truth.
- **TCC identity.** Accessibility permission attaches to the *parent process* (your terminal app), not the parrot binary. Switching terminals means re-granting in System Settings → Privacy & Security → Accessibility. `parrot doctor` diagnoses this.
- Whisper non-speech tokens (`[BLANK_AUDIO]`, `[MUSIC]`, …) are stripped in `WhisperKitTranscriber`.
