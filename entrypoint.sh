#!/bin/bash
set -euo pipefail

# Deployer version
VERSION=1.0.1

## UI Constants
YELLOW=🟨
GREEN=🟩
BLUE=🟦
PURPLE=🟪
SUCCESS=✅
ERROR=❌

PLUGIN_FOLDER=${INPUT_PLUGIN_FOLDER:-}
EXCLUDE=${INPUT_EXCLUDE:-}
SLUG=${INPUT_SLUG:-}
SVN_USERNAME=${INPUT_USERNAME:-}
SVN_PASSWORD=${INPUT_PASSWORD:-}
TAG=${INPUT_TAG:-}
TAG=${TAG#v} # WordPress.org versions have no "v" prefix
ASSETS_FOLDER=${INPUT_ASSETS_FOLDER:-}
DRY_RUN=${INPUT_DRY_RUN:-}
COMMIT_MESSAGE=${INPUT_COMMIT_MESSAGE:-Plugin Update from GitHub actions}
WORKSPACE=${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is not set}

# DEPLOYER_FOLDER and DEPLOYER_SVN_URL are overridden only by the tests
DEPLOYER_FOLDER=${DEPLOYER_FOLDER:-/deployer}
EXCLUDE_FILE="$DEPLOYER_FOLDER/exclude.txt"
SVN_DIR="$DEPLOYER_FOLDER/plugins/$SLUG"
SVN_URL=${DEPLOYER_SVN_URL:-https://plugins.svn.wordpress.org/$SLUG/}

# logLine does an echo and attaches the timestamp as a prefix
logLine() {
    echo "[$(date "+%F %T")] $*"
}

fail() {
    logLine "$ERROR $*" >&2
    exit 1
}

# workspacePath resolves a repository folder to an absolute path with a trailing slash
workspacePath() {
    echo "$WORKSPACE/$1/" | tr -s /
}

# isPlugin checks that a folder contains a WordPress plugin
isPlugin() {
    [[ -f "$1/readme.txt" ]] || grep -qs "Plugin Name:" "$1"/*.php
}

# writeExcludeFile lists the paths that must never be published, plus the user ones
writeExcludeFile() {
    local entries entry
    printf '%s\n' .git .github .gitignore .env > "$EXCLUDE_FILE"
    IFS=',' read -ra entries <<< "${EXCLUDE//$'\n'/,}"
    for entry in "${entries[@]}"; do
        entry="${entry#"${entry%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"
        if [[ -n "$entry" ]]; then
            printf '%s\n' "$entry" >> "$EXCLUDE_FILE"
        fi
    done
}

# syncFolder mirrors a source folder into a SVN folder
syncFolder() {
    rsync -rc --exclude-from="$EXCLUDE_FILE" --delete --delete-excluded "$1" "$2"
}

# svnStage schedules new files for addition and missing files for deletion
svnStage() {
    local status line
    status=$(svn status)
    if grep -q '^~' <<< "$status"; then
        fail "A file was replaced by a folder (or the reverse); remove it from SVN manually first"
    fi
    # --no-ignore: the svn default ignores would silently drop files like *.so
    svn add . --force --no-ignore
    while IFS= read -r line; do
        if [[ "$line" == '!'* ]]; then
            # the trailing @ keeps names containing @ from being read as a revision
            svn rm --force -- "${line:8}@"
        fi
    done <<< "$status"
}

# simple_jwt_header_header displayes an ASCII code for Simple-JWT-Login Deployer
simple_jwt_header_header()
{
    # Generateed with https://patorjk.com/software/taag
    local COLOR='\033[1;33m' # Yellow
    local NC='\033[0m' # No Color
    echo -e "$COLOR"
    echo " _____ _                 _             ___  _    _ _____      _                 _       "
    echo "/  ___(_)               | |           |_  || |  | |_   _|    | |               (_)      "
    echo "\ \`--. _ _ __ ___  _ __ | | ___ ______  | || |  | | | |______| |     ___   __ _ _ _ __  "
    echo " \`--. \ | '_ \` _ \| '_ \| |/ _ \______| | || |/\| | | |______| |    / _ \ / _\` | | '\ "
    echo "/\__/ / | | | | | | |_) | |  __/    /\__/ /\  /\  / | |      | |___| (_) | (_| | | | | |"
    echo "\____/|_|_| |_| |_| .__/|_|\___|    \____/  \/  \/  \_/      \_____/\___/ \__, |_|_| |_|"
    echo "                  | |                                                      __/ |        "
    echo "                  |_|                                                     |___/         "
    echo -e "$NC"

    echo "  ____             _                       "
    echo " |  _ \  ___ _ __ | | ___  _   _  ___ _ __ "
    echo " | | | |/ _ \ '_ \| |/ _ \| | | |/ _ \ '__|"
    echo " | |_| |  __/ |_) | | (_) | |_| |  __/ |   "
    echo " |____/ \___| .__/|_|\___/ \__, |\___|_|   "
    echo "            |_|            |___/           "
    echo ""
    echo " Version: $VERSION"
    echo ""
}

simple_jwt_header_header

# Validate inputs
case "${DRY_RUN,,}" in
    true) DRY_RUN=true ;;
    false|"") DRY_RUN=false ;;
    *) fail "dry_run must be true, false or empty" ;;
esac
[[ "$SLUG" =~ ^[a-z0-9-]+$ ]] || fail "slug is missing or invalid: '$SLUG'"
if [[ -n "$TAG" && ! "$TAG" =~ ^[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$ ]]; then
    fail "tag is invalid: '$TAG' (expected a version like 1.2.3)"
fi
SOURCE=$(workspacePath "$PLUGIN_FOLDER")
isPlugin "$SOURCE" || fail "No plugin found in $SOURCE (readme.txt or a PHP file with a 'Plugin Name:' header)"

if [[ "$DRY_RUN" == true ]]; then
    logLine "$YELLOW RUNNING IN DRY RUN MODE"
else
    logLine "$GREEN RUNNING IN LIVE MODE"
    [[ -n "$SVN_USERNAME" ]] || fail "username is empty/not available"
    [[ -n "$SVN_PASSWORD" ]] || fail "password is empty/not available"
fi

mkdir -p "$SVN_DIR"
writeExcludeFile

logLine "$BLUE Checking out .org repository..."
svn checkout -q --non-interactive --depth immediates "$SVN_URL" "$SVN_DIR"
cd "$SVN_DIR"
svn update -q --non-interactive --set-depth infinity assets
svn update -q --non-interactive --set-depth infinity trunk
svn update -q --non-interactive --set-depth immediates tags
logLine "$GREEN svn checkout completed."

if [[ -n "$TAG" && -e "tags/$TAG" ]]; then
    fail "$SLUG version $TAG already exists"
fi

logLine "$BLUE Copying files from $SOURCE to trunk/ ..."
syncFolder "$SOURCE" trunk/
logLine "$GREEN rsync for trunk/ completed"

if [[ -n "$ASSETS_FOLDER" ]]; then
    ASSETS_SOURCE=$(workspacePath "$ASSETS_FOLDER")
    if [[ -d "$ASSETS_SOURCE" && -n "$(ls -A "$ASSETS_SOURCE")" ]]; then
        logLine "$BLUE Syncing assets directory $ASSETS_SOURCE to assets/ ..."
        syncFolder "$ASSETS_SOURCE" assets/
    else
        logLine "$YELLOW $ASSETS_SOURCE is missing or empty; skipping asset copy"
    fi
fi

logLine "$BLUE Staging changes ..."
svnStage

if [[ -n "$TAG" ]]; then
    logLine "$BLUE Copying trunk to tags/$TAG ..."
    svn cp trunk "tags/$TAG"
fi

logLine "$PURPLE List trunk content"
find trunk

logLine "$PURPLE Running svn status:"
svn status

logLine "$PURPLE Running svn diff ..."
svn diff

if [[ "$DRY_RUN" == true ]]; then
    logLine "$BLUE Dry run: Files not committed."
    exit 0
fi

logLine "$BLUE Committing files..."
printf '%s' "$SVN_PASSWORD" | svn commit -m "$COMMIT_MESSAGE" --no-auth-cache --non-interactive \
    --username "$SVN_USERNAME" --password-from-stdin
logLine "$SUCCESS Plugin deployed to wordpress.org!"
