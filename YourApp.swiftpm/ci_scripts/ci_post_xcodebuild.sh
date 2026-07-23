#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# ci_post_xcodebuild.sh — runs inside Xcode Cloud after the build action
# succeeds.  Boots a simulator, installs the built .app, launches it in
# screenshot mode, collects every captured PNG, and exports them as build
# artifacts (GitHub Actions will download them from there).
#
# The app detects screenshot mode via the SCREENSHOT_MODE environment
# variable set in its scheme (configured in Xcode's Build Action > Environment
# Variables) AND a launch argument so we can be certain at least one path
# works regardless of how the scheme is set up.
# ---------------------------------------------------------------------------

echo "ci_post_xcodebuild: starting screenshot capture"

# --- locate the built .app ------------------------------------------------
# Xcode Cloud builds into DerivedData; the exact path depends on whether the
# action is Build, Test, or Archive.  We search for the .app that matches
# the product name.
APP_NAME="YourApp"
DERIVED_DATA="${CI_DERIVED_DATA_PATH:-${HOME}/Library/Developer/Xcode/DerivedData}"
APP_PATH=$(find "${DERIVED_DATA}" -name "${APP_NAME}.app" -type d 2>/dev/null | head -n 1)

if [ -z "${APP_PATH}" ]; then
  echo "ci_post_xcodebuild: ERROR — could not find ${APP_NAME}.app in ${DERIVED_DATA}"
  echo "  Listing DerivedData for debugging:"
  find "${DERIVED_DATA}" -maxdepth 3 -type d 2>/dev/null || true
  exit 1
fi

echo "ci_post_xcodebuild: found app at ${APP_PATH}"

# --- pick a simulator ------------------------------------------------------
# We want iPhone 15 Pro (6.1") for App Store screenshots.  List available
# runtimes and pick the newest iOS 17+ one.
RUNTIME=$(xcrun simctl list runtimes -j 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
ios = [r for r in d.get('runtimes',[]) if 'iOS' in r.get('name','') and r.get('isAvailable',False)]
# prefer 17.x, fall back to newest
v17 = sorted([r for r in ios if '17' in r.get('name','')], key=lambda r: r['version'], reverse=True)
target = v17[0] if v17 else sorted(ios, key=lambda r: r['version'], reverse=True)[0]
print(target['identifier'])
" 2>/dev/null || echo "com.apple.CoreSimulator.SimRuntime.iOS-17-5")

if [ -z "${RUNTIME}" ]; then
  echo "ci_post_xcodebuild: ERROR — no iOS runtime found"
  xcrun simctl list runtimes
  exit 1
fi
echo "ci_post_xcodebuild: using runtime ${RUNTIME}"

DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
SIMULATOR_NAME="SwiPebabyScreenshots"

# Tear down any leftover simulator from a previous run
xcrun simctl delete "${SIMULATOR_NAME}" 2>/dev/null || true

# Create a fresh simulator
SIM_UDID=$(xcrun simctl create "${SIMULATOR_NAME}" "${DEVICE_TYPE}" "${RUNTIME}" 2>/dev/null)
echo "ci_post_xcodebuild: created simulator ${SIM_UDID}"

# --- boot, install, launch ------------------------------------------------
xcrun simctl boot "${SIM_UDID}" 2>/dev/null || true
# Wait for the simulator to finish booting
xcrun simctl bootstatus "${SIM_UDID}" -b 2>/dev/null || sleep 15

xcrun simctl install "${SIM_UDID}" "${APP_PATH}"
echo "ci_post_xcodebuild: installed app on simulator"

# Launch with screenshot mode argument.  The app writes .png files into its
# Documents directory and then calls exit(0) when done.
xcrun simctl launch --console "${SIM_UDID}" "com.swipebaby.app" --screenshots

# Wait for the app to finish (it calls exit(0) itself).  Cap at 120 s.
WAIT_SEC=0
MAX_WAIT=120
while [ ${WAIT_SEC} -lt ${MAX_WAIT} ]; do
  PID=$(xcrun simctl spawn "${SIM_UDID}" launchctl list 2>/dev/null | grep com.swipebaby.app | awk '{print $1}' || true)
  if [ -z "${PID}" ]; then
    echo "ci_post_xcodebuild: app exited after ~${WAIT_SEC}s"
    break
  fi
  sleep 2
  WAIT_SEC=$((WAIT_SEC + 2))
done

if [ ${WAIT_SEC} -ge ${MAX_WAIT} ]; then
  echo "ci_post_xcodebuild: WARNING — app did not exit within ${MAX_WAIT}s; forcing screenshot collection anyway"
fi

# --- collect screenshots --------------------------------------------------
SCREENSHOTS_DIR="${CI_WORKSPACE}/screenshots"
mkdir -p "${SCREENSHOTS_DIR}"

# The app writes screenshots to its Documents directory.  The path inside the
# simulator is:
#   ~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/Application/<app-UUID>/Documents/
CONTAINER_DATA=$(xcrun simctl get_app_container "${SIM_UDID}" "com.swipebaby.app" data 2>/dev/null)
DOCUMENTS="${CONTAINER_DATA}/Documents"

if [ -d "${DOCUMENTS}" ]; then
  cp "${DOCUMENTS}"/*.png "${SCREENSHOTS_DIR}/" 2>/dev/null || true
  COUNT=$(ls -1 "${SCREENSHOTS_DIR}"/*.png 2>/dev/null | wc -l | tr -d ' ')
  echo "ci_post_xcodebuild: collected ${COUNT} screenshot(s)"
  ls -la "${SCREENSHOTS_DIR}/" 2>/dev/null || true
else
  echo "ci_post_xcodebuild: WARNING — Documents directory not found at ${DOCUMENTS}"
fi

# --- export as Xcode Cloud artifact ---------------------------------------
# Xcode Cloud automatically picks up anything we write to a path set in the
# CI_ARTIFACTS_* variables.  We also tar them up for easy download.
ARTIFACT_TARBALL="${CI_WORKSPACE}/screenshots.tar.gz"
tar -czf "${ARTIFACT_TARBALL}" -C "${CI_WORKSPACE}" screenshots
echo "ci_post_xcodebuild: tarball at ${ARTIFACT_TARBALL}"

# CI_PRODUCT_PATH and friends aren't always set for Build actions, so we
# make the tarball and individual files available via the workspace.
# Xcode Cloud's "Build artifacts" will include everything in CI_WORKSPACE
# that isn't in .gitignore.

# --- cleanup --------------------------------------------------------------
xcrun simctl shutdown "${SIM_UDID}" 2>/dev/null || true
xcrun simctl delete "${SIM_UDID}" 2>/dev/null || true

echo "ci_post_xcodebuild: done"

# --- notify GitHub Actions ------------------------------------------------
# Fire a repository_dispatch event so the xcode-cloud-screenshots workflow
# picks up the artifacts and posts them to any open PR.
# Requires GH_PAT (a GitHub personal access token with repo scope) and
# GH_REPO (e.g. "owner/repo") to be set as Xcode Cloud environment variables
# (configured in Xcode's Build Action > Environment Variables).
if [ -n "${GH_PAT}" ] && [ -n "${GH_REPO}" ] && [ -n "${CI_BUILD_NUMBER}" ]; then
  COMMIT_SHA="${CI_COMMIT_REF:-${CI_GIT_REF}}"
  echo "ci_post_xcodebuild: notifying GitHub (repo=${GH_REPO}, commit=${COMMIT_SHA})"

  curl -sS -X POST \
    -H "Authorization: token ${GH_PAT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GH_REPO}/dispatches" \
    -d "$(cat <<EOF
{
  "event_type": "xcode-cloud-screenshots",
  "client_payload": {
    "build_id": "${CI_BUILD_NUMBER}",
    "commit_sha": "${COMMIT_SHA}",
    "product_id": "${CI_PRODUCT}",
    "screenshot_count": ${COUNT:-0}
  }
}
EOF
)" 2>/dev/null || echo "ci_post_xcodebuild: GitHub notification failed (non-fatal)"
else
  echo "ci_post_xcodebuild: skipping GitHub notification (GH_PAT, GH_REPO, or CI_BUILD_NUMBER not set)"
fi
