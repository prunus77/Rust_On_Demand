# Rust AI Harness: Claude Code Instructions

Project: Ipser Labs proof of concept. Owner: Cherry Mathew Roy, with Ed and JB.

## Context

We are building an AI harness around Rust for non-developers. The user describes what they want in plain language and may not fully know what they want. The harness owns the whole loop and returns working software on a real device:

1. **Intent**: the user describes the goal in plain language.
2. **Spec**: the harness turns intent into a concrete spec with testable acceptance checks.
3. **Code**: it writes the Rust code.
4. **Compile**: it builds the code and repairs its own compiler errors.
5. **Simulate**: it runs the build in the Android emulator.
6. **Flash**: it installs the build onto a physical phone.
7. **Observe**: it checks logs, screens and behavior against the spec, and loops back to Code on failure.

Team decisions so far:

- Start with mobile. Target hardware is old, used Android phones (devices sitting in drawers as e-waste).
- Android over iPhone because it is easier to get access to.
- Proof of concept, not end product. No new hardware purchases. Embedded targets come later, after outside feedback.
- Flutter plus Rust combos on Android are an option for the UI if pure Rust cannot do it. Watch for libraries that depend on OS features.
- Long term, the harness may take over the whole phone (root, kiosk, or custom image). For now, keep it simple: install an app.

## Your role

You are building a proof of concept of this harness. You own the loop: intent, spec, code, compile, simulate, flash, observe. Optimize for a working end-to-end loop over polish. Explain decisions in plain language in each run report.

## Goal for this proof of concept

A user types one paragraph, for example "an app that splits a restaurant bill between friends, with tip". Without anyone editing code by hand, the harness produces an app that runs first in the Android emulator and then on a physical old Android phone, plus a plain-language report of what it built and how it checked it.

## Constraints

- The harness itself is written in Rust (a CLI binary). Generated apps are Rust too.
- Target: used Android phones over USB with `adb`. Do not assume new hardware. Start with an app install, not a full OS replacement; device takeover (kiosk mode, rooting) is a later phase.
- Old phones may be 32-bit. Build for both `aarch64-linux-android` and `armv7-linux-androideabi`.
- Check the minimum Android API level the current Android NDK supports and record it. Recent NDKs have dropped very old Android versions, so phones older than that are out of scope unless a workaround is documented.
- The LLM provider is pluggable behind one trait. Default to the Anthropic API via an API key in an environment variable. Never commit keys.
- Every external command (`cargo`, `adb`, emulator) runs with a timeout, and its output is captured to the run folder.
- Cap self-repair loops (default 5 attempts per stage) and stop with a clear report rather than looping forever.

## Phased plan

1. **Phase 0, toolchain spike (do first, then stop and report).**
   Install or verify rustup, the two Android targets, the Android SDK and NDK, `cargo-ndk`, `adb`, and an emulator image. Build a hand-written "hello" Rust app and run it on the emulator. Compare two UI approaches and recommend one:
   - Pure Rust, for example `android-activity` with a native activity and an immediate-mode UI such as egui.
   - Flutter with `flutter_rust_bridge`.

   Note any library that depends on OS features the phones may lack. Deliverable: `docs/phase0-findings.md`.

2. **Phase 1, loop skeleton.**
   A CLI, `harness run "<intent>"`, with one module per stage and a shared run folder `runs/<timestamp>/` holding:
   - `intent.md`
   - `spec.md`
   - `app/` (the generated Cargo project)
   - `build.log`
   - `sim.log`
   - `device.log`
   - `screens/`
   - `report.md`

   Stages can be stubbed but must pass artifacts to each other.

3. **Phase 2, AI in the loop.**
   - Intent to spec: the spec lists features plus 3 to 6 observable acceptance checks.
   - Spec to code from a fixed app template.
   - Compile, feed errors back to the model, retry.
   - Simulate: install on the emulator, launch, drive basic input with `adb shell input`, capture `adb logcat` and screenshots.
   - Observe: check results against the acceptance checks and loop back to code on failure.

4. **Phase 3, real device.**
   Detect a connected phone, record its model, Android version and CPU architecture, pick the right build target, install, launch, and observe the same way as the emulator.

5. **Phase 4, demo.**
   Run the full loop on the bill-splitting intent and on one more intent of your choice, and write up both runs.

## Acceptance criteria

- [ ] `harness run` completes all seven stages on the emulator for the bill-splitting intent with no manual code edits.
- [ ] The same build installs and launches on at least one physical old Android phone.
- [ ] Compiler errors are repaired automatically in at least one recorded run.
- [ ] Each run folder contains every artifact listed above, and `report.md` is readable by a non-developer.
- [ ] A README explains setup from a clean machine in under 15 steps.

## Working agreements

- Start with Phase 0 only, then stop and summarize findings before Phase 1.
- Commit in small steps with clear messages. Keep a `docs/decisions.md` log of choices and why.
- When something is ambiguous, pick the simplest option that keeps the loop working, and note it in `docs/decisions.md`.

## Open questions (do not block on these; note anything you learn)

- What use case makes a repurposed old phone valuable (single-purpose device, kiosk, home sensor or controller)?
- How far should "replace everything on the phone" go: an app, a locked-down kiosk, or a custom OS image?
- What is the oldest Android version worth supporting?
- Is the JetBrains Rust AI tooling worth integrating, or only a reference point?
