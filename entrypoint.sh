#!/bin/bash -l

# Deployer version
VERSION=0.1.0

# Init variables from args
FOLDER=$1
EXCLUDE=$2
SLUG=$3
SVN_USERNAME=$4
SVN_PASSWORD=$5
TAG=$6
ASSETS_FOLDER=$7
DRY_RUN=$8

EXCLUDE_FILE="/exclude.txt"


# Validate number of arguments
if [ $# -lt 7 ]; then
    logLine "$ERROR Missing arguments"
    exit 1
fi;

# Create the exclude file
touch "$EXCLUDE_FILE"

# Add excluded files 
if [ -z "$EXCLUDE" ]; then
    echo ".gitignore" > "$EXCLUDE_FILE"
else
    array=(`echo $EXCLUDE | sed 's/,/\n/g'`)
    for i in "${!array[@]}"
    do
        echo ${array[i]} >> "$EXCLUDE_FILE"
    done
fi;

## UI Constants
RED=🟥
ORANGE=🟧
YELLOW=🟨
GREEN=🟩
BLUE=🟦
PURPLE=🟪
SUCCESS=✅
ERROR=❌

# logLine does an echo and attaches the timestap as a prefix. Accepts one argument
logLine() {
    echo "["$(date "+%F %T")"] $1"
}

# simple_jwt_header_header displayes an ASCII code for Simple-JWT-Login Deployer
simple_jwt_header_header()
{
    # Generateed with https://patorjk.com/software/taag
    COLOR='\033[1;33m' # Yellow
    NC='\033[0m' # No Color
    echo -e "$COLOR"
    echo " _____ _                 _             ___  _    _ _____      _                 _       "
    echo "/  ___(_)               | |           |_  || |  | |_   _|    | |               (_)      "
    echo "\ \`--. _ _ __ ___  _ __ | | ___ ______  | || |  | | | |______| |     ___   __ _ _ _ __  "
    echo " \`--. \ | '_ \` _ \| '_ \| |/ _ \______| | || |/\| | | |______| |    / _ \ / _\` | | '_ \ "
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

if [ -z "$DRY_RUN" ]; then
    logLine "$GREEN RUNNIING IN LIVE MODE"
else 
    logLine "$YELLOW RUNNING IN DRY RUN MODE"
fi;

SVN_DIR="${HOME}/SVN/plugins/${SLUG}"
SVN_URL="https://plugins.svn.wordpress.org/${SLUG}/"

# make sure the directory exists
mkdir -p $SVN_DIR

# diplay header to make pipeline cooler
simple_jwt_header_header

# Clone the svn repository
logLine "$BLUE Checking out .org repository..."
svn checkout --depth immediates "$SVN_URL" "$SVN_DIR"
logLine "$GREEN svn choukout completed."

# Go to svn plugin
cd "$SVN_DIR"

# Update SVN R
logLine "$BLUE updating svn repository..."
svn update --set-depth infinity assets
svn update --set-depth infinity trunk
svn update --set-depth immediates tags
logLine "$GREEN svn update completed."

## Debugging
logLine "$PURPLE List $SVN_DIR/trunk ..."
ls -la $SVN_DIR/trunk

logLine "$PURPLE List $SVN_DIR/tags ..."
ls -d $SVN_DIR/tags

# Check if the tag already exist
if [[ -d "tags/$VERSION" ]]; then
    logLine "$ERROR $SLUG plugin version $TAG already exists. Exiting...";
    exit 1
fi

logLine "$BLUE Copying files from build directory to  trunk..."
rsync -rc --exclude-from=$EXCLUDE_FILE "/app/$FOLDER" trunk/ --delete --delete-excluded
logLine "$GREEN rsync for trunk/ completed"


# If ASSETS_FOLDER is not null, copy all files to /assets
if [[ -d "$GITHUB_WORKSPACE/$ASSETS_FOLDER/" ]]; then
    logLine "$BLUE Syncing assets directory..."
	rsync -rc "$GITHUB_WORKSPACE/$ASSETS_FOLDER/" assets/ --delete
else
	logLine "$YELLOW No assets directory found; skipping asset copy"
fi

logLine "$BLUE Copying trunk to tags/$TAG ..."
svn cp "trunk" "tags/$TAG"
logLine "$GREEN tags/$TAG created."

logLine "$PURPLE SVN status:"
svn status


if [ -z "$DRY_RUN" ]; then
    logLine "$BLUE Preparing files with svn add ..."
    svn add . --force > /dev/null
    svn add .
    logLine "$GREEN Files added successfully."
    
    logLine "$BLUE Committing files..."
    svn commit -m "Update to version $TAG from GitHub actions" --no-auth-cache --non-interactive  --username "$SVN_USERNAME" --password "$SVN_PASSWORD"
    
    echo ""
    echo ""
    logLine "$SUCCESS Plugin deployed to wordpress.org!"
else 
    logLine "$PURPLE Running svn diff ..."
    svn diff
    
    logLine "$PURPLE Running svn status ..."
    svn status

    logLine "$PURPLE Running svn add ..."
    svn add .

    logLine "$PURPLE Running svn status ..."
    svn status

    echo ""
    echo ""
    logLine "$BLUE Dry run: Files not committed."
    logLine "$SUCCESS Done."
    exit 0;
fi;
