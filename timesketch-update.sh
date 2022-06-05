#!/bin/bash

# This script downloads a couple of configuration files and a sigma blocklist
# file and then updates the Timesketch install to run a newer version. The
# main reason for the new version is to fix bugs with applying comments, stars,
# and labels.

# Exit early if run as non-root user.
if [ "$EUID" -ne 0 ]; then
	echo "ERROR: This script needs to run as root (sudo ./timesketch-update.sh)."
  exit 1
fi

# Exit early if there are Timesketch containers already running.
if [ ! -z "$(docker ps | grep timesketch)" ]; then
  echo "ERROR: Timesketch containers are running. Shutdown the stack by changing directories to /opt/timesketch and running 'docker-compose down' before proceeding."
  exit 1
fi

TIMESTAMP=$(date --utc +'%Y%m%dt%H%M%S')

echo "Updating /opt/timesketch/docker-compose.yml"
mv /opt/timesketch/docker-compose.yml /opt/timesketch/docker-compose_$TIMESTAMP.yml.bak
wget -q https://github.com/mpilking/for608-public/raw/H01/docker-compose.yml -O /opt/timesketch/docker-compose.yml

echo "Updating /opt/timesketch/etc/timesketch/timesketch.conf"
mv /opt/timesketch/etc/timesketch/timesketch.conf /opt/timesketch/etc/timesketch/timesketch_$TIMESTAMP.conf.bak
wget -q https://github.com/mpilking/for608-public/raw/H01/timesketch.conf -O /opt/timesketch/etc/timesketch/timesketch.conf

echo "Adding required sigma blocklist file"
wget -q https://github.com/mpilking/for608-public/raw/H01/sigma_blocklist.csv -O /opt/timesketch/etc/timesketch/sigma_blocklist.csv

echo "Adding ATT&CK tagger file"
mv /opt/timesketch/etc/timesketch/tags.yaml /opt/timesketch/etc/timesketch/tags_$TIMESTAMP.yaml
wget -q https://raw.githubusercontent.com/blueteam0ps/AllthingsTimesketch/master/tags.yaml -O /opt/timesketch/etc/timesketch/tags.yaml

echo "Updated files are now in place. Start the stack by changing directories to /opt/timesketch and running 'docker-compose up -d' as standard 'sansforensics' user."

