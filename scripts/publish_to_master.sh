#!/usr/bin/env bash
set -euo pipefail
# Run from extracted SQuARE-integrated package on a machine with GitHub git access.
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_URL="${REPO_URL:-https://github.com/mukullokhande99/SQuARE.git}"
TARGET="$(mktemp -d)"
trap 'rm -rf "$TARGET"' EXIT
git clone --branch master "$REPO_URL" "$TARGET/repo"
cd "$TARGET/repo"
cp -a "$SOURCE_ROOT/rtl" "$SOURCE_ROOT/tests" "$SOURCE_ROOT/vectors" "$SOURCE_ROOT/docs" .
cp -a "$SOURCE_ROOT/README.md" "$SOURCE_ROOT/.gitignore" "$SOURCE_ROOT/SOURCE_MANIFEST.txt" .
mkdir -p scripts
cp -a "$SOURCE_ROOT/scripts/publish_to_master.sh" scripts/
git add README.md .gitignore rtl tests vectors docs SOURCE_MANIFEST.txt scripts/publish_to_master.sh
if ! git diff --cached --quiet; then
  git commit -m 'Integrate complete SQuARE SoC and SPARX source tree'
  git push origin master
fi
