#!/bin/bash
# Publish a release of gh-accounts and update the Homebrew tap.
#
#   scripts/release.sh 1.0.0
#
# First run creates both public repos (OWNER/gh-accounts and OWNER/homebrew-tap).
# Later runs bump VERSION, tag, release and update the formula.
set -euo pipefail

V="${1:?Usage: scripts/release.sh <version>  (e.g. 1.0.0)}"
OWNER="${OWNER:-aiherrera}"
REPO="gh-accounts"
TAP="homebrew-tap"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESC="Per-client GitHub accounts on macOS: gh, git, SSH and GPG auto-selected by folder, with rules for AI agents"

# Always publish as OWNER, whatever folder this runs from
export GH_TOKEN="$(gh auth token --user "$OWNER")"
[ "$(gh api user -q .login)" = "$OWNER" ] || { echo "gh is not authenticated as $OWNER" >&2; exit 1; }

cd "$ROOT"
sed -i '' "s/^VERSION=.*/VERSION=\"$V\"/" gh-accounts
chmod +x gh-accounts scripts/release.sh

# --- main repo ---
[ -d .git ] || git init -q -b main
git add -A
git diff --cached --quiet || git commit -q -m "chore: release v$V"

if gh api "repos/$OWNER/$REPO" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "git@github.com:$OWNER/$REPO.git"
  git push -q origin HEAD:main
else
  gh repo create "$OWNER/$REPO" --public --description "$DESC" --source . --remote origin --push
  gh api -X PUT "repos/$OWNER/$REPO/topics" -f 'names[]=gh-extension' -f 'names[]=homebrew' \
    -f 'names[]=github-cli' -f 'names[]=git' -f 'names[]=ai-agents' >/dev/null
fi

git tag -f "v$V" >/dev/null
git push -q -f origin "v$V"
gh release view "v$V" -R "$OWNER/$REPO" >/dev/null 2>&1 \
  || gh release create "v$V" -R "$OWNER/$REPO" --title "v$V" --generate-notes

SHA="$(curl -fsSL "https://github.com/$OWNER/$REPO/archive/refs/tags/v$V.tar.gz" | shasum -a 256 | cut -d' ' -f1)"
echo "sha256: $SHA"

# --- tap repo ---
WORK="$(mktemp -d)"
if gh api "repos/$OWNER/$TAP" >/dev/null 2>&1; then
  git clone -q "git@github.com:$OWNER/$TAP.git" "$WORK/tap"
  NEW_TAP=0
else
  mkdir -p "$WORK/tap"; git -C "$WORK/tap" init -q -b main
  printf '# %s/homebrew-tap\n\nHomebrew formulae by %s.\n\n```bash\nbrew install %s/tap/gh-accounts\n```\n' \
    "$OWNER" "$OWNER" "$OWNER" > "$WORK/tap/README.md"
  NEW_TAP=1
fi
mkdir -p "$WORK/tap/Formula"
sed -e "s/__OWNER__/$OWNER/g" -e "s/__VERSION__/$V/g" -e "s/__SHA256__/$SHA/g" \
  packaging/gh-accounts.rb.tmpl > "$WORK/tap/Formula/gh-accounts.rb"
git -C "$WORK/tap" add -A
git -C "$WORK/tap" diff --cached --quiet || git -C "$WORK/tap" commit -q -m "gh-accounts $V"
if [ "$NEW_TAP" -eq 1 ]; then
  (cd "$WORK/tap" && gh repo create "$OWNER/$TAP" --public --description "Homebrew formulae by $OWNER" --source . --remote origin --push)
else
  git -C "$WORK/tap" push -q origin HEAD:main
fi
rm -rf "$WORK"

echo
echo "Released v$V"
echo "  brew:  brew install $OWNER/tap/gh-accounts   (upgrade: brew update && brew upgrade gh-accounts)"
echo "  gh:    gh extension install $OWNER/gh-accounts (upgrade: gh extension upgrade accounts)"
