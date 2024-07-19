#!/bin/bash
#
# Fetch docker compose and env files from 
# https://github.com/jitsi/docker-jitsi-meet
#

set -euo pipefail

usage() {
    echo "Usage: $0 [--no-branding] <version>"
    echo "          <version> - Jitsi-docker release version to generate config for."
    echo "                      Either a release version like 'stable-9584-1'"
    echo "                      or 'latest' for latest development master branch."
    echo "                      See https://github.com/jitsi/docker-jitsi-meet/releases"
    echo "                      for avilable versions."
    echo "          --no-branding Don't use Flatcar branding."
    echo
}

if [ $# -lt 1 ] ; then
    usage
    exit 1
fi

no_branding="false"
if [ "$1" = "--no-branding" ] ; then
    no_branding="true"
    shift
fi

if [ $# -ne 1 ] ; then
    usage
    exit 1
fi

# Get docker compose yaml, default env, and related config files from
# jitsi-docker.
version="$1"
base_url=""
files_list=( "docker-compose.yml" "env.example" "gen-passwords.sh" "jibri.yml" )

if [ "$version" = "latest" ] ; then
    base_url="https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master"
else
    base_url="https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/${version}"
fi

echo "Fetching config files for '${version}'"
echo "${version}" > JITSI_VERSION

for file in "${files_list[@]}"; do
    echo -n "  ${file}: "
    curl -s "${base_url}/${file}" > "${file}"
    echo "OK"
done

if [ "$no_branding" = "false" ] ; then
	echo "Applying branding patch"
	git apply "resources/branding-docker-compose.yml.patch"
fi

echo "Generating Ignition config"
cat config.yaml \
    | docker run --rm -i -v "$(pwd):/files" \
            quay.io/coreos/butane:latest --files-dir /files \
      > ignition.json

echo "All done. Configuration available at 'ignition.json'."
