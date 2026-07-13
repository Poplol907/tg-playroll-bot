#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
gradle_file="$repo_root/mobile/android/app/build.gradle.kts"

for property in storeFile storePassword keyAlias keyPassword; do
  if ! grep -Fq "\"$property\"" "$gradle_file"; then
    printf 'Release signing validation must require %s.\n' "$property" >&2
    exit 1
  fi
done

if ! grep -Fq 'val missingReleaseSigningProperties = requiredReleaseSigningProperties.filter' "$gradle_file"; then
  printf 'Release signing must collect missing required properties before configuration.\n' >&2
  exit 1
fi

if ! grep -Fq 'if (missingReleaseSigningProperties.isEmpty()) {' "$gradle_file"; then
  printf 'Release signing configuration must be skipped when required properties are missing.\n' >&2
  exit 1
fi

if ! grep -Fq 'Missing values: ${missingReleaseSigningProperties.joinToString()}' "$gradle_file"; then
  printf 'Release signing failure must name missing properties.\n' >&2
  exit 1
fi

printf 'Release signing properties are validated before configuration.\n'
