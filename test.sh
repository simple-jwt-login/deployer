#!/bin/bash

# This is solely for testing purposes
# to replicate the GitHub Actions environment locally

source .env

docker build -t deployer:v1 .

docker run --env-file .env deployer:v1