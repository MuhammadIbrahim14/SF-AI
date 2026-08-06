# SIE Technology Spike — Camera + Hand + Virtual Cursor

**Status:** Disposable proof of concept (not production SIE)  
**Targets:** Flutter Web (Chrome/Edge) + Android only  
**Isolation:** `spikes/sie_camera_hand_cursor/` — **not** wired into the SkillForge host app

This spike validates the highest-risk assumptions from Stage 2 Prompt 06 before `/packages/skillforge_sie` exists.

Frozen design docs `01`–`06` were **not** modified.

---

## Run

```bash
cd spikes/sie_camera_hand_cursor
flutter pub get

# Web (Chrome)
flutter run -d chrome

# Android device/emulator
flutter run -d android
```

### Web notes

- First run downloads MediaPipe WASM + `hand_landmarker.task` from Google/CDN (needs network).
- Browser will prompt for camera permission.
- Live camera preview appears as a small PiP (bottom-right DOM overlay).
- Virtual cursor + optional landmark skeleton render in Flutter.

### Android notes

- Uses `camera` + `hand_landmarker` (MediaPipe JNI, GPU delegate).
- `minSdk = 26`, camera permission required.
- Full-screen `CameraPreview` under the Flutter cursor overlay.

---

## What is in scope

| Feature | Included |
|---------|----------|
| Camera permission + preview | Yes |
| Continuous frame / video processing | Yes |
| Single-hand landmarks | Yes |
| Landmark debug overlay | Yes (toggle) |
| Index-fingertip → virtual cursor | Yes |
| EMA smoothing + recovery states | Yes |
| FPS / latency HUD | Yes |
| Click / drag / scroll / gestures | **No** |
| SkillForge integration | **No** |

---

## Layout

```text
lib/
  main.dart
  models/spike_models.dart
  pipeline/cursor_mapper.dart
  pipeline/metrics_collector.dart
  platforms/          # web vs android conditional imports
  ui/
web/hand_landmarker_bridge.js
BENCHMARK_REPORT.md
```

---

## Success criteria (see BENCHMARK_REPORT.md)

Stable hand detection, responsive cursor, performance near targets, architecture assumptions still valid, no critical blockers on Web/Android.
