# Running the app in Android Studio

The app is a Flutter project in `mobile/`. Android Studio runs it once the Flutter plugin is installed.
The Android project files (`mobile/android/`) are already in the repo, with camera and internet
permissions, text-to-speech access, minSdk 26 and portrait mode set up.

## One-time setup (Mac)
1. **Install Flutter** (3.50 or newer; the Android build uses Gradle 9.5 and Android Gradle Plugin 9.3, which older
   Flutter versions can't build): https://docs.flutter.dev/get-started/install/macos
   then check it with `flutter doctor` in Terminal and fix anything marked ✗ for Android.
2. **Install Android Studio**, open it, and finish the setup wizard (it installs the Android SDK).
3. In Android Studio: **Settings → Plugins → Marketplace**, install **Flutter** (it also installs Dart), then restart.
4. **Settings → Languages & Frameworks → Flutter**: set the Flutter SDK path (e.g. `~/development/flutter`).
5. Accept the Android licenses once: `flutter doctor --android-licenses`.

## Open and run
1. **File → Open** and choose the **`formcoach-app/mobile`** folder (not the repo root, not `android/`).
2. When the banner says "pub get has not been run", click **Get dependencies**
   (or run `flutter pub get` in the terminal tab). This also writes `android/local.properties`.
3. Pick a device in the toolbar:
   - **Real phone (recommended, the camera matters):** turn on Developer options and USB debugging on the phone,
     plug it in, tap "Allow" on the phone.
   - **Emulator:** Device Manager → create a Pixel device (API 34+). The emulator camera is a fake scene, so pose
     detection won't do much.
4. Press the green **Run ▶** button. The first build takes a few minutes (Gradle downloads).

### Pointing the app at the backend
The backend address is passed when you run. In Android Studio: **Run → Edit Configurations… → main.dart →
Additional run args**:
```
--dart-define=BACKEND_URL=http://192.168.1.23:8080 --dart-define=API_KEY=your-key
```
- Backend on your laptop: use the laptop's Wi-Fi IP (`ipconfig getifaddr en0`), phone on the same Wi-Fi.
- Emulator with a laptop backend: the default `http://10.0.2.2:8080` already works.
- Deployed backend: `https://formcoach-api-XXXX.run.app`.

### Model A
Copy `form_classifier.tflite` from the models repo (`runs/finetune/`) into `mobile/assets/models/`, then run again.
Without it the app still runs: it counts reps and the coach waits for the model.

## Tests
`flutter test` (or right-click the `test` folder → Run) runs the parity tests (Dart geometry matches the Python
training code) and the session-summary tests.

## Common build problems
| Message | Fix |
|---|---|
| `flutter.sdk not set in local.properties` | Run `flutter pub get` in `mobile/`. |
| `minSdkVersion 21 cannot be smaller than version 26` | Already set to 26 in `android/app/build.gradle.kts`; run **Build → Clean Project** or `flutter clean`. |
| Plugin asks for a newer `compileSdk` / NDK | Upgrade Flutter (`flutter upgrade`), or set `compileSdk = 36` / the NDK version it names in `android/app/build.gradle.kts`. |
| "Your project's Android Gradle Plugin version is lower than…" warning | Raise the `com.android.application` version in `android/settings.gradle.kts` to the one Flutter suggests. |
| "Your project's Gradle version (…) is lower than Flutter's minimum supported version" | Run `git pull` (the project is on Gradle 9.5). If your Flutter is newer still, run `flutter create --platforms android fc_template` in a scratch folder and copy the versions from its `android/` files. |
| "Java/Gradle incompatibility" with a new Java version | Point Flutter at Java 21: install Temurin 21, then `flutter config --jdk-dir="$(/usr/libexec/java_home -v 21)"`. |
| "No macOS desktop project configured" / "not configured to build on the web" / `dart:ffi` errors | You picked macOS or Chrome as the device. Pick an Android phone or emulator; `flutter config --no-enable-web --no-enable-macos-desktop` hides the others. |
| Phone not listed | Unlock the phone, accept the USB debugging prompt, try another cable; run `flutter devices`. |

## iOS (optional, needs a Mac with Xcode)
Run `flutter create --platforms ios .` in `mobile/` once (it adds `ios/` without touching existing files), add
`NSCameraUsageDescription` to `ios/Runner/Info.plist`, set `platform :ios, '15.5'` in `ios/Podfile`, then run from
Xcode or Android Studio with an iPhone connected.
