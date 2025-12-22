# Systemd Service Files

This directory contains systemd service files for managing the Minecraft server and related services.

## Service Files

### Convitelist Services
- `convitelist-docker.service` - Main Docker Compose service for Convitelist (✅ **Currently Installed**)
- `convitelist-update.service` - Auto-update service (used by timer)
- `convitelist-update.timer` - Auto-update timer (checks every 5 minutes) (✅ **Currently Installed**)
- `convitelist-api.service` - Alternative: Direct npm service (not used, Docker preferred)
- `convitelist-frontend.service` - Alternative: Frontend build service (not used, Docker preferred)

### Minecraft Services
- `minecraft.service` - Main Minecraft server service (✅ **Currently Installed**)
- `minecraft-sleeper.service` - Alternative: Server sleeper interface
- `minecraft-sleeper-improved.service` - Alternative: Improved server sleeper with pre-start tasks

## Installation

To install a service file:

```bash
sudo cp services/<service-name>.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable <service-name>.service
sudo systemctl start <service-name>.service
```

## Currently Active Services

- `minecraft.service` - Minecraft server
- `convitelist-docker.service` - Convitelist Docker Compose
- `convitelist-update.timer` - Auto-update from GitHub

## Documentation

See `../docs/` for detailed setup instructions:
- `DOCKER_SETUP.md` - Docker setup guide
- `MIGRATION_COMPLETE.md` - Migration documentation
- `SERVICE_FILES_EXPLANATION.md` - How service files work


## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Raspberry Pi Boot                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │   systemd (Service Manager)        │
        └───────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│  Minecraft   │  │   Convitelist    │  │ Auto-Update  │
│   Service    │  │  Docker Service   │  │    Timer     │
└──────────────┘  └──────────────────┘  └──────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│ Server       │  │ Docker Containers │  │ GitHub       │
│ Sleeper      │  │ - Backend API     │  │ Polling      │
│ Interface    │  │ - Frontend        │  │ (every 5min) │
│              │  │ - Nginx           │  └──────────────┘
└──────────────┘  └──────────────────┘
        │                   │
        ▼                   ▼
┌──────────────┐  ┌──────────────────┐
│ Actual       │  │ Convitelist      │
│ Minecraft    │  │ Web Interface    │
│ Server       │  │ (Port 3002/3003) │
│ (when needed)│  └──────────────────┘
└──────────────┘
```

## Service Flow

### 1. On Boot (Automatic Startup)

**Step 1: System Boots**
- Raspberry Pi starts up
- systemd initializes

**Step 2: Services Start (in order)**
1. **minecraft.service** starts
   - Runs `/home/pi/minecraft/start.sh`
   - Starts server sleeper interface via `screen -dmS minecraft npm run start`
   - Server sleeper listens on port 25565 (Minecraft port)
   - Actual server is NOT started yet (saves resources)

2. **convitelist-docker.service** starts
   - Pulls latest code from GitHub (`git pull origin master`)
   - Starts Docker Compose services:
     - `convitelist-backend` (API on port 3002)
     - `convitelist-frontend` (Web UI on port 3003)
     - `convitelist-nginx` (Reverse proxy on port 80/443)

3. **convitelist-update.timer** activates
   - Checks for updates every 5 minutes
   - If changes detected, triggers `convitelist-update.service`

### 2. When a Player Connects

```
Player connects to port 25565
        │
        ▼
Server Sleeper Interface detects connection
        │
        ▼
Checks whitelist (from Minecraft whitelist.json)
        │
        ▼
If allowed: Starts actual Minecraft server
        │
        ▼
Player can now play
        │
        ▼
When all players leave: Server stops automatically
        │
        ▼
Server Sleeper Interface continues running
```

### 3. Auto-Update Process

```
Every 5 minutes:
        │
        ▼
convitelist-update.timer triggers
        │
        ▼
convitelist-update.service runs
        │
        ▼
Pulls latest code from GitHub
        │
        ▼
Checks if files changed
        │
        ▼
If changed:
  - Rebuilds Docker images
  - Restarts Docker containers
  - Runs database migrations
```

## Components Breakdown

### 1. Minecraft Server Sleeper Interface

**What it does:**
- Listens on Minecraft port (25565)
- Shows "server sleeping" message to players
- Starts actual server when whitelisted player connects
- Stops server when empty (saves resources)

**Configuration:**
- File: `/home/pi/minecraft/sleepingSettings.yml`
- Web interface: Port 5000 (for server status)
- Managed by: `minecraft.service` → `start.sh` → `npm run start`

**Benefits:**
- Server only runs when needed (saves CPU/RAM)
- Automatic start/stop
- Web interface for status

### 2. Convitelist (Whitelist Management)

**What it does:**
- Web interface for managing Minecraft whitelist
- Users can register themselves
- Admins approve/reject users
- Automatically adds approved users to Minecraft whitelist via RCON

**Components:**
- **Backend API** (Docker container)
  - Port: 3002 (mapped from container 3001)
  - Database: SQLite in Docker volume
  - RCON: Connects to Minecraft server to manage whitelist

- **Frontend** (Docker container)
  - Port: 3003 (mapped from container 80)
  - React web application
  - Served by Nginx

- **Nginx** (Docker container)
  - Port: 80/443
  - Reverse proxy (optional, if using custom domain)

**Managed by:** `convitelist-docker.service`

### 3. Auto-Update System

**What it does:**
- Automatically pulls latest code from GitHub
- Rebuilds and restarts services if changes detected
- Runs every 5 minutes

**Components:**
- `convitelist-update.timer` - Triggers every 5 minutes
- `convitelist-update.service` - Performs the update

**Benefits:**
- Always running latest code
- No manual updates needed
- Automatic deployment

## Port Mapping

| Service | Port | Description |
|---------|------|-------------|
| Minecraft | 25565 | Main game port |
| Server Sleeper Web | 5000 | Status/control interface |
| Convitelist Backend | 3002 | API (mapped from 3001) |
| Convitelist Frontend | 3003 | Web UI (mapped from 80) |
| Nginx | 80/443 | Reverse proxy (optional) |

## File Locations

### Service Files (Source)
- Location: `/home/pi/RPi-Minecraft-Server/services/`
- Installed to: `/etc/systemd/system/`

### Minecraft Server
- Directory: `/home/pi/minecraft/`
- Start script: `/home/pi/minecraft/start.sh`
- Sleeper config: `/home/pi/minecraft/sleepingSettings.yml`

### Convitelist
- Directory: `/home/pi/convitelist/`
- Docker Compose: `/home/pi/convitelist/docker-compose.yml`
- Environment: `/home/pi/convitelist/.env`

## Service Management

### Check Status
```bash
# All services
systemctl status minecraft.service convitelist-docker.service

# Docker containers
docker ps

# Auto-update timer
systemctl status convitelist-update.timer
```

### Start/Stop Services
```bash
# Minecraft
sudo systemctl start minecraft.service
sudo systemctl stop minecraft.service

# Convitelist
sudo systemctl start convitelist-docker.service
sudo systemctl stop convitelist-docker.service
```

### View Logs
```bash
# Minecraft
journalctl -u minecraft.service -f

# Convitelist
journalctl -u convitelist-docker.service -f
docker-compose -f /home/pi/convitelist/docker-compose.yml logs -f
```

## Data Flow

### Whitelist Management Flow

```
User visits Convitelist website
        │
        ▼
Registers with Minecraft username
        │
        ▼
Admin logs in and reviews
        │
        ▼
Admin approves user
        │
        ▼
Backend uses RCON to add user to Minecraft whitelist
        │
        ▼
User can now connect to server
```

### Server Wake-Up Flow

```
Player tries to connect
        │
        ▼
Server Sleeper checks whitelist
        │
        ▼
If whitelisted: Starts actual server
        │
        ▼
Player connects and plays
        │
        ▼
When empty: Server stops, Sleeper continues
```
