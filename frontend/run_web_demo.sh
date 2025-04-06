#!/bin/bash

# Use the simplified web demo pubspec and main file
cp pubspec_web.yaml pubspec.yaml
flutter clean
flutter pub get
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5001 -t lib/main_web.dart
