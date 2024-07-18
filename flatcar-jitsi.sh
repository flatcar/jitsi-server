#!/bin/bash
# Flatcar Jitsi server installer
# 
# Copyright (c) 2021 The Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license that can be
# found in the LICENSE file.

set -euo pipefail

# --------
# User provisioning settings
DEPLOY_SET_PUBLIC_IP="true"
DEPLOY_WAIT_FOR_HOSTNAME_DNS="true"
# --------

function get_public_ip() {
    curl -s http://ip6.me/api/ \
        | grep -E '^IPv4,' | awk -F, '{print $2}'
}
# --

function wait_for_dns() {
    local ip="$1"
    local hostname="$2"

    while true; do
        local host_ip
        for host_ip in $(host -t A "$hostname"  \
                    | sed -n 's/.*has address \([0-9.:]\+\)$/\1/p'); do
            echo "[DEPLOY]   Found '$host_ip' for '$hostname' (looking for '$ip')"
            if [ "$host_ip" = "$ip" ] ; then
                break
            fi
        done
        if [ "$host_ip" = "$ip" ] ; then
            break
        fi
        sleep 1
    done
}
# --

SCRIPT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}); pwd)"
RSRC_DIR="${SCRIPT_DIR}/resources"

if [ -n "$DEPLOY_SET_PUBLIC_IP" ] ; then
    if [ "$DEPLOY_SET_PUBLIC_IP" = "true" ] ; then
        DEPLOY_SET_PUBLIC_IP="$(get_public_ip)"
    fi
    echo "[DEPLOY] My IP is '$DEPLOY_SET_PUBLIC_IP'"

    if [ "$DEPLOY_WAIT_FOR_HOSTNAME_DNS" = "true" ] ; then
    (
        source "${RSRC_DIR}/flatcar.env"
        echo "[DEPLOY] Waiting for '$JITSI_SERVER_FQDN' to resolve to '$DEPLOY_SET_PUBLIC_IP'"
        wait_for_dns "$DEPLOY_SET_PUBLIC_IP" "$JITSI_SERVER_FQDN"
        echo "[DEPLOY] '$JITSI_SERVER_FQDN' points to '$DEPLOY_SET_PUBLIC_IP'"
    )
    fi
fi

MODERATOR_USER=flatcar
MODERATOR_PASS=$(openssl rand -hex 16)

DEST_DIR=~/jitsi-docker


# Use a release version / tag from https://github.com/jitsi/docker-jitsi-meet
#  otherwise the unstable nightly docker images will be used
JITSI_VERSION="${JITSI_VERSION:-stable-9584-1}"

mkdir -p "${DEST_DIR}"
cd ${DEST_DIR}

git clone https://github.com/jitsi/docker-jitsi-meet.git .
git checkout "${JITSI_VERSION}"

mkdir -p __jitsi_docker_config__/{web,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

# Copy branding things
cp "${RSRC_DIR}/flatcar_logo-vertical-stacked-black.svg" \
   "${RSRC_DIR}/flatcar_logo-vertical-stacked.svg" \
   "${RSRC_DIR}/flatcar_banner.png" \
   __jitsi_docker_config__/

# Apply patch to mount above files into web container
git apply "${RSRC_DIR}/branding-docker-compose.yml.patch"

# Copy custom config snippet
cp "${RSRC_DIR}/custom-interface_config.js" __jitsi_docker_config__/web/

cp env.example .env
./gen-passwords.sh
sed -i 's/^HTTP_PORT.*/HTTP_PORT=80/' .env
sed -i 's/^HTTPS_PORT.*/HTTPS_PORT=443/' .env
sed -i "s,^CONFIG=.*,CONFIG=${DEST_DIR}/__jitsi_docker_config__," .env

cat "${RSRC_DIR}/flatcar.env" >> .env

# add to .env to ease upgrade once deployed
echo "JITSI_IMAGE_VERSION=${JITSI_VERSION}" >> .env

if [ -n "$DEPLOY_SET_PUBLIC_IP" ] ; then
    echo "JVB_ADVERTISE_IPS=${DEPLOY_SET_PUBLIC_IP}" >> .env
fi

# Start the services temporatily so we can create the moderator user
docker compose -f docker-compose.yml -f jibri.yml up -d
sleep 2

docker compose exec prosody /usr/bin/prosodyctl --config /config/prosody.cfg.lua register "${MODERATOR_USER}" meet.jitsi "${MODERATOR_PASS}"

docker compose -f docker-compose.yml -f jibri.yml down

cat >>.env<<EOF
#
# Moderator user
# username: ${MODERATOR_USER}
# password: ${MODERATOR_PASS}
EOF

echo "==========================================================="
echo "All done."
echo
echo "Moderator account:"
echo "username: '${MODERATOR_USER}'"
echo "password: '${MODERATOR_PASS}'"

