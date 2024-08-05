#!/bin/bash
# Flatcar Jitsi server installer
# 
# Copyright (c) 2021 The Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license that can be
# found in the LICENSE file.

set -euo pipefail

INSTALLER_DIR="$(cd $(dirname ${BASH_SOURCE[0]}); pwd)"
DEST_DIR="/opt/jitsi"
if [ -f "${DEST_DIR}/.installation-complete" ] ; then
    exit 0
fi

# ---- Source user settings and set defaults
source "$INSTALLER_DIR/jitsi-install.env"

MODERATOR_USER="${MODERATOR_USER:-flatcar}"
MODERATOR_PASS="${MODERATOR_PASS:-$(openssl rand -hex 16)}"
DEPLOY_SET_PUBLIC_IP="${DEPLOY_SET_PUBLIC_IP:-}"
DEPLOY_WAIT_FOR_HOSTNAME_DNS="${DEPLOY_WAIT_FOR_HOSTNAME_DNS:-}"
# --

JITSI_VERSION="$(cat "${INSTALLER_DIR}/JITSI_VERSION")"
JITSI_STATE_DIR="${DEST_DIR}/__jitsi_state__"

if [ "$DEPLOY_SET_PUBLIC_IP" = "false" ] ; then
	DEPLOY_SET_PUBLIC_IP=""
fi

# ---- Determine and set public IP, wait for DNS

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

if [ -n "$DEPLOY_SET_PUBLIC_IP" ] ; then
    if [ "$DEPLOY_SET_PUBLIC_IP" = "true" ] ; then
        DEPLOY_SET_PUBLIC_IP="$(get_public_ip)"
    fi
    echo "[DEPLOY] My IP is '$DEPLOY_SET_PUBLIC_IP'"

    if [ "$DEPLOY_WAIT_FOR_HOSTNAME_DNS" = "true" ] ; then
    (
        source "${INSTALLER_DIR}/jitsi-config.env"
        echo "[DEPLOY] Waiting for '$JITSI_SERVER_FQDN' to resolve to '$DEPLOY_SET_PUBLIC_IP'"
        wait_for_dns "$DEPLOY_SET_PUBLIC_IP" "$JITSI_SERVER_FQDN"
        echo "[DEPLOY] '$JITSI_SERVER_FQDN' points to '$DEPLOY_SET_PUBLIC_IP'"
    )
    fi
fi
# --

# ---- Create destination, copy resources and env
#
mkdir -p "${DEST_DIR}"
mkdir -p "${JITSI_STATE_DIR}"/{web,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

# Copy branding things
cp "${INSTALLER_DIR}/flatcar_logo-vertical-stacked-black.svg" \
   "${INSTALLER_DIR}/flatcar_logo-vertical-stacked.svg" \
   "${INSTALLER_DIR}/flatcar_banner.png" \
   "${JITSI_STATE_DIR}"/

# Copy custom config snippet
cp "${INSTALLER_DIR}/custom-interface_config.js" "${JITSI_STATE_DIR}"/web/

# copy docker-compose files and helper scripts
cp "${INSTALLER_DIR}/env.example" \
   "${INSTALLER_DIR}/docker-compose.yml" \
   "${INSTALLER_DIR}/jibri.yml" \
   "${INSTALLER_DIR}/gen-passwords.sh" \
   "${DEST_DIR}"/

cd "${DEST_DIR}"

mv env.example .env
./gen-passwords.sh
sed -i "s,^CONFIG=.*,CONFIG=${JITSI_STATE_DIR}," .env

cat "${INSTALLER_DIR}/jitsi-config.env" >> .env
echo "JITSI_IMAGE_VERSION=${JITSI_VERSION}" >> .env

if [ -n "$DEPLOY_SET_PUBLIC_IP" ] ; then
    echo "JVB_ADVERTISE_IPS=${DEPLOY_SET_PUBLIC_IP}" >> .env
fi

# Start the services temporatily so we can create the moderator user
docker compose -f docker-compose.yml -f jibri.yml up -d --wait
sleep 5

docker compose exec prosody /usr/bin/prosodyctl \
               --config /config/prosody.cfg.lua \
               register "${MODERATOR_USER}" meet.jitsi "${MODERATOR_PASS}"

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

echo "$(date)" > "${DEST_DIR}/.installation-complete"
