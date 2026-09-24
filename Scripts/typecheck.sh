#!/bin/bash
# Typechecks every Swift file in the app and test targets as one module, under the
# same flags the Xcode project uses. Agents cannot run xcodebuild, so this is the
# mechanical check that a change still compiles. It is not a substitute for the
# real build or for running the tests.
set -euo pipefail

cd "$(dirname "$0")/.."

SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
PLUGIN="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

find Gabay GabayTests -name '*.swift' -exec cp {} "$WORK"/ \;

# The two targets compile separately in Xcode, so the test files import the app
# module. Typechecking them as one module makes those imports self-references.
perl -pi -e 's/^\@testable import Gabay$//; s/^import Gabay$//' "$WORK"/*.swift

echo "Typechecking $(ls "$WORK"/*.swift | wc -l | tr -d ' ') files..."

swiftc -swift-version 6 -typecheck -module-name Gabay \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -F "$SDK/../../Library/Frameworks" \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -enable-upcoming-feature MemberImportVisibility \
  -load-plugin-library "$PLUGIN" \
  "$WORK"/*.swift

echo "Clean."
