#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# ci_post_clone.sh — runs inside Xcode Cloud immediately after the repo is
# cloned and before any build or test action.
#
# This repo is a Swift Playgrounds .swiftpm package, so there are no SPM
# dependencies or CocoaPods to resolve.  The script just makes sure the
# environment is predictable.
# ---------------------------------------------------------------------------

echo "Xcode Cloud — post-clone hook"
echo "  CI_WORKSPACE       = ${CI_WORKSPACE:-(not set)}"
echo "  CI_PRODUCT         = ${CI_PRODUCT:-(not set)}"
echo "  CI_XCODEBUILD_ACTION = ${CI_XCODEBUILD_ACTION:-(not set)}"
echo "  CI_DERIVED_DATA_PATH = ${CI_DERIVED_DATA_PATH:-(not set)}"

# --- set Apple Developer Team Identifier ----------------------------------
# Package.swift ships with a blank teamIdentifier placeholder.  Baking the
# real team ID at build time means the Archive action can code-sign without
# manual per-developer configuration (same pattern as the GitHub release
# workflow, release-swiftpm.yml).
if [ -n "${APPLE_TEAM_ID}" ]; then
  echo "ci_post_clone: setting teamIdentifier to ${APPLE_TEAM_ID}"
  sed -i "s/teamIdentifier: \"\"/teamIdentifier: \"${APPLE_TEAM_ID}\"/" YourApp.swiftpm/Package.swift
else
  echo "ci_post_clone: APPLE_TEAM_ID not set — Archive action will need manual signing config"
fi

# If you ever add a Package.resolved or need pinned dependency versions,
# resolve them here.  For a pure SwiftUI Playgrounds app this is a no-op.
echo "ci_post_clone: done"
