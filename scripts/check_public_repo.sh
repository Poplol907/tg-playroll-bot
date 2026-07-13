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
    *.db|*.db-*|*.sqlite|*.sqlite-*|*.sqlite3|*.sqlite3-*)
      violations+=("$path")
      ;;
    *.pem|*.key|*.p12|*.pfx|*.crt|*.cer|*.der)
      violations+=("$path")
      ;;
    *.jks|*.keystore|*.keystore.properties|key.properties|*/key.properties)
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

if grep -Eq '^[[:space:]]*POSTGRES_PASSWORD:[[:space:]]*[^$[:space:]]' docker-compose.yml; then
  violations+=("docker-compose.yml: literal POSTGRES_PASSWORD")
fi

if grep -Eq '^[[:space:]]*-[[:space:]]*"?[^[:space:]]*5432:5432"?[[:space:]]*$' docker-compose.yml \
  && ! grep -Eq '^[[:space:]]*-[[:space:]]*"?127\.0\.0\.1:[^[:space:]]*5432:5432"?[[:space:]]*$' docker-compose.yml; then
  violations+=("docker-compose.yml: PostgreSQL port must bind to 127.0.0.1")
fi

if awk '
  /^[[:space:]]*release[[:space:]]*\{/ { in_release = 1; next }
  in_release && /^[[:space:]]*\}/ { in_release = 0; next }
  in_release && /signingConfig[[:space:]]*=[[:space:]]*signingConfigs\.getByName\("debug"\)/ { found = 1 }
  END { exit !found }
' mobile/android/app/build.gradle.kts; then
  violations+=("mobile/android/app/build.gradle.kts: release build must not use debug signing")
fi

if ((${#violations[@]})); then
  printf 'Public repository hygiene check failed.\n' >&2
  printf '  %s\n' "${violations[@]}" >&2
  exit 1
fi

printf 'Public repository hygiene check passed.\n'
