# Decisions log

Newest at the bottom. Each entry: what we chose, and why.

## 2026-11-20: Phase 0

1. **Toolchain lives on the external drive, inside an APFS disk image.** The internal disk had under 1 GB free. The external drive is exFAT, which has no symlinks (the NDK needs them) and creates `._` files that break Gradle. A growable APFS sparsebundle on the drive (`toolchain.sparsebundle`, mounted at `/Volumes/IpserToolchain`) gives a normal Mac filesystem without reformatting the drive. `env.sh` mounts it and redirects every tool's home, cache and temp folder to it.
2. **Build output goes on the image, not next to the source.** `CARGO_TARGET_DIR` points at the image. Generated projects that need Gradle are copied there before building.
3. **NDK r30 (30.0.16248370), pinned.** Newest stable. It supports API 21 to 37, for both 32- and 64-bit ARM.
4. **`minSdkVersion 21` (Android 5.0) for generated apps.** This is the NDK's floor. Older phones are out of scope.
5. **Emulator: Android 14 (API 34) arm64 Google APIs image.** Native speed on Apple Silicon. It cannot run 32-bit ARM, so armv7 is verified only on real phones.
6. **Pure Rust UI: egui 0.37 (eframe, `glow` renderer) on `NativeActivity`, packaged with `cargo-apk`.** No Gradle, Rust only. `glow` (OpenGL ES 2+) over `wgpu` for old-phone compatibility.
7. **App template declares every `configChanges`.** Otherwise Android relaunches the NativeActivity and it deadlocks (observed).
8. **Apps report behaviour through logcat with an `IPSER_` prefix under tag `ipser`.** egui has no Android accessibility tree, so logs are the main observation channel.
9. **Release APKs are signed with a local dev key** stored on the image (`keys/ipser-dev.keystore`), never in git. Fine for sideloading test builds.
10. **Recommendation pending team review: pure Rust (egui) over Flutter + flutter_rust_bridge.** See `phase0-findings.md`. Flutter stays installed as the fallback.
