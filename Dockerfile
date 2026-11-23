# Container image that runs your code
FROM debian:12.9-slim

RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get install -y ca-certificates subversion rsync \
    && rm -rf /var/lib/apt/lists/*

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Docker actions must run as root:
# https://docs.github.com/en/actions/sharing-automations/creating-actions/dockerfile-support-for-github-actions#user

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
