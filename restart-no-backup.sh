#!/bin/bash
# Restart Minecraft server without creating a backup
# Usage: ./restart-no-backup.sh

echo "Stopping Minecraft server..."
sudo systemctl stop minecraft.service

echo "Waiting for server to stop..."
sleep 3

echo "Creating .skip-backup flag file..."
touch /home/pi/minecraft/.skip-backup

echo "Starting Minecraft server without backup..."
sudo systemctl start minecraft.service

echo "Removing .skip-backup flag file..."
rm -f /home/pi/minecraft/.skip-backup

echo "Server restart initiated (no backup)."
echo "To view the server console: screen -r minecraft"
echo "To check status: sudo systemctl status minecraft.service"

