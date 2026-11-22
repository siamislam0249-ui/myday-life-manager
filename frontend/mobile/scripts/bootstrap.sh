#!/usr/bin/env bash
# Generates the Android/Web platform folders (not stored in git) and applies the
# manifest/gradle settings MyDay needs. Run from frontend/mobile. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  cp pubspec.yaml /tmp/myday_pubspec.yaml
  rm -rf /tmp/myday_lib && cp -r lib /tmp/myday_lib
  flutter create --platforms=android,web --org com.myday --project-name myday --overwrite .
  cp /tmp/myday_pubspec.yaml pubspec.yaml   # flutter create must not replace our files
  rm -rf lib && cp -r /tmp/myday_lib lib
  rm -f test/widget_test.dart               # template test references the counter app
fi
python3 scripts/patch_android.py
