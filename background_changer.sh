#!/bin/bash

PID=$(pgrep --euid $EUID gnome-session)
export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PID/environ|cut -d= -f2-)

#set for cron if  cron use or timed if timed use
cronortimed=cron
#time interval - only used if timed and not cron - set a number for seconds or add m for minutes. ie 5 = seconds. 5m = 5 minutes.
time_interval=30

DIR="/files/to/images/to/randomly/go/through"

while true;
do
PIC=$(ls $DIR/* | shuf -n1)
gsettings set org.gnome.desktop.background picture-uri "file://$PIC"
gsettings set org.gnome.desktop.screensaver picture-uri "file://$PIC"
if [$cronortimed -eq "timed"] then
sleep $time_interval
fi
done
