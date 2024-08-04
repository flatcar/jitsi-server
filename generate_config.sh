#!/bin/bash
#
# Fetch docker compose and env files from 
# https://github.com/jitsi/docker-jitsi-meet
#

set -euo pipefail

arch="x86-64"
branding="true"
version=""

usage() {
    echo "Usage: $0 [--no-branding] [--arch <x86-64|arm64>] <version>"
    echo "          <version>     Jitsi-docker release version to generate config for."
    echo "                        Either a release version like 'stable-9584-1'"
    echo "                        or 'latest' for latest development master branch."
    echo "                        See https://github.com/jitsi/docker-jitsi-meet/releases"
    echo "                        for available versions."
    echo "                        This argument is required."
    echo "          --arch <arch> Generate config for this architecture. Must be"
    echo "                        'x86-64' or 'arm64' if provided."
    echo "                        Defaults to 'x86-64'."
    echo "          --no-branding Don't use Flatcar branding."
    echo
}

while [ $# -gt 0 ] ; do
    case "$1" in
        --no-branding) branding="false";;
        --arch) if [ "$2" != "x86-64" -a "$2" != "arm64" ] ; then
                    echo "Unsupported arch '$2'."
                    echo "Arch must be 'x86-64' or 'arm64'."
                    exit 1
                fi
                arch="$2"
                shift;;
        -h) usage; exit;;
        --help) usage; exit;;
        *) version="$1"
    esac
    shift
done

if [ -z "${version}" ] ; then
    usage
    exit 1
fi


# Get docker compose yaml, default env, and related config files from
# jitsi-docker.
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
    curl -fsSL "${base_url}/${file}" --remote-name
    echo "OK"
done

if [ "$branding" = "true" ] ; then
	echo "Applying branding patch"
	git apply "resources/branding-docker-compose.yml.patch"
fi

echo "Generating Ignition config"

sed "s/@ARCH@/${arch}/g" config.yaml.tmpl \
    > config.yaml

cat config.yaml \
    | docker run --rm -i -v "$(pwd):/files" \
            quay.io/coreos/butane:latest --files-dir /files \
      > ignition.json

echo "All done. Configuration available at 'ignition.json'."
