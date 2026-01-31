#!/bin/bash
# Server Status Check Script
# This script checks if all Minecraft server components are running properly

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Minecraft Server Status Check"
echo "=========================================="
echo ""

# Check 1: Systemd Service Status
echo "1. Checking systemd service status..."
if systemctl is-active --quiet minecraft.service; then
    echo -e "${GREEN}✓${NC} minecraft.service is ACTIVE"
    systemctl status minecraft.service --no-pager -l | head -5
else
    echo -e "${RED}✗${NC} minecraft.service is INACTIVE"
    echo "   Status: $(systemctl is-active minecraft.service 2>/dev/null || echo 'unknown')"
fi
echo ""

# Check 2: Screen Sessions
echo "2. Checking screen sessions..."
SCREENS=$(screen -list 2>/dev/null | grep -c "\.minecraft")
if [ "$SCREENS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $SCREENS screen session(s):"
    screen -list 2>/dev/null | grep "\.minecraft"
else
    echo -e "${RED}✗${NC} No screen sessions found"
fi
echo ""

# Check 3: Java/Minecraft Processes
echo "3. Checking Java/Minecraft processes..."
JAVA_PROC=$(ps aux | grep -E "java.*paperclip" | grep -v grep | wc -l)
NODE_PROC=$(ps aux | grep -E "node.*sleepingServerStarter" | grep -v grep | wc -l)
if [ "$JAVA_PROC" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $JAVA_PROC Java/Minecraft process(es)"
    ps aux | grep -E "java.*paperclip" | grep -v grep | awk '{print "   PID:", $2, "CPU:", $3"%", "MEM:", $4"%", "CMD:", substr($0, index($0,$11))}'
else
    echo -e "${RED}✗${NC} No Java/Minecraft process found"
fi
if [ "$NODE_PROC" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $NODE_PROC Node.js sleeping server process(es)"
    ps aux | grep -E "node.*sleepingServerStarter" | grep -v grep | awk '{print "   PID:", $2, "CPU:", $3"%", "MEM:", $4"%"}'
else
    echo -e "${YELLOW}⚠${NC} No Node.js sleeping server process found (this is OK if server is fully started)"
fi
echo ""

# Check 4: Network Ports
echo "4. Checking network ports..."
if command -v ss >/dev/null 2>&1; then
    PORT_CMD="ss"
else
    PORT_CMD="netstat"
fi

PORT_25565=$($PORT_CMD -tlnp 2>/dev/null | grep -c ":25565")
PORT_19132=$($PORT_CMD -ulnp 2>/dev/null | grep -c ":19132")
PORT_5000=$($PORT_CMD -tlnp 2>/dev/null | grep -c ":5000")

if [ "$PORT_25565" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Port 25565 (Java Edition) is LISTENING"
    $PORT_CMD -tlnp 2>/dev/null | grep ":25565" | head -1
else
    echo -e "${RED}✗${NC} Port 25565 (Java Edition) is NOT listening"
fi

if [ "$PORT_19132" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Port 19132 (Bedrock Edition) is LISTENING"
    $PORT_CMD -ulnp 2>/dev/null | grep ":19132" | head -1
else
    echo -e "${YELLOW}⚠${NC} Port 19132 (Bedrock Edition) is NOT listening (may be normal if Bedrock is disabled)"
fi

if [ "$PORT_5000" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Port 5000 (Web interface) is LISTENING"
    $PORT_CMD -tlnp 2>/dev/null | grep ":5000" | head -1
else
    echo -e "${YELLOW}⚠${NC} Port 5000 (Web interface) is NOT listening (may be normal if web server is disabled)"
fi
echo ""

# Check 5: Server Files
echo "5. Checking server files..."
if [ -f "/home/pi/minecraft/paperclip.jar" ]; then
    echo -e "${GREEN}✓${NC} paperclip.jar exists"
    ls -lh /home/pi/minecraft/paperclip.jar | awk '{print "   Size:", $5, "Modified:", $6, $7, $8}'
else
    echo -e "${RED}✗${NC} paperclip.jar NOT FOUND"
fi

if [ -f "/home/pi/minecraft/sleepingSettings.yml" ]; then
    echo -e "${GREEN}✓${NC} sleepingSettings.yml exists"
else
    echo -e "${RED}✗${NC} sleepingSettings.yml NOT FOUND"
fi

if [ -d "/home/pi/minecraft/plugins" ]; then
    PLUGIN_COUNT=$(ls -1 /home/pi/minecraft/plugins/*.jar 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Plugins directory exists ($PLUGIN_COUNT .jar files)"
else
    echo -e "${RED}✗${NC} Plugins directory NOT FOUND"
fi
echo ""

# Check 6: Recent Logs
echo "6. Checking recent server activity..."
if [ -f "/home/pi/minecraft/logs/latest.log" ]; then
    echo "   Last 5 lines of latest.log:"
    tail -5 /home/pi/minecraft/logs/latest.log 2>/dev/null | sed 's/^/   /'
else
    echo -e "${YELLOW}⚠${NC} No latest.log found (server may not have started yet)"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="

ALL_OK=true
if ! systemctl is-active --quiet minecraft.service; then
    ALL_OK=false
fi
if [ "$SCREENS" -eq 0 ] && [ "$JAVA_PROC" -eq 0 ]; then
    ALL_OK=false
fi
if [ "$PORT_25565" -eq 0 ]; then
    ALL_OK=false
fi

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✓ Server appears to be RUNNING${NC}"
    echo ""
    echo "To view the server console:"
    echo "  screen -r minecraft"
    echo ""
    echo "To stop the server:"
    echo "  sudo systemctl stop minecraft"
    echo "  OR"
    echo "  ./stop.sh"
else
    echo -e "${RED}✗ Server appears to be NOT RUNNING${NC}"
    echo ""
    echo "To start the server:"
    echo "  sudo systemctl start minecraft"
    echo "  OR"
    echo "  ./start.sh"
    echo ""
    echo "To check service logs:"
    echo "  journalctl -u minecraft.service -n 50"
fi
echo ""

