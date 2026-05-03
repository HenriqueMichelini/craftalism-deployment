#!/usr/bin/env bash
set -euo pipefail

fail=0

report_forbidden() {
  local reason="$1"
  local path="$2"

  printf '[hygiene] forbidden tracked file (%s): %s\n' "$reason" "$path" >&2
  fail=1
}

while IFS= read -r path; do
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    continue
  fi

  case "$path" in
    env.example|.env.local.example)
      ;;
    .env|.env.*|*.env)
      report_forbidden "environment file" "$path"
      ;;
    *.pem|*.key|*.secret)
      report_forbidden "secret material" "$path"
      ;;
    before-runtime-fix/*|after-runtime-fix/*|after-runtime-fix-30min/*)
      report_forbidden "generated runtime snapshot" "$path"
      ;;
    before-runtime-fix.tar.gz|after-runtime-fix.tar.gz|after-runtime-fix-30min.tar.gz)
      report_forbidden "generated runtime snapshot archive" "$path"
      ;;
    runtime-snapshot-*/*|runtime-snapshot-*.tar.gz)
      report_forbidden "generated runtime snapshot" "$path"
      ;;
  esac
done < <(git ls-files)

if (( fail != 0 )); then
  printf '[hygiene] remove generated/secret artifacts from git before merging.\n' >&2
  exit 1
fi

printf '[hygiene] repository hygiene checks passed.\n'
