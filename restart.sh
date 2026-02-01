#!/bin/bash
# Minecraft Server reboot script - primarily called by minecraft service but can be ran manually with ./restart.sh

# Set path variable
USERPATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games"
PathLength=${#USERPATH}
if [[ "$PathLength" -gt 12 ]]; then
    PATH="$USERPATH"
else
    echo "Unable to set path variable.  You likely need to download an updated version of SetupMinecraft.sh from GitHub!"
fi

# Check to make sure we aren't running as root
if [[ $(id -u) = 0 ]]; then
   echo "This script is not meant to run as root or sudo.  Please run as a normal user with ./restart.sh.  Exiting..."
   exit 1
fi

# Optional: announce in-game if server is running, then stop via systemctl (one code path, avoids terminal/SIGCONT crash)
if screen -list | grep -q "\.minecraft"; then
  echo "Sending restart notifications to server..."
  screen -Rd minecraft -X stuff "say Server is restarting in 30 seconds! $(printf '\r')"
  sleep 23s
  screen -Rd minecraft -X stuff "say Server is restarting in 7 seconds! $(printf '\r')"
  sleep 1s
  screen -Rd minecraft -X stuff "say Server is restarting in 6 seconds! $(printf '\r')"
  sleep 1s
  screen -Rd minecraft -X stuff "say Server is restarting in 5 seconds! $(printf '\r')"
  sleep 1s
  screen -Rd minecraft -X stuff "say Server is restarting in 4 seconds! $(printf '\r')"
  sleep 1s
  screen -Rd minecraft -X stuff "say Server is restarting in 3 seconds! $(printf '\r')"
  sleep 1s
  screen -Rd minecraft -X stuff "say Server is restarting in 2 seconds! $(printf '\r')"
  sleep 1s
  screen -Rd minecraft -X stuff "say Server is restarting in 1 second! $(printf '\r')"
  sleep 1s
else
  echo "Server not running (will still reboot Pi)."
fi

# Stop via systemctl so stop.sh runs cleanly (avoids SIGCONT/terminal I/O crash)
touch dirname/minecraft/.skip-backup
echo "Stopping Minecraft service..."
sudo -n systemctl stop minecraft.service
sleep 2

echo "Rebooting now."
sudo -n reboot
