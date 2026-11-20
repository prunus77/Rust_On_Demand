# Source this before any harness work:  source env.sh
# Keeps every toolchain, cache and temp file on the APFS image on the external drive,
# because the internal disk is nearly full and the drive itself is exFAT (no symlinks).

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
TC=/Volumes/IpserToolchain

if [ ! -d "$TC" ]; then
  hdiutil attach "$PROJECT_DIR/toolchain.sparsebundle" >/dev/null || {
    echo "Could not mount toolchain image" >&2; return 1; }
fi

export RUSTUP_HOME="$TC/rustup"
export CARGO_HOME="$TC/cargo"
export CARGO_TARGET_DIR="$TC/target"
export JAVA_HOME="$TC/jdk/Contents/Home"
export ANDROID_HOME="$TC/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$TC/android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export GRADLE_USER_HOME="$TC/gradle"
export TMPDIR="$TC/tmp"
mkdir -p "$TMPDIR" "$ANDROID_AVD_HOME"

# NDK version is pinned; see docs/decisions.md
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/30.0.16248370"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"

export PATH="$CARGO_HOME/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Local dev signing key for release APKs (lives on the image, never in git).
# "android" is the standard public debug password; this key is for test installs only.
export CARGO_APK_RELEASE_KEYSTORE="$TC/keys/ipser-dev.keystore"
export CARGO_APK_RELEASE_KEYSTORE_PASSWORD="android"

# Flutter (only needed for the Flutter + flutter_rust_bridge comparison spike)
export FLUTTER_ROOT="$TC/flutter"
export PUB_CACHE="$TC/pub-cache"
export PATH="$FLUTTER_ROOT/bin:$PUB_CACHE/bin:$PATH"
# Dart analyzer cache (otherwise ~/.dartServer on the internal disk)
export ANALYZER_STATE_LOCATION_OVERRIDE="$TC/dart-server"
