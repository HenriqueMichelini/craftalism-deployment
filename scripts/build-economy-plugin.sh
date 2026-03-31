#!/usr/bin/env bash
set -euo pipefail

# Builds the economy plugin from source and copies the jar to .local-dev.
# Usage:
#   scripts/build-economy-plugin.sh [path-to-craftalism-economy-repo]

REPO_DIR="${1:-../craftalism-economy}"
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
./gradlew clean build
JAR_PATH="$(ls build/libs/craftalism-economy-*.jar | grep -v -- '-plain\.jar' | head -n 1)"
popd >/dev/null

mkdir -p .local-dev
cp "$REPO_DIR/$JAR_PATH" .local-dev/craftalism-economy.jar

echo "Built plugin jar: .local-dev/craftalism-economy.jar"
