#!/bin/bash
#
# Fetch docker compose and env files from 
# https://github.com/jitsi/docker-jitsi-meet
#

set -euo pipefail

if [ $# -ne 1 ] ; then
    echo "Usage: $0 <version>"
    echo "          <version> - Jitsi-docker release version to pull files for."
    echo "                      Either a release version like 'stable-9584-1'"
    echo "                      or 'latest' for latest development imaster branch."
    echo "                      See https://github.com/jitsi/docker-jitsi-meet/releases"
    echo "                      for avilable versions."
    echo
    exit 1
fi

version="$1"
base_url=""
files_list=( "docker-compose.yml" "env.example" "gen-passwords.sh" "jibri.yml" )

if [ "$version" = "latest" ] ; then
    base_url="https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master"
else
    base_url="https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/${version}"
fi

echo "Fetching files for '${version}'"

for file in "${files_list[@]}"; do
    echo -n "  ${file}: "
    curl -s "${base_url}/${file}" > "${file}"
    echo "OK"
done
