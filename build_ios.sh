#!/bin/bash

PUBSPEC="pubspec.yaml"

# Extract current version and build number
CURRENT=$(grep "^version:" $PUBSPEC | sed 's/version: //')
VERSION=$(echo $CURRENT | cut -d'+' -f1)
BUILD=$(echo $CURRENT | cut -d'+' -f2)

# Increment build number
NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${VERSION}+${NEW_BUILD}"

# Update pubspec.yaml
sed -i '' "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC

echo "Version bumped: $CURRENT → $NEW_VERSION"
echo "Building IPA..."

flutter build ipa --release
