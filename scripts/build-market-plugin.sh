#!/usr/bin/env bash
set -euo pipefail

# Builds the market plugin from source and copies the jar to .local-dev.
# Usage:
#   scripts/build-market-plugin.sh [--clean] [path-to-craftalism-market-repo]
# Defaults to incremental builds for faster local iteration.

DO_CLEAN="${DO_CLEAN:-0}"
if [[ "${1:-}" == "--clean" ]]; then
  DO_CLEAN=1
  shift
fi

REPO_DIR="${1:-../craftalism-market}"
if [[ ! -d "$REPO_DIR" ]]; then
  echo "Repository not found: $REPO_DIR" >&2
  echo "Clone it next to this repo or pass an explicit path." >&2
  exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/resolve-plugin-source-dir.sh"
REPO_DIR="$("$SOURCE_DIR" "$REPO_DIR")"

pushd "$REPO_DIR" >/dev/null
if [[ "$DO_CLEAN" == "1" ]]; then
  ./gradlew clean build
else
  ./gradlew build
fi
JAR_PATH="$(find build/libs -maxdepth 1 -type f -name 'craftalism-market-*.jar' ! -name '*-plain.jar' | sort | head -n 1)"
popd >/dev/null

if [[ -z "$JAR_PATH" ]]; then
  echo "Built jar not found under $REPO_DIR/build/libs" >&2
  exit 1
fi

mkdir -p .local-dev
cp "$REPO_DIR/$JAR_PATH" .local-dev/craftalism-market.jar

echo "Built plugin jar: .local-dev/craftalism-market.jar"
