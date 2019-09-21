#!/bin/bash

PID=$(pgrep --euid $EUID gnome-session)
export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PID/environ|cut -d= -f2-)

DIR="/files/to/images/to/randomly/go/through"
while true;
do
PIC=$(ls $DIR/* | shuf -n1)
gsettings set org.gnome.desktop.background picture-uri "file://$PIC"
gsettings set org.gnome.desktop.screensaver picture-uri "file://$PIC"
sleep $time_interval
done
