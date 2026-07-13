#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

test_index="$(mktemp)"
trap 'rm -f "$test_index"' EXIT

GIT_INDEX_FILE="$test_index" git read-tree HEAD

candidates=(
  android/key.properties
  local/cache.sqlite-wal
  local/cache.sqlite-shm
  local/cache.sqlite3-wal
  local/cache.sqlite3-shm
)

for candidate in "${candidates[@]}"; do
  GIT_INDEX_FILE="$test_index" git update-index --add --cacheinfo \
    "100644,e69de29bb2d1d6434b8b29ae775ad8c2e48c5391,$candidate"
done

if output="$(GIT_INDEX_FILE="$test_index" bash scripts/check_public_repo.sh 2>&1)"; then
  printf 'Expected hygiene check to reject nested signing and SQLite sidecar paths.\n' >&2
  exit 1
fi

for candidate in "${candidates[@]}"; do
  case "$output" in
    *"$candidate"*) ;;
    *)
      printf 'Hygiene output omitted expected violation: %s\n' "$candidate" >&2
      exit 1
      ;;
  esac
done

printf 'Nested signing and SQLite sidecar paths are rejected.\n'

fixture_root="$(mktemp -d)"
trap 'rm -f "$test_index"; rm -rf "$fixture_root"' EXIT

git -C "$fixture_root" init -q
mkdir -p "$fixture_root/scripts" "$fixture_root/mobile/android/app"
cp scripts/check_public_repo.sh "$fixture_root/scripts/check_public_repo.sh"

cat > "$fixture_root/docker-compose.yml" <<'EOF'
services:
  db:
    environment:
      POSTGRES_PASSWORD: fixture-password-not-a-secret
    ports:
      - "5432:5432"
EOF

cat > "$fixture_root/mobile/android/app/build.gradle.kts" <<'EOF'
android {
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
EOF

git -C "$fixture_root" add .

if output="$(cd "$fixture_root" && bash scripts/check_public_repo.sh 2>&1)"; then
  printf 'Expected hygiene check to reject unsafe release configuration.\n' >&2
  exit 1
fi

for violation in \
  'docker-compose.yml: literal POSTGRES_PASSWORD' \
  'docker-compose.yml: PostgreSQL port must bind to 127.0.0.1' \
  'mobile/android/app/build.gradle.kts: release build must not use debug signing'; do
  case "$output" in
    *"$violation"*) ;;
    *)
      printf 'Hygiene output omitted expected configuration violation: %s\n' "$violation" >&2
      exit 1
      ;;
  esac
done

printf 'Unsafe release configuration is rejected.\n'

debug_fixture_root="$(mktemp -d)"
trap 'rm -f "$test_index"; rm -rf "$fixture_root" "$debug_fixture_root"' EXIT

git -C "$debug_fixture_root" init -q
mkdir -p "$debug_fixture_root/scripts" "$debug_fixture_root/mobile/android/app"
cp scripts/check_public_repo.sh "$debug_fixture_root/scripts/check_public_repo.sh"

cat > "$debug_fixture_root/docker-compose.yml" <<'EOF'
services:
  db:
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?required}
    ports:
      - "127.0.0.1:5432:5432"
EOF

cat > "$debug_fixture_root/mobile/android/app/build.gradle.kts" <<'EOF'
android {
    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
EOF

git -C "$debug_fixture_root" add .

if ! (cd "$debug_fixture_root" && bash scripts/check_public_repo.sh); then
  printf 'Expected hygiene check to allow debug build signing.\n' >&2
  exit 1
fi

printf 'Debug build signing is allowed.\n'
