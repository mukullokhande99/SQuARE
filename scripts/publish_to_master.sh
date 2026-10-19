#!/usr/bin/env bash
set -euo pipefail
# Run at the root of the extracted SQuARE-integrated directory.
# Requires git and credentials authorized to push to mukullokhande99/SQuARE.
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_URL="${REPO_URL:-https://github.com/mukullokhande99/SQuARE.git}"
TARGET="$(mktemp -d)"
trap 'rm -rf "$TARGET"' EXIT

git clone --branch master "$REPO_URL" "$TARGET/repo"
cd "$TARGET/repo"
# Copy source tree without overwriting the repository .git directory.
cp -a "$SOURCE_ROOT/rtl" "$SOURCE_ROOT/tests" "$SOURCE_ROOT/vectors" "$SOURCE_ROOT/docs" .
cp -a "$SOURCE_ROOT/README.md" "$SOURCE_ROOT/.gitignore" .
cp -a "$SOURCE_ROOT/SOURCE_MANIFEST.txt" .
mkdir -p scripts
cp -a "$SOURCE_ROOT/scripts/publish_to_master.sh" scripts/
git add README.md .gitignore rtl tests vectors docs SOURCE_MANIFEST.txt scripts/publish_to_master.sh
if git diff --cached --quiet; then
  echo 'No changes to publish.'
else
  git commit -m 'Integrate SQuARE SoC and SPARX mixed-precision RTL sources'
  git push origin master
fi
