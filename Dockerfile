# Container image that runs your code
FROM debian:12.9-slim 
# https://docs.github.com/en/actions/sharing-automations/creating-actions/dockerfile-support-for-github-actions#from

RUN apt-get -y update && apt-get -y upgrade

RUN  apt-get install -y  --reinstall ca-certificates

WORKDIR /app

# INSTALL SVN
RUN apt-get install -y \
    subversion \
    rsync

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Create a new user
RUN useradd -u 1000 www

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]