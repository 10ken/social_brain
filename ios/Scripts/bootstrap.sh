#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPOSITORY_DIR="$(cd "$IOS_DIR/.." && pwd)"
SPEC="$IOS_DIR/project.yml"
PROJECT="$IOS_DIR/SocialBrain.xcodeproj"
LOCKFILE="$IOS_DIR/Package.resolved"
GENERATED_LOCKFILE="$PROJECT/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

mode="local"
generate_project=1
resolve_packages=1
ci_mode=0

usage() {
  cat <<'USAGE'
Usage: Scripts/bootstrap.sh [--local | --firebase] [--ci] [--skip-package-resolution | --verify-only]

Validates the checked-in iOS project definition, generates SocialBrain.xcodeproj,
and resolves Swift Package dependencies. Local is the safe default; Firebase mode
additionally verifies the ignored Firebase configuration files.
USAGE
}

fail() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: ${1#$IOS_DIR/}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      mode="local"
      ;;
    --firebase)
      mode="firebase"
      ;;
    --ci)
      ci_mode=1
      ;;
    --skip-package-resolution)
      resolve_packages=0
      ;;
    --verify-only)
      generate_project=0
      resolve_packages=0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown option: $1"
      ;;
  esac
  shift
done

validate_static_configuration() {
  local plist
  local plan

  require_file "$SPEC"
  require_file "$LOCKFILE"
  require_file "$IOS_DIR/Config/Base.xcconfig"
  require_file "$IOS_DIR/Config/Developer.local.xcconfig.example"
  require_file "$IOS_DIR/Config/Firebase.local.xcconfig.example"
  require_file "$IOS_DIR/SocialBrain/Resources/Info.plist"
  require_file "$IOS_DIR/SocialBrain/Resources/SocialBrain.entitlements"
  require_file "$IOS_DIR/SocialBrain/Resources/PrivacyInfo.xcprivacy"
  require_file "$IOS_DIR/SocialBrain/Resources/Assets.xcassets/Contents.json"
  require_file "$IOS_DIR/SocialBrain/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
  require_file "$IOS_DIR/SocialBrainUITests/SocialBrainLaunchTests.swift"

  require_command plutil
  require_command python3
  for plist in \
    "$IOS_DIR/SocialBrain/Resources/Info.plist" \
    "$IOS_DIR/SocialBrain/Resources/SocialBrain.entitlements" \
    "$IOS_DIR/SocialBrain/Resources/PrivacyInfo.xcprivacy"; do
    plutil -lint "$plist" >/dev/null || fail "invalid plist: ${plist#$IOS_DIR/}"
  done

  for plan in "$IOS_DIR"/TestPlans/*.xctestplan; do
    require_file "$plan"
    python3 -c 'import json, pathlib, sys; json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' "$plan" \
      || fail "invalid test plan: ${plan#$IOS_DIR/}"
  done

  python3 - "$LOCKFILE" <<'PY' || fail "Package.resolved does not contain the required exact direct pins"
import json
import sys

expected = {
    "firebase-ios-sdk": {
        "location": "https://github.com/firebase/firebase-ios-sdk.git",
        "revision": "33a468adfdb75b53f05a37e7c886ca7c962b5c17",
        "version": "12.17.0",
    },
    "googlesignin-ios": {
        "location": "https://github.com/google/GoogleSignIn-iOS.git",
        "revision": "913b4005ea26aebe1c97d54e35ad82a515924c71",
        "version": "9.1.0",
    },
}

lockfile = json.load(open(sys.argv[1], encoding="utf-8"))
if lockfile.get("version") != 2:
    raise SystemExit("Package.resolved must use version 2")

pins = {pin["identity"]: pin for pin in lockfile["pins"]}
for identity, requirement in expected.items():
    pin = pins.get(identity)
    if pin is None or pin.get("kind") != "remoteSourceControl":
        raise SystemExit(f"missing remote source-control pin: {identity}")
    state = pin.get("state", {})
    if pin.get("location") != requirement["location"] or any(
        state.get(key) != requirement[key] for key in ("revision", "version")
    ):
        raise SystemExit(f"incorrect pin: {identity}")
PY

  grep -Fq 'exactVersion: 12.17.0' "$SPEC" || fail "Firebase must be pinned to 12.17.0"
  grep -Fq 'exactVersion: 9.1.0' "$SPEC" || fail "GoogleSignIn must be pinned to 9.1.0"
  grep -Fq 'SWIFT_VERSION: "5.0"' "$SPEC" || fail "project must compile in Swift 5.0 language mode"
  grep -Fq 'SWIFT_STRICT_CONCURRENCY: complete' "$SPEC" || fail "strict concurrency must be complete"
  grep -Fq 'SocialBrainUITests:' "$SPEC" || fail "UI test target is missing"
  grep -Fq 'Local.xctestplan' "$SPEC" || fail "Local test plan is missing"
  grep -Fq 'Firebase.xctestplan' "$SPEC" || fail "Firebase test plan is missing"
  grep -Fq 'UITests.xctestplan' "$SPEC" || fail "UI test plan is missing"
  grep -Fq 'GoogleService-Info.plist' "$SPEC" || fail "Firebase plist isolation is missing"
  grep -Fq 'FIREBASE_PLIST_PATH' "$IOS_DIR/Config/Firebase.xcconfig" || fail "Firebase plist path is missing"

  if grep -Fq 'product: FirebaseFirestore' "$SPEC" || grep -Fq 'product: FirebaseStorage' "$SPEC"; then
    fail "Firestore and Storage must not be linked into the iOS target"
  fi

  if grep -R -Fq '__SOCIALBRAIN_' "$IOS_DIR/TestPlans"; then
    fail "test-plan target identifiers have not been generated"
  fi

  if git -C "$REPOSITORY_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local credential_path
    for credential_path in \
      ios/Config/Firebase/GoogleService-Info.plist \
      ios/SocialBrain/Resources/GoogleService-Info.plist; do
      if git -C "$REPOSITORY_DIR" ls-files --error-unmatch "$credential_path" >/dev/null 2>&1; then
        fail "GoogleService-Info.plist must remain untracked"
      fi
    done
  fi
}

validate_firebase_configuration() {
  local service_plist="$IOS_DIR/Config/Firebase/GoogleService-Info.plist"
  local private_xcconfig="$IOS_DIR/Config/Firebase.local.xcconfig"
  local reversed_client_id

  require_file "$service_plist"
  require_file "$private_xcconfig"
  plutil -lint "$service_plist" >/dev/null || fail "invalid Firebase service plist"

  reversed_client_id="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$service_plist" 2>/dev/null || true)"
  [[ -n "$reversed_client_id" ]] || fail "Firebase service plist has no REVERSED_CLIENT_ID"
  [[ "$reversed_client_id" != *REPLACE_WITH_REAL_REVERSED_CLIENT_ID* ]] || fail "Firebase service plist still has a placeholder client ID"
  grep -Fq "$reversed_client_id" "$private_xcconfig" \
    || fail "Firebase.local.xcconfig must set GOOGLE_REVERSED_CLIENT_ID from the service plist"
}

validate_static_configuration

if [[ "$mode" == "firebase" ]]; then
  validate_firebase_configuration
fi

if [[ "$generate_project" -eq 0 ]]; then
  printf 'bootstrap: static configuration verified (%s mode)\n' "$mode"
  exit 0
fi

require_command xcodegen
require_command xcodebuild

if [[ "$ci_mode" -eq 1 ]]; then
  xcodegen --version | grep -Fq 'Version: 2.45.4' \
    || fail "CI requires XcodeGen 2.45.4"
fi

(
  cd "$IOS_DIR"
  xcodegen generate --spec project.yml
)

[[ -d "$PROJECT" ]] || fail "XcodeGen did not create SocialBrain.xcodeproj"

mkdir -p "$(dirname "$GENERATED_LOCKFILE")"
cp "$LOCKFILE" "$GENERATED_LOCKFILE"

scheme="SocialBrain-Local"
if [[ "$mode" == "firebase" ]]; then
  scheme="SocialBrain-FirebaseDebug"
fi

xcodebuild -list -project "$PROJECT" >/dev/null

if [[ "$resolve_packages" -eq 1 ]]; then
  xcodebuild -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$scheme" \
    -clonedSourcePackagesDirPath "$IOS_DIR/.build/SourcePackages"
fi

xcodebuild -showTestPlans -project "$PROJECT" -scheme "$scheme" >/dev/null

printf 'bootstrap: generated and verified %s (%s mode)\n' "${PROJECT#$REPOSITORY_DIR/}" "$mode"
