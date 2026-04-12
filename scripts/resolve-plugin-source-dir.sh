#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "Usage: $0 <plugin-repo-or-source-dir>" >&2
  exit 1
fi

INPUT_DIR="$1"

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Directory not found: $INPUT_DIR" >&2
  exit 1
fi

if [[ -f "$INPUT_DIR/gradlew" ]]; then
  printf '%s\n' "$INPUT_DIR"
  exit 0
fi

if [[ -f "$INPUT_DIR/java/gradlew" ]]; then
  printf '%s\n' "$INPUT_DIR/java"
  exit 0
fi

echo "Could not find a Gradle plugin project under $INPUT_DIR or $INPUT_DIR/java" >&2
exit 1
