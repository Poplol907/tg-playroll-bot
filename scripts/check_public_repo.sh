#!/usr/bin/env bash

# Fail when files that must remain local are tracked by Git.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

violations=()

while IFS= read -r -d '' path; do
  case "$path" in
    .env.prod.example)
      ;;
    .env|.env.*|*/.env|*/.env.*)
      violations+=("$path")
      ;;
    *.db|*.db-*|*.sqlite|*.sqlite3)
      violations+=("$path")
      ;;
    *.pem|*.key|*.p12|*.pfx|*.crt|*.cer|*.der)
      violations+=("$path")
      ;;
    *.jks|*.keystore|*.keystore.properties|key.properties)
      violations+=("$path")
      ;;
    *.dump|*.dump.gz|*.sql.gz)
      violations+=("$path")
      ;;
    *.log|*.log.*)
      violations+=("$path")
      ;;
    .coverage|.coverage.*|coverage.lcov|lcov.info|*.lcov|coverage/*|*/coverage/*|htmlcov/*|*/htmlcov/*)
      violations+=("$path")
      ;;
  esac
done < <(git ls-files -z)

if ((${#violations[@]})); then
  printf 'Public repository hygiene check failed. Tracked local-only files:\n' >&2
  printf '  %s\n' "${violations[@]}" >&2
  exit 1
fi

printf 'Public repository hygiene check passed.\n'
