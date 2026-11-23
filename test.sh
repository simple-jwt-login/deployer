#!/bin/bash

# This is solely for testing purposes
# to replicate the GitHub Actions environment locally.
# Usage: ./test.sh /path/to/repository
set -euo pipefail

cd "$(dirname "$0")"
REPOSITORY=$(realpath "${1:?Usage: ./test.sh /path/to/repository}")

docker build -t deployer:v1 .

docker run --rm --env-file .env -e GITHUB_WORKSPACE=/app -v "$REPOSITORY:/app:ro" deployer:v1
