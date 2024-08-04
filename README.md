# jitsi-server

The Flatcar Jitsi server. Uses https://github.com/jitsi/docker-jitsi-meet.

# Features
- A full-blown Jitsi server, stateless, deploy when you need it (and remove it afterwards)
- Jibri integration for server-side recording and live streaming
- LetsEncrypt integration for serving HTTPS from your Jitsi host
- Very minimal configuration requirements:
  - A host to provision Flatcar to with the `ignition.json` generated from this repo
  - hostname DNS entry and email address (for LetsEncrypt HTTPS cert)

- Provisioning can be tested in a local qemu VM.

# Installation

Although this installation is Flatcar branded you might re-use this repo to deploy your own Jitsi server.
Branding is patched in at configuration build time; just skip this step (in `generate_config.sh`)
and you'll get a stock Jitsi server.
You can also use your own logos, banner, and watermark.

The installation will go through these steps
- Clone this repo locally and configure your new server with minimal settings
- build your Flatcar ignition Jitsi configuration
- Provision a new Flatcar machine / VM and pass the ignition configuration (via "user data")
- Connect to your Jitsi server and meet away!

## Configure your deployment

First, clone this repo locally:
```bash
git clone https://github.com/flatcar/jitsi-server.git
cd jitsi-server
```

Take a look at [`jitsi-config.env`](jitsi-config.env) and set
- `JITSI_SERVER_FQDN` to your new server's designated DNS name.
  You will need to point the respective DNS record to your new Jitsi server later,
   before or during provisioning.
- `LETSENCRYPT_EMAIL` to your email address for receiving LetsEncrypt notifications.
  This is particularly important for long-running servers as LetsEncrypt will send
  TLS certificate expiries to that email address.
  To refresh a certificate simply restart the Jitsi service (or the whole node).

That's it, you're good to go!

## Generate configuration and deploy

This step will fetch docker compose YAML files from
[docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet)
for a specific Jitsi release, and generate a self-contained configuration to pass
into a Flatcar deployment.

The config generator requires a Jitsi version.
At the time of writing, `stable-9584-1` was the latest release.
To use this version, run:
```bash
./generate_config.sh stable-9584-1
```
For a full list of Jitsi releases, check out
https://github.com/jitsi/docker-jitsi-meet/releases.

This generates `ignition.json` which we'll feed into the Flatcar deployment.

Optionally pass `--no-branding` to `./generate_config.sh` to disable branding.

If your target deployment is ARM64, pass `--arch arm64` to
`./generate_config.sh` so the correct docker sysexts are used.

## Deploy

Deploy a new Flatcar instance on a
[cloud provider or private cloud of your choice](https://www.flatcar.org/docs/latest/installing/cloud/)
and feed `ignition.json` to the deployment.

If you deploy to a locked-down environment e.g. behind a NAT or firewall, make
sure to open ports 80 and 443 (TCP) and 10000 (UDP) to the instance (and
optionally port 22 if you want to ssh into your server).

The deployment is zero-touch.
There should be no need to interact with the instance to aid the deployment.

As soon as you know the IP address of your Flatcar Jitsi host, point the hostname DNS entry
(the one we used for `JITSI_SERVER_FQDN`) to that IP.

At first boot, the [installer](jitsi-install.sh) will run and set up Jitsi in `/opt/jitsi`. 

Jitsi will become available at the designated hostname after a few minutes.

## Meet

Connect to the host via `https://<hostname>` and start a meeting.

By default, authentication is enabled - though unauthenticated guests can enter after
an authenticated host has started a meeting.
The default authenticated user name is `flatcar`, and the password is auto-generated on
the node during provisioning.
Initial user and password are appended to `/opt/jitsi/.env` on the server.
See Customisation below on how to pass a custom user/password into the deployment.

## Customisations

- Installer script settings can be overridden in [jitsi-install.env](jitsi-install.env):
  - `MODERATOR_USER` Custom Jitsi meeting moderator user name
  - `MODERATOR_PASS` Password for `MODERATOR_USER`.
     Will be auto-generated at provisioning time and appended to `/opt/jitsi/.env` if not set.
  - `DEPLOY_SET_PUBLIC_IP` When `true`, before installing Jitsi, determine the server's public IP
     address and explicitly configure Jitsi for that IP address (via `JVB_ADVERTISE_IPS`).
     This is handy for running in a NATed / load-balanced cloud environment where the 
     instance doesn't know its public IP address (e.g. in protected Azure environments).
     Alternatively, this can be set to a public IP address to use _that_ address for the server.
     _Set to empty or to `false` to disable._
  - `DEPLOY_WAIT_FOR_HOSTNAME_DNS` wait for the hostname `JITSI_SERVER_FQDN` to resolve to
    the host's public IP before installing Jitsi. Needs `DEPLOY_SET_PUBLIC_IP`.
    In order to ensure we're not flooding LetsEncrypt with certificate queries (and get blocked as a result), the
    installer will check whether the designated hostname matches its public IP address before
    continuing the installation.
- Jitsi settings such as LetsEncrypt usage, authentication, live streaming and recording can be set in
  `jitsi-config.env`. All env variables of jitsi-docker's
  [`docker-compose.yml`](https://github.com/jitsi/docker-jitsi-meet/blob/master/docker-compose.yml)
  and [`jibri.yaml`](https://github.com/jitsi/docker-jitsi-meet/blob/master/jibri.yml)
  can be overridden there.

### ARM64

If you want to deploy to an ARM64 server you'll need to change [`config.yaml`](config.yaml) to use
ARM64 sysexts for docker and docker compose. See the sysexts' `target:` lines in the `links:` section
and the `- path:` and `source:` lines in the `files:` section respectively.

## Test the set-up locally

You can test locally in a qemu VM.
Uncomment the local test settings at the bottom of [`jitsi-config.env`](jitsi-config.env),
disable `DEPLOY_SET_PUBLIC_IP` in [jitsi-install.env](jitsi-install.env),
and re-generate the configuration.

Fetch the latest `flatcar_production_qemu_uefi_efi_code.fd`,
 `flatcar_production_qemu_uefi_efi_vars.fd`,
 `flatcar_production_qemu_uefi_image.img`,
 `flatcar_production_qemu_uefi.sh` from https://stable.release.flatcar-linux.net/amd64-usr/current/ .

Start a local Flatcar instance, pass `ignition.json` and export the necessary ports:
```
chmod 755 flatcar_production_qemu_uefi.sh
./flatcar_production_qemu_uefi.sh -i ignition.json \
  -p 4080-:4080,hostfwd=tcp::4443-:4443,hostfwd=udp::10000-:10000,hostfwd=tcp::2222 \
  -m 4096
  -nographic -snapshot
```
(Note that the `-snapshot` option runs the VM in ephemeral mode, i.e. all changes to the VM
 will be discarded when it powers down.
 This is useful for testing re-provisioning.)

# Operate Jitsi

Connect to https://meet.flatcar.org/, start a meeting.
A login will pop up if you try to create a room and are not authenticated; log in with the user/pass from the installation above.
After starting a meeting, you can (optionally) enable a lobby by clicking "..." -> "Security".

## Stream a meeting to youtube

You need to be logged in as a moderator in Jitsi in order to start a stream.
1. Go to https://studio.youtube.com/, click "Create" (upper right), select "Go live" from the drop-down
2. Configure the live stream, set a title, set visibility, etc.
3. Copy the stream key. DO NOT CLOSE THE TAB.
4. Go to https://meet.flatcar.org/ IN A SEPARATE TAB, create or join a room (https://meet.flatcar.org/OfficeHours is a favourite).
5. Click "..." (lower center, to the right), select "Start live stream"
6. Paste the stream key and click the "Start live stream" button.
7. Optionally, add a youtube widget to the Matrix channel so people there can watch the stream
   1. In Matrix, Click "room info" (upper right)
      1. Select "Add widgets, bridges & bots"
      2. Click "Add Integrations"
      3. Select "Youtube"
   2. In the Youtube live stream tab (you didn't close it, did you?)
      1. Click the "share" button (the bent arrow on the upper right hand side) and copy the video URL to clipboard
   3. In the Matrix youtube widget settings
      1. Paste the video URL
      2. Click Save and close the widget dialog
      3. Back in the room info, pin the youtube widget
      4. Finally, click "Set my room layout for everyone"

NOTE that when you are the moderator and you close the call / leave the room, the meeting will end for everybody, and a stream, if currently ongoing, will stop.

Stop the stream:

8. In the Jitsi meeting, click "..." (lower center, to the right), select "Stop live stream"
9. In the youtube live stream tab, click "End stream" (upper right)
10. If you pinned the stream in the Matrix channel, you can remove the pinning by removing the youtube widget from the channel.
    If you chose to not remove the pinned video, users on Matrix will have the opportunity to replay a recording of the meeting streamed.
