@echo off
(
    echo Running build_runner...
    flutter pub run build_runner build --delete-conflicting-outputs
) && (
    echo Running flutter build apk...
    flutter build apk --target-platform android-arm64
) && (
    echo Build succeeded.
    start explorer build\app\outputs\flutter-apk && pause
) || (
   echo Build failed. Please check the error messages. && pause
)