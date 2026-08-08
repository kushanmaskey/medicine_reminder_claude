#!/bin/bash
# Build production Android App Bundle for Google Play
flutter build appbundle --release --dart-define=ENV=production
echo ""
echo "✅ Production AAB built: build/app/outputs/bundle/release/app-release.aab"
