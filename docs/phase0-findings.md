# Phase 0 findings: toolchain spike

Date: 20 Nov 2026. Machine: Mac with Apple M2, 16 GB RAM, macOS 26.5.2.

## Summary

- The full toolchain is installed and working: Rust, both Android targets, Android SDK and NDK, `cargo-ndk`, `adb`, an emulator, and Flutter.
- A hand-written Rust app was built, installed on the emulator, launched, tapped and typed into by script, and checked from logs and screenshots. That is the whole loop the harness has to automate, done by hand once.
- **Recommendation: pure Rust (egui on a native activity) for the proof of concept**, with one caveat to plan around (see "Observing the screen"). Flutter + Rust also works and stays the fallback.

## What is installed, and where

The internal disk was full (under 1 GB free), so everything lives on the external drive `Cherry_NvMe`. That drive is exFAT, which can't store symlinks and litters folders with `._` files (both break Android tooling), so the toolchain sits inside an APFS disk image on the drive: `toolchain.sparsebundle`, mounted at `/Volumes/IpserToolchain`. `source env.sh` mounts it and points every tool at it.

| Tool | Version | Notes |
|---|---|---|
| Rust (rustup, minimal profile) | rustc 1.100.0 | targets `aarch64-linux-android`, `armv7-linux-androideabi` (+ `x86_64-linux-android`, unused) |
| JDK | Temurin 17.0.21 | needed by Android SDK tools, `keytool` and Gradle |
| Android cmdline-tools | 15641748 | |
| Android NDK | r30 (30.0.16248370) | |
| Build-tools / platform | 35.0.1 / android-35 | |
| platform-tools (`adb`) | 37.0.3 | |
| Emulator | 37.3.10 | AVD `ipser_api34`: Android 14, Google APIs, arm64-v8a, Pixel 4 |
| `cargo-ndk` | 4.1.2 | |
| `cargo-apk` | 0.10.0 | used to package the pure-Rust APK |
| Flutter | 3.50.1 stable | comparison spike only |
| `flutter_rust_bridge_codegen` | 2.13.0 | comparison spike only |

Disk used: about 24 GB inside the image (Android SDK 12 GB, of which NDK 5.6 GB and system image 4.2 GB; Flutter 4 GB; Gradle cache 2.7 GB; Rust 0.9 GB; build output 1.5 GB). Without Flutter, the pure-Rust path needs about 15 GB.

## Minimum Android version

From the NDK's own `meta/platforms.json` and `meta/abis.json`: **NDK r30 supports API 21 to 37**, so Android 5.0 Lollipop (2014) and newer, for both `armeabi-v7a` (32-bit) and `arm64-v8a`.

- The pure-Rust APK is built with `minSdkVersion 21`.
- The Flutter APK came out at `minSdkVersion 24` (Android 7.0), because that is Flutter's own floor.
- Not yet verified on a real device older than Android 14. Phones older than Android 5.0 are out of scope.

## The hello app (pure Rust)

`spikes/hello-egui/`: a heading, a "Tap me" button with a counter, and a text field. Every tap and keystroke is logged to logcat under the tag `ipser` (`IPSER_START`, `IPSER_TAP count=N`, `IPSER_TEXT value=...`), so the harness can check behaviour from logs.

Evidence is in `docs/phase0-evidence/`:

| Check | Result |
|---|---|
| Build for arm64 + armv7, one APK | Pass. 5.3 MB APK, about 50 s per target for the first release build |
| Install on emulator | Pass, about 0.5 s |
| Launch | Pass, after a fix (see "Deadlock on launch") |
| `adb shell input tap` x3 on the button | Pass. Three `IPSER_TAP` lines, screen shows "Taps: 3" (`02-after-3-taps.png`) |
| Tap text field, soft keyboard opens | Pass (`mInputShown=true`) |
| `adb shell input text "42.50"` | Pass. Field shows 42.50, `IPSER_TEXT value=42.50` logged (`04-after-typing.png`) |
| Rotate to landscape | Pass. Same process, state kept, no relaunch (`05-rotated.png`) |

## The hello app (Flutter + Rust)

`spikes/hello_frb/`: the standard `flutter_rust_bridge` template. Dart calls a Rust function `greet("Tom")` and shows the result. It built (28.3 MB APK, arm64 + armv7, about 80 s Gradle build after the first run), installed and launched (700 ms cold start). The screen shows the Rust result (`06-flutter-frb.png`).

## Problems hit, and what they mean for the harness

1. **Deadlock on launch (pure Rust).** The first launch hung on the splash screen. A native thread dump showed that Android relaunched the activity for a configuration change, the Java side waited in `onDestroy` for the Rust thread, and the Rust thread never answered. Fix: declare every `configChanges` in the manifest, so Android never relaunches the activity. *Harness: bake this into the app template, and treat "window never gets focus" as a known failure with a known fix.*
2. **API drift in libraries.** eframe 0.37 renamed `App::update(ctx)` to `App::ui(ui)`. Models trained on older code will write the old API. *Harness: pin crate versions in the template and give the model a short, current API cheat sheet in the prompt. Compile-error repair will also catch this.*
3. **exFAT breaks Gradle.** macOS writes `._` files on exFAT, and Gradle fails on them in Android resource folders. *Harness: generated projects and build output must live on APFS (the image), not on the exFAT drive.*
4. **No `timeout` command on macOS.** *Harness: implement timeouts in Rust (spawn plus wait with a deadline), not in shell.*
5. **The emulator cannot run 32-bit ARM.** The arm64 image reports no 32-bit ABIs (`abilist32` is empty), and Apple Silicon can't execute 32-bit ARM code. *Harness: armv7 builds can only be verified on a real phone, which matters because old phones are often 32-bit.*
6. **A visible emulator window lets people interfere.** During testing, three taps appeared that the script didn't send, most likely from someone clicking in the emulator window. *Harness: run the emulator with `-no-window` for clean, repeatable checks.*

## Comparing the two UI approaches

| | Pure Rust (egui + `android-activity`) | Flutter + `flutter_rust_bridge` |
|---|---|---|
| Languages the model must write | Rust only | Rust + Dart (+ generated glue) |
| Build chain | `cargo apk` (no Gradle) | Flutter + Gradle + cargokit + codegen |
| Moving parts that can break | Few | Many (Gradle, Kotlin/AGP versions, codegen, Dart) |
| APK size (arm64 + armv7) | 5.3 MB | 28.3 MB |
| Minimum Android | API 21 (5.0) | API 24 (7.0) |
| Look and feel | Plain, game-style widgets | Native-feeling Material widgets |
| Text input / soft keyboard | Works for basic fields; less polished (no number pad hints, no autocorrect) | Full platform keyboard support |
| Accessibility tree (`uiautomator`) | **Empty.** egui draws pixels, so Android can't see buttons | Real labels, which the harness can read |
| Fits "generated apps are Rust too" | Fully | Partly (UI is Dart) |
| OS features it depends on | OpenGL ES 2.0+ via EGL. Every Android 5+ phone has it | Impeller renderer needs Vulkan, with OpenGL ES fallback. Larger memory footprint on low-RAM phones |

### Recommendation

**Pure Rust with egui** for the proof of concept. It matches the constraint that generated apps are Rust, has one language and one build tool for the model to get right, has fewer places to fail, gives smaller APKs, and reaches older phones (API 21). For self-repair loops, a single `cargo` error stream is far easier than mixed Dart, Gradle and Rust errors.

**Observing the screen.** Because egui draws its own pixels, the harness can't find a button by its label through Android. Plan for the Observe stage:

- Generated apps log every user-visible event and state change to logcat in a fixed format (`IPSER_*`). Acceptance checks are checked mainly from logs.
- The app template exposes widget positions. At startup, the app logs each interactive widget's id and screen rectangle (egui knows these), so the harness can tap by id instead of guessing coordinates.
- Screenshots are kept for the report and for a vision-model check of "does this look right".

**Keep Flutter + frb as the fallback** if a later app needs rich native text input, platform widgets or accessibility. The toolchain is already installed and proven.

## Libraries to watch on old phones

- **egui / glow:** needs OpenGL ES 2.0+ and EGL, which every Android 5+ phone has. `wgpu` (the alternative egui renderer) needs Vulkan or GLES 3, so stay on `glow`.
- **winit / android-activity (NativeActivity):** works from API 21. GameActivity would need Gradle and a Java/Kotlin build, so it was avoided.
- **Flutter Impeller:** prefers Vulkan 1.1. Older phones fall back to OpenGL ES, which is slower and less tested.
- Anything needing Google Play Services (maps, push, location fusion) won't work on phones that have been reset without a Google account or run custom ROMs. Generated apps should avoid it.
- Network TLS: very old Android versions have outdated root certificates, so prefer bundling roots (`rustls` + `webpki-roots`) over the system store.

## How to reproduce

```bash
cd "/Volumes/Cherry_NvMe/Ipser Project"
source env.sh                          # mounts the toolchain image, sets paths
cd spikes/hello-egui && cargo apk build --release
emulator -avd ipser_api34 -no-window -no-audio &
adb wait-for-device
adb install -r /Volumes/IpserToolchain/target/release/apk/hello-egui.apk
adb shell am start -n com.ipser.hello/android.app.NativeActivity
adb shell input tap 540 537
adb logcat -d -s ipser
```

## Not done in Phase 0

- No physical phone tested yet (Phase 3). This is the only way to verify the armv7 build.
- No API 21 to 23 emulator image tested. Arm64 images for these old versions were not checked; a real old phone is the more reliable test.
