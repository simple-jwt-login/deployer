#!/bin/bash -l

# logLine does an echo and attaches the timestap as a prefix
logLine() {
    echo "["$(date "+%F %T")"] $@"
}

trim() {
    local input=$1

    # Trim leading and trailing spaces
    local result=$(echo $input | xargs)
    
    if [[ "$input" == /* ]];then
        # remove leading slash
        input="${input:1}"
    fi

     # Remove trailing slash
    input="${input%/}"

    echo $input
}

escapePath() {
    local input=$1
    echo $input | sed 's/\/\//\//g'
}

# Deployer version
VERSION=0.1.0

# Init variables from args
PLUGIN_FOLDER=$INPUT_PLUGIN_FOLDER
EXCLUDE=$INPUT_EXCLUDE
SLUG=$INPUT_SLUG
SVN_USERNAME=$INPUT_USERNAME
SVN_PASSWORD=$INPUT_PASSWORD
TAG=$INPUT_TAG
ASSETS_FOLDER=$INPUT_ASSETS_FOLDER
DRY_RUN=$INPUT_DRY_RUN
COMMIT_MESSAGE="Plugin Update from GitHub actions"
if [ ! -z "$INPUT_COMMIT_MESSAGE"]; then
    COMMIT_MESSAGE=$INPUT_COMMIT_MESSAGE
fi

## Init default values
if [ -z "$PLUGIN_FOLDER" ]; then
    PLUGIN_FOLDER=""
fi


DEPLOYER_FOLDER="/deployer"
EXCLUDE_FILE="$DEPLOYER_FOLDER/exclude.txt"

# Create the exclude file and exlude .git and .github
echo -e ".git/\n.github/\n" > "$EXCLUDE_FILE"

# Add excluded files 
if [ -z "$EXCLUDE" ]; then
    echo ".gitignore" >> "$EXCLUDE_FILE"
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

SVN_DIR="$DEPLOYER_FOLDER/plugins/${SLUG}"
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

# Reset all changes in the SVN directory
logLine "$BLUE Reseting SVN folder..."
svn revert -R .
svn cleanup
logLine "$GREEN SVN folder is clean."

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


folder=$(escapePath "$GITHUB_WORKSPACE/$(trim $PLUGIN_FOLDER)/")
logLine "$BLUE Copying files from $folder directory to  trunk/..."
rsync -rc --exclude-from=$EXCLUDE_FILE $folder trunk/ --delete --delete-excluded --ignore-errors
logLine "$GREEN rsync for trunk/ completed"

echo "assets folder: $ASSETS_FOLDER"
if [ ! -z  "$ASSETS_FOLDER" ];then
    logLine "$BLUE Assets folder provided"
    # If ASSETS_FOLDER is not null, copy all files to /assets
    if [[ -d "/app/$(trim $ASSETS_FOLDER)/" ]]; then
        folder=$(escapePath "$GITHUB_WORKSPACE/$(trim $ASSETS_FOLDER)/")
        logLine "$BLUE Syncing assets directory $folder to assets/ ..."
        rsync -rc --exclude-from=$EXCLUDE_FILE $folder assets/ --delete --delete-excluded --ignore-errors
    else
        logLine "$YELLOW No assets directory found; skipping asset copy"
    fi
fi;

# Check if the tag already exist
if [ ! -z $TAG ]; then
    if [[ -d "tags/$TAG" ]]; then
        logLine "$ORANGE Warning: $SLUG plugin version $TAG already exists.";
    fi
    logLine "$BLUE Copying trunk to tags/$TAG ..."
    svn cp "trunk" "tags/$TAG"

    logLine "$PURPLE list tags/$TAG folder:"
    tree -a tags/$TAG
    
    logLine "$GREEN tags/$TAG created."
fi

logLine "$BLUE list trunk content"
tree -a trunk/

logLine "$BLUE list tag folder"
ls -la tags/

logLine "$PURPLE Running svn status:"
svn status

logLine "$BLUE Preparing files with svn add ..."
svn add . --force
logLine "$GREEN Files added successfully."

logLine "$PURPLE Running svn diff ..."
svn diff

if [ -z "$DRY_RUN" ]; then
    logLine "$BLUE Committing files..."
    svn commit -m "$COMMIT_MESSAGE" --no-auth-cache --non-interactive  --username "$SVN_USERNAME" --password "$SVN_PASSWORD"
    
    echo ""
    echo ""
    logLine "$SUCCESS Plugin deployed to wordpress.org!"
else 
    echo ""
    echo ""
    logLine "$BLUE Dry run: Files not committed."
    logLine "$SUCCESS Done."
    exit 0;
fi;
