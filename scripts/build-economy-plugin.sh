#!/usr/bin/env bash
set -euo pipefail

# Builds the economy plugin from source and copies the jar to .local-dev.
# Usage:
#   scripts/build-economy-plugin.sh [--clean] [path-to-craftalism-economy-repo]
# Defaults to incremental builds for faster local iteration.

DO_CLEAN="${DO_CLEAN:-0}"
if [[ "${1:-}" == "--clean" ]]; then
  DO_CLEAN=1
  shift
fi

REPO_DIR="${1:-../craftalism-economy/java}"
if [[ ! -d "$REPO_DIR" ]]; then
  echo "Repository not found: $REPO_DIR" >&2
  echo "Clone it next to this repo or pass an explicit path." >&2
  exit 1
fi

if [[ ! -f "$REPO_DIR/gradlew" ]]; then
  echo "gradlew not found in $REPO_DIR" >&2
  exit 1
fi

pushd "$REPO_DIR" >/dev/null
if [[ "$DO_CLEAN" == "1" ]]; then
  ./gradlew clean build
else
  ./gradlew build
fi
JAR_PATH="$(find build/libs -maxdepth 1 -type f -name 'craftalism-economy-*.jar' ! -name '*-plain.jar' | sort | head -n 1)"
popd >/dev/null

if [[ -z "$JAR_PATH" ]]; then
  echo "Built jar not found under $REPO_DIR/build/libs" >&2
  exit 1
fi

mkdir -p .local-dev
cp "$REPO_DIR/$JAR_PATH" .local-dev/craftalism-economy.jar

echo "Built plugin jar: .local-dev/craftalism-economy.jar"
