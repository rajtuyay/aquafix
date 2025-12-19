To build and release your Flutter app for Android:

1. Open a terminal in your project directory.

2. Run:
   flutter build apk --release

   This will generate an APK at:
   build/app/outputs/flutter-apk/app-release.apk

3. Transfer the APK to your device and install it.

For iOS (Mac required):

1. flutter build ios --release
2. Use Xcode to archive and export the app for App Store or ad-hoc install.

For more details, see:
https://docs.flutter.dev/deployment/android
https://docs.flutter.dev/deployment/ios
