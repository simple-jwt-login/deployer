#!/bin/bash
# Runs entrypoint.sh against throwaway local SVN repositories.
set -euo pipefail

ENTRYPOINT="$(cd "$(dirname "$0")/.." && pwd)/entrypoint.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
CASE=0

# setup creates a repository holding a released plugin, and a workspace with the next version
setup() {
    CASE=$((CASE + 1))
    BASE="$ROOT/$CASE"
    URL="file://$BASE/repo"
    WS="$BASE/my workspace"
    mkdir -p "$BASE/seed/trunk/old dir" "$BASE/seed/tags/1.0" "$BASE/seed/assets" "$WS/plugin/sub"
    touch "$BASE/seed/trunk/"{readme.txt,gone.php,gone@2x.png,"old dir/x y.php"} "$BASE/seed/tags/1.0/readme.txt"
    svnadmin create "$BASE/repo"
    svn import -q --no-ignore -m seed "$BASE/seed" "$URL"
    touch "$WS/plugin/"{new.php,new@2x.png,lib.so,.env,doc.md,sub/doc.md,sub/ok.php}
    echo v2 > "$WS/plugin/readme.txt"
}

# deploy runs the entrypoint with the given extra variables
deploy() {
    env GITHUB_WORKSPACE="$WS" DEPLOYER_FOLDER="$BASE/deployer" DEPLOYER_SVN_URL="$URL" \
        INPUT_SLUG=demo INPUT_PLUGIN_FOLDER=/plugin/ INPUT_USERNAME=u INPUT_PASSWORD=p "$@" \
        "$ENTRYPOINT" > "$BASE/log" 2>&1
}

die() { echo "FAIL: $*"; cat "$BASE/log"; exit 1; }
tree_of() { svn ls -R "$URL/$1"; }
revision() { svnlook youngest "$BASE/repo"; }
expect_reject() {
    local name=$1 reason=$2
    shift 2
    if deploy "$@"; then die "$name: expected a failure"; fi
    [[ $(revision) == 1 ]] || die "$name: repository was changed"
    if grep -q "Plugin deployed" "$BASE/log"; then die "$name: reported success"; fi
    grep -q "$reason" "$BASE/log" || die "$name: wrong failure reason"
    echo "ok: $name"
}

EXPECTED=$(printf '%s\n' lib.so new.php new@2x.png readme.txt sub/ sub/ok.php | LC_ALL=C sort)

setup
mkdir "$WS/img"; touch "$WS/img/icon.png"
deploy INPUT_TAG=v2.0 INPUT_EXCLUDE=" .gitignore, *.md " INPUT_DRY_RUN=false INPUT_ASSETS_FOLDER=/img || die "release"
for dir in trunk tags/2.0; do
    [[ $(tree_of "$dir" | LC_ALL=C sort) == "$EXPECTED" ]] || die "release: unexpected $dir: $(tree_of "$dir")"
done
[[ $(tree_of assets) == icon.png ]] || die "release: assets not synced"
[[ $(tree_of tags/1.0) == readme.txt ]] || die "release: old tag changed"
echo "ok: release"

setup
deploy INPUT_DRY_RUN=true INPUT_USERNAME= INPUT_PASSWORD= || die "dry run"
[[ $(revision) == 1 ]] || die "dry run committed"
echo "ok: dry run"

setup
deploy || die "no tag, nothing optional"
[[ $(revision) == 2 ]] || die "empty dry_run did not commit"
deploy DEPLOYER_FOLDER="$BASE/again" || die "unchanged redeploy"
[[ $(revision) == 2 ]] || die "unchanged redeploy committed"
echo "ok: live without optional inputs, unchanged redeploy"

setup
expect_reject "existing tag" "already exists" INPUT_TAG=1.0
expect_reject "bad dry_run" "dry_run must be" INPUT_DRY_RUN=maybe
expect_reject "bad tag" "tag is invalid" INPUT_TAG=../trunk
expect_reject "bad slug" "slug is missing" INPUT_SLUG=../x
expect_reject "no password" "password is empty" INPUT_PASSWORD=
expect_reject "missing folder" "No plugin found" INPUT_PLUGIN_FOLDER=nope

setup
rm -r "$WS/plugin"; mkdir "$WS/plugin"
expect_reject "empty folder" "No plugin found"

setup
rm -rf "$WS/plugin/readme.txt"; mkdir "$WS/plugin/gone.php"; echo "Plugin Name: x" > "$WS/plugin/new.php"
expect_reject "file replaced by folder" "replaced by a folder"

setup
printf '#!/bin/sh\nexit 1\n' > "$BASE/repo/hooks/pre-commit"; chmod +x "$BASE/repo/hooks/pre-commit"
expect_reject "rejected commit" "Commit blocked"

setup
expect_reject "checkout failure" "Unable to connect\|E[0-9]*:" DEPLOYER_SVN_URL="file://$BASE/none"

echo "All tests passed"
