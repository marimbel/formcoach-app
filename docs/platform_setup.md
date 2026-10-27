# Building the app

Requirements: Flutter 3.27+ (Dart 3.4+), Android Studio and/or Xcode 15.3+. The repo contains `lib/`, `test/`,
`assets/` and `pubspec.yaml`; generate the platform folders once:

```bash
cd mobile
flutter create --org edu.csueastbay --project-name formcoach --platforms android,ios .
flutter pub get
flutter test          # parity tests: Dart geometry/rep counter == Python training code
```
`flutter create` does not overwrite `lib/` or `pubspec.yaml`. Commit the generated `android/` and `ios/` folders
after making the edits below.

## Android
`android/app/build.gradle` (or `build.gradle.kts`):
```gradle
defaultConfig { minSdk = 26 }   // TFLite plugin needs API 26+; ML Kit needs 21+
```
`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```
For a local backend over plain http (emulator: `http://10.0.2.2:8080`), add
`android:usesCleartextTraffic="true"` to `<application>` in `android/app/src/debug/AndroidManifest.xml` only.

## iOS
`ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>FormCoach uses the camera to watch your exercise form. Video stays on your phone; only a small crop per rep is sent for coaching.</string>
```
`ios/Podfile`: `platform :ios, '15.5'`, and in Xcode exclude `armv7` (Runner → Build Settings → Excluded Architectures),
as the ML Kit plugin requires. Then `cd ios && pod install`.

## Running
```bash
# Model A: copy from the models repo
cp ../../formcoach-models/runs/finetune/form_classifier.tflite assets/models/
# point the app at the backend
flutter run --release \
  --dart-define=BACKEND_URL=https://formcoach-api-XXXX.us-central1.run.app \
  --dart-define=API_KEY=the-shared-key
```
Use `--release` (or `--profile`) for any timing measurements: debug builds are several times slower.
