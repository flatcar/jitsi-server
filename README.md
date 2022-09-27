# jitsi-server

The Flatcar Jitsi server. Uses https://github.com/jitsi/docker-jitsi-meet.

# Use

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

# Installation
- Get a server (docker-compose is required)
- update DNS record of meet.flatcar.org to point to that server

As root, run
```shell
apt install docker.io docker-compose
adduser --system --group jitsi
cp -r flatcar-jitsi.sh resources/ /home/jitsi
cd /home/jitsi
su -s ./flatcar-jitsi.sh - jitsi
cd -
cp jitsi.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now jitsi
```

`flatcar-jitsi.sh` will print the Jitsi moderator username and password.
Only the moderator can start a meeting and stream meetings to youtube.
