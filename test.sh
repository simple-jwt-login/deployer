#!/bin/bash

# This is solely for testing purposes
# to replicate the GitHub Actions environment locally

source .env

docker build -t deployer .

docker run --env-file .env deployer